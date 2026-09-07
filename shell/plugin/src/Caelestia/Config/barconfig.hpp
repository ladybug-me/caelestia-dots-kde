#pragma once

#include "../Settings/objectnode.hpp"
#include "common.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

class BarScrollActions : public settings::ObjectNode {
    CONFIG_NODE(BarScrollActions, settings::ObjectNode)

    CONFIG_PROPERTY(bool, workspaces, true)
    CONFIG_PROPERTY(bool, volume, true)
    CONFIG_PROPERTY(bool, brightness, true)

};

class BarPopouts : public settings::ObjectNode {
    CONFIG_NODE(BarPopouts, settings::ObjectNode)

    CONFIG_PROPERTY(bool, greeter, true)
    CONFIG_PROPERTY(bool, activeWindow, true)
    CONFIG_PROPERTY(bool, tray, true)
    CONFIG_PROPERTY(bool, statusIcons, true)

};

class BarWorkspaces : public settings::ObjectNode {
    CONFIG_NODE(BarWorkspaces, settings::ObjectNode)

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
    CONFIG_GLOBAL_PROPERTY(QVariantList, specialWorkspaceIcons, QVariantList())
    CONFIG_GLOBAL_PROPERTY(QVariantList, windowIcons,
        { vmap({
            { u"regex"_s, u"steam(_app_(default|[0-9]+))?"_s },
            { u"icon"_s, u"sports_esports"_s },
        }) })
    CONFIG_GLOBAL_PROPERTY(QVariantList, wsIcons, QVariantList())

};

class BarGreeter : public settings::ObjectNode {
    CONFIG_NODE(BarGreeter, settings::ObjectNode)

    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_PROPERTY(bool, inverted, false)
    CONFIG_PROPERTY(bool, showOnHover, true)

    CONFIG_PROPERTY(QString, mode, u"timeOfDay"_s)

    // Time of day GIFs
    CONFIG_PROPERTY(QString, morningGif, u"root:/assets/morning.gif"_s)
    CONFIG_PROPERTY(QString, afternoonGif, u"root:/assets/afternoon.gif"_s)
    CONFIG_PROPERTY(QString, eveningGif, u"root:/assets/evening.gif"_s)
    CONFIG_PROPERTY(QString, nightGif, u"root:/assets/night.gif"_s)

    // Time of day period start hours (0-23)
    CONFIG_PROPERTY(int, morningStart, 5)
    CONFIG_PROPERTY(int, afternoonStart, 12)
    CONFIG_PROPERTY(int, eveningStart, 17)
    CONFIG_PROPERTY(int, nightStart, 20)

    // Greeting texts (supports {user})
    CONFIG_PROPERTY(QString, morningText, u"Good Morning"_s)
    CONFIG_PROPERTY(QString, afternoonText, u"Good Afternoon"_s)
    CONFIG_PROPERTY(QString, eveningText, u"Good Evening"_s)
    CONFIG_PROPERTY(QString, nightText, u"Good Night"_s)

    // Slideshow settings
    CONFIG_PROPERTY(QString, slideshowText, u""_s)
    CONFIG_PROPERTY(QString, slideshowIcon, u"waving_hand"_s)
    CONFIG_PROPERTY(QStringList, slideshowFolders, QStringList())
    CONFIG_PROPERTY(QStringList, slideshowGifs,
        DEFAULT_ARG({
            u"root:/assets/morning.gif"_s,
            u"root:/assets/afternoon.gif"_s,
            u"root:/assets/evening.gif"_s,
            u"root:/assets/night.gif"_s
        }))
    CONFIG_PROPERTY(qreal, slideshowInterval, 60.0)
    CONFIG_PROPERTY(bool, slideshowRandom, false)

};

class BarTray : public settings::ObjectNode {
    CONFIG_NODE(BarTray, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, recolour, false)
    CONFIG_PROPERTY(bool, compact, true)
    CONFIG_GLOBAL_PROPERTY(QVariantList, iconSubs, QVariantList())
    CONFIG_GLOBAL_PROPERTY(QStringList, hiddenIcons, QStringList())

};

class BarStatus : public settings::ObjectNode {
    CONFIG_NODE(BarStatus, settings::ObjectNode)

    CONFIG_PROPERTY(bool, showAudio, true)
    CONFIG_PROPERTY(bool, showMicrophone, false)
    CONFIG_PROPERTY(bool, showKbLayout, false)
    CONFIG_PROPERTY(bool, showNetwork, true)
    CONFIG_PROPERTY(bool, showWifi, true)
    CONFIG_PROPERTY(bool, showBluetooth, true)
    CONFIG_PROPERTY(bool, showBattery, true)
    CONFIG_PROPERTY(bool, showPeripheralBattery, false)
    CONFIG_PROPERTY(QStringList, peripheralBatteryExcluded, QStringList())
    CONFIG_PROPERTY(bool, showLockStatus, true)
    CONFIG_PROPERTY(bool, showNotifications, true)
    CONFIG_PROPERTY(bool, showNightLight, true)

};

class BarClock : public settings::ObjectNode {
    CONFIG_NODE(BarClock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showDate, false)
    CONFIG_PROPERTY(bool, showIcon, true)
    CONFIG_PROPERTY(bool, centerClock, false)

};

class BarDock : public settings::ObjectNode {
    CONFIG_NODE(BarDock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, monitorCenter, true)
    CONFIG_PROPERTY(bool, recolourIcons, false)
    CONFIG_PROPERTY(int, iconSize, 32)

};

class BarGithub : public settings::ObjectNode {
    CONFIG_NODE(BarGithub, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)

};

class BarPerformance : public settings::ObjectNode {
    CONFIG_NODE(BarPerformance, settings::ObjectNode)

    CONFIG_PROPERTY(bool, showText, true)

};

class BarPreviewScales : public settings::ObjectNode {
    CONFIG_NODE(BarPreviewScales, settings::ObjectNode)

    CONFIG_PROPERTY(qreal, greeter, 0.0)
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

};

class BarPreviewFontScales : public settings::ObjectNode {
    CONFIG_NODE(BarPreviewFontScales, settings::ObjectNode)

    CONFIG_PROPERTY(qreal, greeter, 0.0)
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

};

class BarConfig : public settings::ObjectNode {
    CONFIG_NODE(BarConfig, settings::ObjectNode)

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
    CONFIG_SUBOBJECT(BarGreeter, greeter)
    CONFIG_SUBOBJECT(BarGreeter, activeWindow)
    CONFIG_SUBOBJECT(BarTray, tray)
    CONFIG_SUBOBJECT(BarStatus, status)
    CONFIG_SUBOBJECT(BarClock, clock)
    CONFIG_SUBOBJECT(BarDock, dock)
    CONFIG_SUBOBJECT(BarGithub, github)
    CONFIG_SUBOBJECT(BarPerformance, performance)
    CONFIG_PROPERTY(QVariantList, entries,
        DEFAULT_ARG({
            vmap({ { u"id"_s, u"logo"_s }, { u"enabled"_s, true }, { u"zone"_s, u"left"_s } }),
            vmap({ { u"id"_s, u"workspaces"_s }, { u"enabled"_s, true }, { u"zone"_s, u"left"_s } }),
            vmap({ { u"id"_s, u"greeter"_s }, { u"enabled"_s, true }, { u"zone"_s, u"left"_s } }),
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
        }))
    CONFIG_PROPERTY(QStringList, excludedScreens, QStringList())

};

} // namespace caelestia::config
