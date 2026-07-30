#include "krohnkiteconfig.hpp"
#include <QDebug>
#include <QProcess>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>

namespace caelestia::services {

KrohnkiteConfig::KrohnkiteConfig(QObject* parent)
    : QObject(parent) {
    refresh();
}

KrohnkiteConfig::~KrohnkiteConfig() = default;

void KrohnkiteConfig::setKWinConfig(const QString& key, const QString& value) {
    QStringList args;
    args << QStringLiteral("--file") << QStringLiteral("kwinrc") << QStringLiteral("--group")
         << QStringLiteral("Script-krohnkite") << QStringLiteral("--key") << key << value;

    QProcess::execute(QStringLiteral("kwriteconfig6"), args);
}

QString KrohnkiteConfig::getKWinConfig(const QString& key, const QString& defaultValue) {
    QProcess process;
    QStringList args;
    args << QStringLiteral("--file") << QStringLiteral("kwinrc") << QStringLiteral("--group")
         << QStringLiteral("Script-krohnkite") << QStringLiteral("--key") << key;

    process.start(QStringLiteral("kreadconfig6"), args);
    if (process.waitForFinished() && process.exitCode() == 0) {
        QString out = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            return out;
        }
    }
    return defaultValue;
}

// -1 means disabled by default; >= 1 means enabled at that position.
bool KrohnkiteConfig::isLayoutEnabled(const QString& key, int defaultOrder) {
    QString val = getKWinConfig(key, QString::number(defaultOrder));
    bool ok = false;
    int v = val.toInt(&ok);
    return ok && v >= 1;
}

// Table of all layout keys paired with their default order position.
// -1 = disabled by default; 1..N = enabled at that position (no duplicates).
struct LayoutDefault {
    const char* key;
    int defaultOrder;
};

static const std::initializer_list<LayoutDefault>& allLayoutDefaults() {
    // Default order when kwinrc has never been written.
    // Only enabled-by-default entries get a positive order; disabled get -1.
    static const std::initializer_list<LayoutDefault> table = {
        { "binaryTreeLayoutOrder", 1 },
        { "floatingLayoutOrder", 2 },
        { "tileLayoutOrder", 3 },
        { "monocleLayoutOrder", 4 },
        { "quarterLayoutOrder", 5 },
        { "threeColumnLayoutOrder", 6 },
        { "spreadLayoutOrder", 7 },
        { "stackedLayoutOrder", 8 },
        { "stairLayoutOrder", 9 },
        // Disabled by default:
        { "spiralLayoutOrder", -1 },
        { "columnsLayoutOrder", -1 },
        { "cascadeLayoutOrder", -1 },
    };
    return table;
}

void KrohnkiteConfig::setLayoutEnabled(const QString& key, bool enabled) {
    // Read current order values for all layouts, seeding from defaults where missing.
    QMap<QString, int> orders;
    for (const auto& entry : allLayoutDefaults()) {
        bool ok = false;
        int v = getKWinConfig(QLatin1String(entry.key), QString::number(entry.defaultOrder)).toInt(&ok);
        orders[QLatin1String(entry.key)] = (ok && v >= 1) ? v : -1;
    }

    if (enabled) {
        if (orders[key] >= 1)
            return; // already enabled, nothing to do
        // Shift every currently-enabled layout's order up by 1 to make room at position 1.
        for (auto it = orders.begin(); it != orders.end(); ++it) {
            if (it.value() >= 1) {
                it.value() += 1;
            }
        }
        orders[key] = 1;
    } else {
        int removedOrder = orders[key];
        if (removedOrder < 1)
            return; // already disabled, nothing to do
        orders[key] = -1;
        // Compact: shift down any layout that was positioned after the removed one.
        for (auto it = orders.begin(); it != orders.end(); ++it) {
            if (it.value() > removedOrder) {
                it.value() -= 1;
            }
        }
    }

    // Write all updated values back.
    for (auto it = orders.cbegin(); it != orders.cend(); ++it) {
        setKWinConfig(it.key(), QString::number(it.value()));
    }
}

void KrohnkiteConfig::refresh() {
    m_screenGapBetween = getKWinConfig("screenGapBetween", "10").toInt();
    m_screenGapBottom = getKWinConfig("screenGapBottom", "4").toInt();
    m_screenGapLeft = getKWinConfig("screenGapLeft", "4").toInt();
    m_screenGapRight = getKWinConfig("screenGapRight", "4").toInt();
    m_screenGapTop = getKWinConfig("screenGapTop", "4").toInt();
    emit gapsChanged();

    m_ignoreClass =
        getKWinConfig("ignoreClass", "krunner,yakuake,spectacle,kded5,xwaylandvideobridge,plasmashell,ksplashqml,org."
                                     "kde.plasmashell,org.kde.polkit-kde-authentication-agent-1,quickshell");
    emit ignoreClassChanged();

    for (const auto& entry : allLayoutDefaults()) {
        bool ok = false;
        int v = getKWinConfig(QLatin1String(entry.key), QString::number(entry.defaultOrder)).toInt(&ok);
        bool isEnabled = (ok && v >= 1);
        const QLatin1String k(entry.key);
        if (k == "binaryTreeLayoutOrder")
            m_binaryTreeLayoutEnabled = isEnabled;
        else if (k == "cascadeLayoutOrder")
            m_cascadeLayoutEnabled = isEnabled;
        else if (k == "columnsLayoutOrder")
            m_columnsLayoutEnabled = isEnabled;
        else if (k == "floatingLayoutOrder")
            m_floatingLayoutEnabled = isEnabled;
        else if (k == "monocleLayoutOrder")
            m_monocleLayoutEnabled = isEnabled;
        else if (k == "quarterLayoutOrder")
            m_quarterLayoutEnabled = isEnabled;
        else if (k == "spiralLayoutOrder")
            m_spiralLayoutEnabled = isEnabled;
        else if (k == "spreadLayoutOrder")
            m_spreadLayoutEnabled = isEnabled;
        else if (k == "stackedLayoutOrder")
            m_stackedLayoutEnabled = isEnabled;
        else if (k == "stairLayoutOrder")
            m_stairLayoutEnabled = isEnabled;
        else if (k == "threeColumnLayoutOrder")
            m_threeColumnLayoutEnabled = isEnabled;
        else if (k == "tileLayoutOrder")
            m_tileLayoutEnabled = isEnabled;
    }
    emit layoutsChanged();
}

void KrohnkiteConfig::apply() {
    // Notify KWin to reconfigure
    QDBusMessage msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"), QStringLiteral("reconfigure"));
    QDBusConnection::sessionBus().call(msg, QDBus::NoBlock);
}

void KrohnkiteConfig::setScreenGapBetween(int gap) {
    if (m_screenGapBetween != gap) {
        m_screenGapBetween = gap;
        setKWinConfig("screenGapBetween", QString::number(gap));
        emit gapsChanged();
    }
}

void KrohnkiteConfig::setScreenGapBottom(int gap) {
    if (m_screenGapBottom != gap) {
        m_screenGapBottom = gap;
        setKWinConfig("screenGapBottom", QString::number(gap));
        emit gapsChanged();
    }
}

void KrohnkiteConfig::setScreenGapLeft(int gap) {
    if (m_screenGapLeft != gap) {
        m_screenGapLeft = gap;
        setKWinConfig("screenGapLeft", QString::number(gap));
        emit gapsChanged();
    }
}

void KrohnkiteConfig::setScreenGapRight(int gap) {
    if (m_screenGapRight != gap) {
        m_screenGapRight = gap;
        setKWinConfig("screenGapRight", QString::number(gap));
        emit gapsChanged();
    }
}

void KrohnkiteConfig::setScreenGapTop(int gap) {
    if (m_screenGapTop != gap) {
        m_screenGapTop = gap;
        setKWinConfig("screenGapTop", QString::number(gap));
        emit gapsChanged();
    }
}

void KrohnkiteConfig::setIgnoreClass(const QString& classes) {
    if (m_ignoreClass != classes) {
        m_ignoreClass = classes;
        setKWinConfig("ignoreClass", classes);
        emit ignoreClassChanged();
    }
}

void KrohnkiteConfig::setBinaryTreeLayoutEnabled(bool enabled) {
    if (m_binaryTreeLayoutEnabled != enabled) {
        m_binaryTreeLayoutEnabled = enabled;
        setLayoutEnabled("binaryTreeLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setCascadeLayoutEnabled(bool enabled) {
    if (m_cascadeLayoutEnabled != enabled) {
        m_cascadeLayoutEnabled = enabled;
        setLayoutEnabled("cascadeLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setColumnsLayoutEnabled(bool enabled) {
    if (m_columnsLayoutEnabled != enabled) {
        m_columnsLayoutEnabled = enabled;
        setLayoutEnabled("columnsLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setFloatingLayoutEnabled(bool enabled) {
    if (m_floatingLayoutEnabled != enabled) {
        m_floatingLayoutEnabled = enabled;
        setLayoutEnabled("floatingLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setMonocleLayoutEnabled(bool enabled) {
    if (m_monocleLayoutEnabled != enabled) {
        m_monocleLayoutEnabled = enabled;
        setLayoutEnabled("monocleLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setQuarterLayoutEnabled(bool enabled) {
    if (m_quarterLayoutEnabled != enabled) {
        m_quarterLayoutEnabled = enabled;
        setLayoutEnabled("quarterLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setSpiralLayoutEnabled(bool enabled) {
    if (m_spiralLayoutEnabled != enabled) {
        m_spiralLayoutEnabled = enabled;
        setLayoutEnabled("spiralLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setSpreadLayoutEnabled(bool enabled) {
    if (m_spreadLayoutEnabled != enabled) {
        m_spreadLayoutEnabled = enabled;
        setLayoutEnabled("spreadLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setStackedLayoutEnabled(bool enabled) {
    if (m_stackedLayoutEnabled != enabled) {
        m_stackedLayoutEnabled = enabled;
        setLayoutEnabled("stackedLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setStairLayoutEnabled(bool enabled) {
    if (m_stairLayoutEnabled != enabled) {
        m_stairLayoutEnabled = enabled;
        setLayoutEnabled("stairLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setThreeColumnLayoutEnabled(bool enabled) {
    if (m_threeColumnLayoutEnabled != enabled) {
        m_threeColumnLayoutEnabled = enabled;
        setLayoutEnabled("threeColumnLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

void KrohnkiteConfig::setTileLayoutEnabled(bool enabled) {
    if (m_tileLayoutEnabled != enabled) {
        m_tileLayoutEnabled = enabled;
        setLayoutEnabled("tileLayoutOrder", enabled);
        emit layoutsChanged();
    }
}

} // namespace caelestia::services
