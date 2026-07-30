#include "krohnkiteconfig.hpp"
#include <QProcess>
#include <QDebug>
#include <QtDBus/QDBusConnection>
#include <QtDBus/QDBusMessage>

namespace caelestia::services {

KrohnkiteConfig::KrohnkiteConfig(QObject* parent) : QObject(parent) {
    refresh();
}

KrohnkiteConfig::~KrohnkiteConfig() = default;

void KrohnkiteConfig::setKWinConfig(const QString& key, const QString& value) {
    QStringList args;
    args << QStringLiteral("--file") << QStringLiteral("kwinrc")
         << QStringLiteral("--group") << QStringLiteral("Script-krohnkite")
         << QStringLiteral("--key") << key
         << value;
    
    QProcess::execute(QStringLiteral("kwriteconfig6"), args);
}

QString KrohnkiteConfig::getKWinConfig(const QString& key, const QString& defaultValue) {
    QProcess process;
    QStringList args;
    args << QStringLiteral("--file") << QStringLiteral("kwinrc")
         << QStringLiteral("--group") << QStringLiteral("Script-krohnkite")
         << QStringLiteral("--key") << key;
         
    process.start(QStringLiteral("kreadconfig6"), args);
    if (process.waitForFinished() && process.exitCode() == 0) {
        QString out = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            return out;
        }
    }
    return defaultValue;
}

bool KrohnkiteConfig::isLayoutEnabled(const QString& key) {
    QString val = getKWinConfig(key, "-1");
    return val != "-1" && val.toInt() >= 0;
}

void KrohnkiteConfig::setLayoutEnabled(const QString& key, bool enabled) {
    if (enabled) {
        // If it was disabled (-1) or missing, we set it to 0 (default order). 
        // We might want to be more sophisticated with ordering, but 0 enables it.
        QString val = getKWinConfig(key, "-1");
        if (val == "-1" || val.toInt() < 0) {
            setKWinConfig(key, "0");
        }
    } else {
        setKWinConfig(key, "-1");
    }
}

void KrohnkiteConfig::refresh() {
    m_screenGapBetween = getKWinConfig("screenGapBetween", "10").toInt();
    m_screenGapBottom = getKWinConfig("screenGapBottom", "4").toInt();
    m_screenGapLeft = getKWinConfig("screenGapLeft", "4").toInt();
    m_screenGapRight = getKWinConfig("screenGapRight", "4").toInt();
    m_screenGapTop = getKWinConfig("screenGapTop", "4").toInt();
    emit gapsChanged();

    m_ignoreClass = getKWinConfig("ignoreClass", "krunner,yakuake,spectacle,kded5,xwaylandvideobridge,plasmashell,ksplashqml,org.kde.plasmashell,org.kde.polkit-kde-authentication-agent-1,quickshell");
    emit ignoreClassChanged();

    m_binaryTreeLayoutEnabled = isLayoutEnabled("binaryTreeLayoutOrder");
    m_cascadeLayoutEnabled = isLayoutEnabled("cascadeLayoutOrder");
    m_columnsLayoutEnabled = isLayoutEnabled("columnsLayoutOrder");
    m_floatingLayoutEnabled = isLayoutEnabled("floatingLayoutOrder");
    m_monocleLayoutEnabled = isLayoutEnabled("monocleLayoutOrder");
    m_quarterLayoutEnabled = isLayoutEnabled("quarterLayoutOrder");
    m_spiralLayoutEnabled = isLayoutEnabled("spiralLayoutOrder");
    m_spreadLayoutEnabled = isLayoutEnabled("spreadLayoutOrder");
    m_stackedLayoutEnabled = isLayoutEnabled("stackedLayoutOrder");
    m_stairLayoutEnabled = isLayoutEnabled("stairLayoutOrder");
    m_threeColumnLayoutEnabled = isLayoutEnabled("threeColumnLayoutOrder");
    m_tileLayoutEnabled = isLayoutEnabled("tileLayoutOrder");
    emit layoutsChanged();
}

void KrohnkiteConfig::apply() {
    // Notify KWin to reconfigure
    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("/KWin"),
        QStringLiteral("org.kde.KWin"),
        QStringLiteral("reconfigure")
    );
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
