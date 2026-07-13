// SPDX-License-Identifier: GPL-3.0-only
#include "clipboardmanager.hpp"

#include "../Config/config.hpp"
#include "../Config/launcherconfig.hpp"

#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qloggingcategory.h>
#include <qregularexpression.h>

Q_LOGGING_CATEGORY(lcClipboard, "caelestia.services.clipboard", QtInfoMsg)

namespace caelestia::services {

ClipboardManager::ClipboardManager(QObject* parent)
    : QObject(parent) {
    const auto runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR", "/tmp");
    m_imageCacheDir = runtimeDir + "/caelestia-clipboard";
}

QVariantList ClipboardManager::items() const { return m_items; }

QString ClipboardManager::imageCacheDir() const { return m_imageCacheDir; }

void ClipboardManager::reload() {
    // Kill any in-flight list process
    if (m_listProc && m_listProc->state() != QProcess::NotRunning) {
        m_listProc->kill();
        m_listProc->waitForFinished(200);
    }

    m_listProc = new QProcess(this);
    m_listProc->setProgram("cliphist");
    m_listProc->setArguments({"list"});

    connect(m_listProc, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus) {
        if (exitCode != 0) {
            qCWarning(lcClipboard) << "cliphist list failed with exit code" << exitCode;
            m_items.clear();
            emit itemsChanged();
            m_listProc->deleteLater();
            m_listProc = nullptr;
            return;
        }

        const auto output = m_listProc->readAllStandardOutput();
        m_listProc->deleteLater();
        m_listProc = nullptr;

        // Parse natively: each line is "<id>\t<preview>"
        static const QRegularExpression imageRe(
            QStringLiteral(R"(\[\[ binary data \d+ KiB png \d+x\d+ \]\])"));

        QVariantList result;
        const auto lines = output.split('\n');
        result.reserve(lines.size());

        const int maxEntries = caelestia::config::GlobalConfig::instance()->launcher()->clipboardMaxEntries();
        int count = 0;

        for (const auto& rawLine : lines) {
            if (count >= maxEntries) break;

            const auto line = QString::fromUtf8(rawLine);
            if (line.isEmpty()) continue;

            const auto tabIdx = line.indexOf('\t');
            if (tabIdx < 0) continue;

            bool ok = false;
            const int id = line.left(tabIdx).toInt(&ok);
            if (!ok) continue;

            const auto preview = line.mid(tabIdx + 1);
            const bool isImage = imageRe.match(preview).hasMatch();

            result.append(QVariantMap{
                {"id",      id},
                {"preview", preview},
                {"isImage", isImage},
            });
            count++;
        }

        m_items = result;
        emit itemsChanged();

        // Pre-warm: decode all image entries in the background so they are
        // already on disk before the user opens the launcher.
        QDir().mkpath(m_imageCacheDir);
        for (const auto& entry : std::as_const(m_items)) {
            const auto map = entry.toMap();
            if (!map.value("isImage").toBool()) continue;
            const int id = map.value("id").toInt();
            const QString outPath = m_imageCacheDir + "/" + QString::number(id) + ".png";
            // Skip if already cached from a previous reload
            if (QFileInfo::exists(outPath)) {
                emit imageReady(id, outPath);
                continue;
            }
            decodeImage(id, outPath);
        }
    });

    connect(m_listProc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        qCWarning(lcClipboard) << "cliphist list process error:" << err;
        m_listProc->deleteLater();
        m_listProc = nullptr;
    });

    m_listProc->start();
}

void ClipboardManager::decodeImage(int id, const QString& outPath) {
    // Ensure output directory exists
    const QFileInfo fi(outPath);
    QDir dir(fi.absolutePath());
    if (!dir.exists() && !dir.mkpath(".")) {
        qCWarning(lcClipboard) << "Failed to create cache directory:" << dir.absolutePath();
        return;
    }

    auto* proc = new QProcess(this);
    proc->setProgram("cliphist");
    proc->setArguments({"decode", QString::number(id)});

    connect(proc, &QProcess::finished, this, [this, proc, outPath, id](int exitCode, QProcess::ExitStatus) {
        if (exitCode != 0) {
            qCWarning(lcClipboard) << "cliphist decode failed for id" << id;
            proc->deleteLater();
            return;
        }

        const auto data = proc->readAllStandardOutput();
        proc->deleteLater();

        QFile f(outPath);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            qCWarning(lcClipboard) << "Failed to write decoded clipboard image to:" << outPath;
            return;
        }
        f.write(data);
        f.close();

        // Signal QML that this specific image is ready — no timers needed.
        emit imageReady(id, outPath);
    });

    connect(proc, &QProcess::errorOccurred, this, [proc, id](QProcess::ProcessError err) {
        qCWarning(lcClipboard) << "cliphist decode process error for id" << id << ":" << err;
        proc->deleteLater();
    });

    proc->start();
}

} // namespace caelestia::services
