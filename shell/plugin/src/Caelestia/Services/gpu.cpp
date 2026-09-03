#include "gpu.hpp"

#include "../Config/rootnodes.hpp"
#include "../Config/serviceconfig.hpp"
#include "sensorslib.hpp"

#include <cmath>
#include <qdir.h>
#include <qfile.h>
#include <qregularexpression.h>
#include <QTimer>

namespace caelestia::services {

namespace {

constexpr const char* kTypeDetectScript =
    "if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then echo NVIDIA;"
    " elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC;"
    " elif ls /sys/class/drm/card*/gt/gt0/rps_cur_freq_mhz 2>/dev/null | grep -q .; then echo GENERIC;"
    " else echo NONE; fi";

constexpr const char* kNameDetectScript = "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null"
                                          " || glxinfo -B 2>/dev/null | grep 'Device:' | cut -d':' -f2 | cut -d'(' -f1"
                                          " || lspci 2>/dev/null | grep -i 'vga\\|3d controller\\|display' | head -1";

} // namespace

Gpu::Gpu(QObject* parent)
    : TickingService(parent) {
    auto* svc = caelestia::config::ConfigSingleton::instance()->services();
    m_userType = parseType(svc->gpuType());
    QObject::connect(svc, &caelestia::config::ServiceConfig::gpuTypeChanged, this, [this, svc] {
        setUserType(parseType(svc->gpuType()));
    });

    // Defer the initial GPU detection by 5 seconds to prevent waking up a runtime-suspended
    // discrete GPU (e.g., Nvidia) during Qt Wayland's initial screen enumeration.
    // If the dGPU wakes up while Qt is picking the primary screen for its animation
    // loop, Qt may lock the refresh rate to the dGPU's monitor rather than the iGPU's,
    // causing an animation refresh-rate mismatch on multi-monitor setups (Issue #169, #314).
    QTimer::singleShot(5000, this, [this] {
        if (m_userType == Auto) {
            detectTypeOnce();
        }
        detectNameOnce();
    });
}

Gpu::Type Gpu::type() const {
    return m_userType == Auto ? m_autoType : m_userType;
}

Gpu::Type Gpu::userType() const {
    return m_userType;
}

Gpu::Type Gpu::autoType() const {
    return m_autoType;
}

QString Gpu::name() const {
    return m_name;
}

qreal Gpu::percentage() const {
    return m_percentage;
}

qreal Gpu::temperature() const {
    return m_temperature;
}

void Gpu::setUserType(Type value) {
    if (value == m_userType) {
        return;
    }
    const Type prevDerived = type();
    m_userType = value;
    Q_EMIT userTypeChanged();
    if (type() != prevDerived) {
        Q_EMIT typeChanged();
    }
}

void Gpu::setAutoType(Type value) {
    if (value == m_autoType) {
        return;
    }
    const Type prevDerived = type();
    m_autoType = value;
    Q_EMIT autoTypeChanged();
    if (type() != prevDerived) {
        Q_EMIT typeChanged();
    }
}

void Gpu::setName(QString value) {
    if (value == m_name) {
        return;
    }
    m_name = std::move(value);
    Q_EMIT nameChanged();
}

void Gpu::tick() {
    const Type t = type();
    if (t == Generic) {
        readGenericUsage();
        readGpuTemperature();
    } else if (t == Nvidia) {
        startNvidiaUsage();
    } else {
        if (std::abs(m_percentage) > 0.0001) {
            m_percentage = 0.0;
            Q_EMIT percentageChanged();
        }
        if (std::abs(m_temperature) > 0.05) {
            m_temperature = 0.0;
            Q_EMIT temperatureChanged();
        }
    }
}

void Gpu::detectTypeOnce() {
    if (m_typeProc) {
        return;
    }
    m_typeProc = new QProcess(this);
    QObject::connect(m_typeProc, &QProcess::finished, this, [this](int, QProcess::ExitStatus) {
        const QByteArray out = m_typeProc->readAllStandardOutput().trimmed();
        if (!out.isEmpty()) {
            setAutoType(parseType(QString::fromLatin1(out)));
        }
        m_typeProc->deleteLater();
        m_typeProc = nullptr;
    });
    m_typeProc->start(QStringLiteral("sh"), { QStringLiteral("-c"), QString::fromLatin1(kTypeDetectScript) });
}

void Gpu::detectNameOnce() {
    if (m_nameProc) {
        return;
    }
    m_nameProc = new QProcess(this);
    QObject::connect(m_nameProc, &QProcess::finished, this, [this](int, QProcess::ExitStatus) {
        const QString output = QString::fromUtf8(m_nameProc->readAllStandardOutput()).trimmed();
        if (!output.isEmpty()) {
            const QString lower = output.toLower();
            if (lower.contains(QStringLiteral("nvidia")) || lower.contains(QStringLiteral("geforce")) ||
                lower.contains(QStringLiteral("rtx")) || lower.contains(QStringLiteral("gtx")) ||
                lower.contains(QStringLiteral("rx"))) {
                setName(cleanName(output));
            } else {
                static const QRegularExpression bracketRe(QStringLiteral("\\[([^\\]]+)\\][^\\[]*$"));
                const auto bracket = bracketRe.match(output);
                if (bracket.hasMatch()) {
                    setName(cleanName(bracket.captured(1)));
                } else {
                    static const QRegularExpression colonRe(QStringLiteral(":\\s*(.+)"));
                    const auto colon = colonRe.match(output);
                    if (colon.hasMatch()) {
                        setName(cleanName(colon.captured(1)));
                    }
                }
            }
        }
        m_nameProc->deleteLater();
        m_nameProc = nullptr;
    });
    m_nameProc->start(QStringLiteral("sh"), { QStringLiteral("-c"), QString::fromLatin1(kNameDetectScript) });
}

void Gpu::readGenericUsage() {
    const QStringList cards =
        QDir(QStringLiteral("/sys/class/drm"))
            .entryList(QStringList() << QStringLiteral("card*"), QDir::Dirs | QDir::NoDotAndDotDot);

    qreal sum = 0.0;
    int count = 0;

    // Pass 1: amdgpu (and some newer Xe) cards expose a direct busy percent.
    for (const QString& card : cards) {
        QFile f(QStringLiteral("/sys/class/drm/%1/device/gpu_busy_percent").arg(card));
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        bool ok = false;
        const qreal v = f.readAll().trimmed().toDouble(&ok);
        f.close();
        if (ok) {
            sum += v;
            ++count;
        }
    }

    // Pass 2: Intel iGPUs have no busy-percent node; approximate usage as the
    // ratio of the current GPU frequency to its maximum.
    if (count < cards.size()) {
        for (const QString& card : cards) {
            if (QFile::exists(QStringLiteral("/sys/class/drm/%1/device/gpu_busy_percent").arg(card)))
                continue;
            QFile cur(QStringLiteral("/sys/class/drm/%1/gt/gt0/rps_cur_freq_mhz").arg(card));
            if (!cur.open(QIODevice::ReadOnly | QIODevice::Text)) {
                continue;
            }
            QFile max(QStringLiteral("/sys/class/drm/%1/gt/gt0/rps_max_freq_mhz").arg(card));
            if (!max.open(QIODevice::ReadOnly | QIODevice::Text)) {
                cur.close();
                continue;
            }
            bool curOk = false;
            bool maxOk = false;
            const qreal curV = cur.readAll().trimmed().toDouble(&curOk);
            const qreal maxV = max.readAll().trimmed().toDouble(&maxOk);
            cur.close();
            max.close();
            if (curOk && maxOk && maxV > 0.0) {
                qreal ratio = curV / maxV;
                if (ratio < 0.0) {
                    ratio = 0.0;
                }
                if (ratio > 1.0) {
                    ratio = 1.0;
                }
                sum += ratio * 100.0;
                ++count;
            }
        }
    }

    const qreal newPerc = count > 0 ? sum / count / 100.0 : 0.0;
    if (std::abs(newPerc - m_percentage) > 0.0001) {
        m_percentage = newPerc;
        Q_EMIT percentageChanged();
    }
}

void Gpu::startNvidiaUsage() {
    if (m_nvidiaProc) {
        return;
    }
    m_nvidiaProc = new QProcess(this);
    QObject::connect(m_nvidiaProc, &QProcess::finished, this, [this](int, QProcess::ExitStatus) {
        const QByteArray out = m_nvidiaProc->readAllStandardOutput().trimmed();
        m_nvidiaProc->deleteLater();
        m_nvidiaProc = nullptr;

        const QList<QByteArray> parts = out.split(',');
        if (parts.size() < 2) {
            return;
        }
        bool ok1 = false;
        bool ok2 = false;
        const qreal usage = parts.at(0).trimmed().toDouble(&ok1) / 100.0;
        const qreal temp = parts.at(1).trimmed().toDouble(&ok2);
        if (ok1 && std::abs(usage - m_percentage) > 0.0001) {
            m_percentage = usage;
            Q_EMIT percentageChanged();
        }
        if (ok2 && std::abs(temp - m_temperature) > 0.05) {
            m_temperature = temp;
            Q_EMIT temperatureChanged();
        }
    });
    m_nvidiaProc->start(QStringLiteral("nvidia-smi"), { QStringLiteral("--query-gpu=utilization.gpu,temperature.gpu"),
                                                          QStringLiteral("--format=csv,noheader,nounits") });
}

void Gpu::readGpuTemperature() {
    const auto t = sensorslib::gpuPciAverageTemp();
    const qreal newTemp = t.value_or(0.0);
    if (std::abs(newTemp - m_temperature) > 0.05) {
        m_temperature = newTemp;
        Q_EMIT temperatureChanged();
    }
}

Gpu::Type Gpu::parseType(const QString& s) {
    const QString u = s.trimmed().toUpper();
    if (u.isEmpty()) {
        return Auto;
    }
    if (u == QStringLiteral("NVIDIA")) {
        return Nvidia;
    }
    if (u == QStringLiteral("GENERIC")) {
        return Generic;
    }
    return None;
}

QString Gpu::cleanName(QString s) {
    static const QRegularExpression noise(
        QStringLiteral("\\(R\\)|\\(TM\\)|Graphics"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression spaces(QStringLiteral("\\s+"));
    s.replace(noise, QString());
    s.replace(spaces, QStringLiteral(" "));
    return s.trimmed();
}

} // namespace caelestia::services
