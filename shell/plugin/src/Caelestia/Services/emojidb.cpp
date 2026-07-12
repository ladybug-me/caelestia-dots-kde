// SPDX-License-Identifier: GPL-3.0-only
#include "emojidb.hpp"

#include <algorithm>

#include <qfile.h>
#include <qjsondocument.h>
#include <qjsonobject.h>
#include <qloggingcategory.h>
#include <qstandardpaths.h>
#include <qtextstream.h>

Q_LOGGING_CATEGORY(lcEmojiDb, "caelestia.services.emojidb", QtInfoMsg)

namespace caelestia::services {

EmojiDb::EmojiDb(QObject* parent)
    : QObject(parent) {
    // Find the emojis.txt — same path used by Emojis.qml
    // Prefer user-local override, fall back to system package path
    const auto sysPath = QStringLiteral("/usr/lib/python3.14/site-packages/caelestia/data/emojis.txt");
    // Also try versioned python paths
    const QStringList candidates = {
        sysPath,
        QStringLiteral("/usr/lib/python3.13/site-packages/caelestia/data/emojis.txt"),
        QStringLiteral("/usr/lib/python3.12/site-packages/caelestia/data/emojis.txt"),
    };
    for (const auto& path : candidates) {
        if (QFile::exists(path)) {
            m_emojiPath = path;
            break;
        }
    }

    // Frequency file: $XDG_CONFIG_HOME/caelestia/emoji-frequencies.json
    const auto configDir = qEnvironmentVariable("XDG_CONFIG_HOME",
        QDir::homePath() + "/.config");
    m_freqPath = configDir + "/caelestia/emoji-frequencies.json";

    loadEmojis();
    loadFrequencies();
}

bool EmojiDb::loaded() const { return m_loaded; }
int EmojiDb::count() const { return static_cast<int>(m_emojis.size()); }

void EmojiDb::loadEmojis() {
    if (m_emojiPath.isEmpty()) {
        qCWarning(lcEmojiDb) << "emojis.txt not found. Emoji picker will be empty.";
        return;
    }

    QFile f(m_emojiPath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCWarning(lcEmojiDb) << "Failed to open emojis.txt:" << m_emojiPath;
        return;
    }

    QTextStream in(&f);
    m_emojis.clear();
    m_emojis.reserve(14000);

    while (!in.atEnd()) {
        const auto line = in.readLine();
        if (line.isEmpty()) continue;

        const auto spaceIdx = line.indexOf(u' ');
        if (spaceIdx < 0) continue;

        EmojiEntry entry;
        entry.ch = line.left(spaceIdx);
        entry.name = line.mid(spaceIdx + 1).trimmed();
        entry.nameLower = entry.name.toLower();
        m_emojis.append(std::move(entry));
    }

    m_loaded = true;
    emit loadedChanged();
    qCInfo(lcEmojiDb) << "Loaded" << m_emojis.size() << "emojis from" << m_emojiPath;
}

void EmojiDb::loadFrequencies() {
    QFile f(m_freqPath);
    if (!f.exists()) return;

    if (!f.open(QIODevice::ReadOnly)) {
        qCWarning(lcEmojiDb) << "Failed to open frequency file:" << m_freqPath;
        return;
    }

    const auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) return;

    const auto obj = doc.object();
    m_frequencies.clear();
    m_frequencies.reserve(obj.size());
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        m_frequencies.insert(it.key(), it.value().toInt());
    }
}

void EmojiDb::saveFrequencies() {
    QJsonObject obj;
    for (auto it = m_frequencies.begin(); it != m_frequencies.end(); ++it) {
        obj.insert(it.key(), it.value());
    }

    const auto path = m_freqPath;
    // Ensure parent dir exists
    QDir dir(QFileInfo(path).absolutePath());
    if (!dir.exists()) dir.mkpath(".");

    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcEmojiDb) << "Failed to write frequency file:" << path;
        return;
    }
    f.write(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

void EmojiDb::recordUsage(const QString& ch) {
    m_frequencies[ch] = m_frequencies.value(ch, 0) + 1;
    saveFrequencies();
}

int EmojiDb::getFrequency(const QString& ch) const {
    return m_frequencies.value(ch, 0);
}

QVariantList EmojiDb::getSortedItems(const QStringList& favourites, int limit) const {
    if (m_emojis.isEmpty()) return {};

    const QSet<QString> favSet(favourites.begin(), favourites.end());

    // Build index array for sorting (avoid copying entries)
    QVector<int> indices(m_emojis.size());
    std::iota(indices.begin(), indices.end(), 0);

    std::stable_sort(indices.begin(), indices.end(), [&](int a, int b) {
        const bool aFav = favSet.contains(m_emojis[a].ch);
        const bool bFav = favSet.contains(m_emojis[b].ch);
        if (aFav != bFav) return aFav;
        const int freqA = m_frequencies.value(m_emojis[a].ch, 0);
        const int freqB = m_frequencies.value(m_emojis[b].ch, 0);
        return freqA > freqB;
    });

    QVariantList result;
    const int actualLimit = (limit <= 0) ? static_cast<int>(m_emojis.size()) : std::min(limit, static_cast<int>(m_emojis.size()));
    result.reserve(actualLimit);
    for (int i = 0; i < actualLimit; ++i) {
        const auto& e = m_emojis[indices[i]];
        result.append(QVariantMap{
            {"ch",        e.ch},
            {"name",      e.name},
            {"nameLower", e.nameLower},
        });
    }
    return result;
}

QVariantList EmojiDb::search(const QString& text, int limit) const {
    if (m_emojis.isEmpty()) return {};
    if (text.isEmpty()) return getSortedItems({});

    const auto lower = text.toLower();
    QVariantList result;
    result.reserve(std::min(limit, static_cast<int>(m_emojis.size())));

    for (const auto& e : m_emojis) {
        if (e.nameLower.contains(lower)) {
            result.append(QVariantMap{
                {"ch",        e.ch},
                {"name",      e.name},
                {"nameLower", e.nameLower},
            });
            if (result.size() >= limit) break;
        }
    }
    return result;
}

} // namespace caelestia::services
