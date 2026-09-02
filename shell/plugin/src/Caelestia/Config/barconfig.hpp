#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class BarScrollActions : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, workspaces, true)
    CONFIG_PROPERTY(bool, volume, true)
    CONFIG_PROPERTY(bool, brightness, true)

public:
    explicit BarScrollActions(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarPopouts : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, activeWindow, true)
    CONFIG_PROPERTY(bool, tray, true)
    CONFIG_PROPERTY(bool, statusIcons, true)

public:
    explicit BarPopouts(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarWorkspaces : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, shown, 5)
    CONFIG_PROPERTY(bool, activeIndicator, true)
    CONFIG_PROPERTY(bool, occupiedBg, false)
    CONFIG_PROPERTY(bool, showWindows, true)
    CONFIG_PROPERTY(bool, showWindowsOnSpecialWorkspaces, true)
    CONFIG_PROPERTY(int, maxWindowIcons, 5)
    CONFIG_PROPERTY(bool, activeTrail, false)
    CONFIG_PROPERTY(bool, monitorCenter, false)
    CONFIG_GLOBAL_PROPERTY(bool, perMonitorWorkspaces, true)
    CONFIG_PROPERTY(bool, useIcon, true)
    CONFIG_PROPERTY(QString, label, u" "_s)
    CONFIG_PROPERTY(QString, occupiedLabel, u" 󰮯"_s)
    CONFIG_PROPERTY(QString, activeLabel, u"󰮯 "_s)
    CONFIG_PROPERTY(QString, capitalisation, u"preserve"_s)
    CONFIG_GLOBAL_PROPERTY(QVariantList, specialWorkspaceIcons)
    CONFIG_GLOBAL_PROPERTY(QVariantList, windowIcons,
        { vmap({
            { u"regex"_s, u"steam(_app_(default|[0-9]+))?"_s },
            { u"icon"_s, u"sports_esports"_s },
        }) })
    CONFIG_GLOBAL_PROPERTY(QVariantList, wsIcons)

public:
    explicit BarWorkspaces(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarActiveWindow : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_PROPERTY(bool, inverted, false)
    CONFIG_PROPERTY(bool, showOnHover, true)
    // Custom greeting preview images shown in the active-window popout when no
    // window is focused. Empty = use the bundled default for that time of day.
    CONFIG_GLOBAL_PROPERTY(QString, morningGif, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, afternoonGif, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, eveningGif, u""_s)
    CONFIG_GLOBAL_PROPERTY(QString, nightGif, u""_s)

public:
    explicit BarActiveWindow(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarTray : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, recolour, false)
    CONFIG_PROPERTY(bool, compact, true)
    CONFIG_GLOBAL_PROPERTY(QVariantList, iconSubs)
    CONFIG_GLOBAL_PROPERTY(QStringList, hiddenIcons)

public:
    explicit BarTray(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarStatus : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, showAudio, true)
    CONFIG_PROPERTY(bool, showMicrophone, false)
    CONFIG_PROPERTY(bool, showKbLayout, false)
    CONFIG_PROPERTY(bool, showNetwork, true)
    CONFIG_PROPERTY(bool, showWifi, true)
    CONFIG_PROPERTY(bool, showBluetooth, true)
    CONFIG_PROPERTY(bool, showBattery, true)
    CONFIG_PROPERTY(bool, showPeripheralBattery, false)
    CONFIG_PROPERTY(QStringList, peripheralBatteryExcluded)
    CONFIG_PROPERTY(bool, showLockStatus, true)
    CONFIG_PROPERTY(bool, showNotifications, true)
    CONFIG_PROPERTY(bool, showNightLight, true)

public:
    explicit BarStatus(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarClock : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showDate, false)
    CONFIG_PROPERTY(bool, showIcon, true)
    CONFIG_PROPERTY(bool, centerClock, false)

public:
    explicit BarClock(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarDock : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, monitorCenter, true)
    CONFIG_PROPERTY(bool, recolourIcons, false)
    CONFIG_PROPERTY(int, iconSize, 32)

public:
    explicit BarDock(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarGithub : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, background, false)

public:
    explicit BarGithub(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarPerformance : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, showText, true)

public:
    explicit BarPerformance(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarPreviewScales : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(qreal, activeWindow, 0.0)
    CONFIG_PROPERTY(qreal, audio, 0.0)
    CONFIG_PROPERTY(qreal, battery, 0.0)
    CONFIG_PROPERTY(qreal, bluetooth, 0.0)
    CONFIG_PROPERTY(qreal, dock, 0.0)
    CONFIG_PROPERTY(qreal, github, 0.0)
    CONFIG_PROPERTY(qreal, kblayout, 0.0)
    CONFIG_PROPERTY(qreal, lockStatus, 0.0)
    CONFIG_PROPERTY(qreal, network, 0.0)
    CONFIG_PROPERTY(qreal, notifications, 0.0)
    CONFIG_PROPERTY(qreal, peripheralBattery, 0.0)
    CONFIG_PROPERTY(qreal, trayMenu, 0.0)
    CONFIG_PROPERTY(qreal, wirelessPassword, 0.0)

public:
    explicit BarPreviewScales(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarPreviewFontScales : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(qreal, activeWindow, 0.0)
    CONFIG_PROPERTY(qreal, audio, 0.0)
    CONFIG_PROPERTY(qreal, battery, 0.0)
    CONFIG_PROPERTY(qreal, bluetooth, 0.0)
    CONFIG_PROPERTY(qreal, dock, 0.0)
    CONFIG_PROPERTY(qreal, github, 0.0)
    CONFIG_PROPERTY(qreal, kblayout, 0.0)
    CONFIG_PROPERTY(qreal, lockStatus, 0.0)
    CONFIG_PROPERTY(qreal, network, 0.0)
    CONFIG_PROPERTY(qreal, notifications, 0.0)
    CONFIG_PROPERTY(qreal, peripheralBattery, 0.0)
    CONFIG_PROPERTY(qreal, trayMenu, 0.0)
    CONFIG_PROPERTY(qreal, wirelessPassword, 0.0)

public:
    explicit BarPreviewFontScales(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class BarConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(qreal, previewScale, 1.0)
    CONFIG_PROPERTY(bool, previewScaleWithBar, false)
    CONFIG_PROPERTY(bool, perElementPreviewScale, false)
    CONFIG_PROPERTY(bool, perElementFontScale, false)
    CONFIG_PROPERTY(qreal, fontScaleOffset, 0.0)
    // Live PipeWire window thumbnails (dock hover, overview, alt-tab, window info).
    // Disable if screen sharing / camera in other apps (e.g. Vesktop) freezes or
    // crashes - some NVIDIA + KWin setups can't handle KWin's screencast protocol
    // being used by two clients at once.
    CONFIG_PROPERTY(bool, livePreviews, true)
    CONFIG_SUBOBJECT(BarPreviewScales, previewScales)
    CONFIG_SUBOBJECT(BarPreviewFontScales, previewFontScales)
    CONFIG_PROPERTY(bool, persistent, true)
    // Retract the bar while a window overlaps the strip it occupies, and let it
    // come back when nothing is under it. Only meaningful together with
    // persistent — a non-persistent bar is already hidden by default.
    //
    // The bar stops reserving an exclusive zone in this mode: windows have to
    // be allowed to sit under it for the overlap to mean anything, and a
    // reserved zone would push every window off the bar and make the two
    // oscillate.
    CONFIG_PROPERTY(bool, dodgeWindows, false)
    // Narrow dodging to the window you are actually working in. Without this
    // any window over the bar retracts it, so a background window parked there
    // keeps the bar down even while you use something else entirely.
    CONFIG_PROPERTY(bool, dodgeFocusedOnly, false)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(int, dragThreshold, 20)
    CONFIG_PROPERTY(QString, position, u"bottom"_s)
    CONFIG_SUBOBJECT(BarScrollActions, scrollActions)
    CONFIG_SUBOBJECT(BarPopouts, popouts)
    CONFIG_SUBOBJECT(BarWorkspaces, workspaces)
    CONFIG_SUBOBJECT(BarActiveWindow, activeWindow)
    CONFIG_SUBOBJECT(BarTray, tray)
    CONFIG_SUBOBJECT(BarStatus, status)
    CONFIG_SUBOBJECT(BarClock, clock)
    CONFIG_SUBOBJECT(BarDock, dock)
    CONFIG_SUBOBJECT(BarGithub, github)
    CONFIG_SUBOBJECT(BarPerformance, performance)
    CONFIG_PROPERTY(QVariantList, entries,
        {
            vmap({ { u"id"_s, u"logo"_s }, { u"enabled"_s, true }, { u"zone"_s, u"left"_s } }),
            vmap({ { u"id"_s, u"workspaces"_s }, { u"enabled"_s, true }, { u"zone"_s, u"left"_s } }),
            vmap({ { u"id"_s, u"activeWindow"_s }, { u"enabled"_s, true }, { u"zone"_s, u"left"_s } }),
            vmap({ { u"id"_s, u"dock"_s }, { u"enabled"_s, true }, { u"zone"_s, u"middle"_s } }),
            vmap({ { u"id"_s, u"tray"_s }, { u"enabled"_s, true }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"updateIndicator"_s }, { u"enabled"_s, true }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"github"_s }, { u"enabled"_s, true }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"clock"_s }, { u"enabled"_s, true }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"statusIcons"_s }, { u"enabled"_s, true }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"kbLayoutIndicator"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"notificationsIndicator"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"perfCpu"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"perfMemory"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"perfStorage"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"perfNetwork"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"perfGpu"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"perfBattery"_s }, { u"enabled"_s, false }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"showDesktop"_s }, { u"enabled"_s, true }, { u"zone"_s, u"right"_s } }),
            vmap({ { u"id"_s, u"power"_s }, { u"enabled"_s, true }, { u"zone"_s, u"right"_s } }),
        })
    CONFIG_PROPERTY(QStringList, excludedScreens)

public:
    explicit BarConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_previewScales(new BarPreviewScales(this))
        , m_previewFontScales(new BarPreviewFontScales(this))
        , m_scrollActions(new BarScrollActions(this))
        , m_popouts(new BarPopouts(this))
        , m_workspaces(new BarWorkspaces(this))
        , m_activeWindow(new BarActiveWindow(this))
        , m_tray(new BarTray(this))
        , m_status(new BarStatus(this))
        , m_clock(new BarClock(this))
        , m_dock(new BarDock(this))
        , m_github(new BarGithub(this))
        , m_performance(new BarPerformance(this)) {}
};

} // namespace caelestia::config
