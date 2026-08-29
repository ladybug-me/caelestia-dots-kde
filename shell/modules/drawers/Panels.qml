import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.overview as Overview
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property real overviewBorderThickness
    property var overviewAnimConfig
    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar
    readonly property alias overview: overview
    readonly property real leftMargin: anchors.leftMargin
    readonly property real rightMargin: anchors.rightMargin
    readonly property real topMargin: anchors.topMargin
    readonly property real bottomMargin: anchors.bottomMargin
    // Screen-relative cursor position, updated by ContentWindow from interactions.mouseX/Y
    property point cursorPos
    // Resolved position string: auto → bar-derived, manual → as-is.
    // When auto + cursor is in the default corner (no popups showing), flip to opposite corner.
    // Resets to bar-derived corner on next notification arrival.
    readonly property string notifAutoPosition: {
        const barPos = Config.bar.position;
        const v = barPos === "bottom" ? "bottom" : "top";
        const h = barPos === "right" ? "left" : "right";
        return `${v}-${h}`;
    }
    property bool notifAutoFlipped: false
    property int _prevPopupCount: 0
    readonly property string notifPosition: {
        if (GlobalConfig.notifs.position !== "auto")
            return GlobalConfig.notifs.position;
        if (notifAutoFlipped) {
            const parts = notifAutoPosition.split("-");
            const v = parts[0] === "top" ? "bottom" : "top";
            const h = parts[1] === "left" ? "right" : "left";
            return `${v}-${h}`;
        }
        return notifAutoPosition;
    }
    readonly property bool notifAtTop: notifPosition.startsWith("top")
    readonly property bool notifAtBottom: notifPosition.startsWith("bottom")
    // Height of the notification region, for other items to reference
    readonly property real notifReservedHeight: notifications.implicitHeight > 0 ? notifications.implicitHeight + Tokens.spacing.extraLarge : 0

    readonly property bool popoutIntersectsRight: {
        if (!popoutsWrapper.visible || popoutsWrapper.offsetScale >= 1) return false;
        if (Config.bar.position === "top" || Config.bar.position === "bottom") {
            const notifLeft = notifications.x;
            const notifRight = notifLeft + (notifications.implicitWidth > 0 ? notifications.implicitWidth : Tokens.sizes.notifs.width);
            const popLeft = popoutsWrapper.x;
            const popRight = popoutsWrapper.x + popoutsWrapper.content.nonAnimWidth;
            return popLeft < notifRight && popRight > notifLeft;
        } else {
            const notifTop = notifications.y;
            const notifBottom = notifTop + (notifications.implicitHeight > 0 ? notifications.implicitHeight : 300);
            const popTop = popoutsWrapper.y;
            const popBottom = popoutsWrapper.y + popoutsWrapper.content.nonAnimHeight;
            return popTop < notifBottom && popBottom > notifTop;
        }
    }

    readonly property bool popoutIntersectsSidebar: {
        if (!popoutsWrapper.visible || popoutsWrapper.offsetScale >= 1) return false;
        if (!sidebar.visible) return false;
        if (Config.bar.position === "top" || Config.bar.position === "bottom") {
            const sideLeft = sidebar.x;
            const sideRight = sideLeft + sidebar.width;
            const popLeft = popoutsWrapper.x;
            const popRight = popoutsWrapper.x + popoutsWrapper.content.nonAnimWidth;
            return popLeft < sideRight && popRight > sideLeft;
        } else {
            const sideTop = sidebar.y;
            const sideBottom = sideTop + sidebar.height;
            const popTop = popoutsWrapper.y;
            const popBottom = popoutsWrapper.y + popoutsWrapper.content.nonAnimHeight;
            return popTop < sideBottom && popBottom > sideTop;
        }
    }

    anchors.fill: parent
    anchors.leftMargin: (Config.bar.position === "left" ? bar.implicitWidth + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))
    anchors.rightMargin: (Config.bar.position === "right" ? bar.implicitWidth + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))
    anchors.topMargin: (Config.bar.position === "top" ? bar.implicitHeight + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))
    anchors.bottomMargin: (Config.bar.position === "bottom" ? bar.implicitHeight + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))
    states: [
        State {
            name: "right"
            when: Config.bar.position === "right"

            AnchorChanges {
                target: osdWrapper
                anchors.left: parent.left
                anchors.right: undefined
            }
            AnchorChanges {
                target: osd
                anchors.left: parent.left
                anchors.right: undefined
            }
            AnchorChanges {
                target: sessionWrapper
                anchors.left: parent.left
                anchors.right: undefined
            }
            AnchorChanges {
                target: session
                anchors.left: parent.left
                anchors.right: undefined
            }
            AnchorChanges {
                target: utilities
                anchors.left: parent.left
                anchors.right: undefined
            }
            AnchorChanges {
                target: toasts
                anchors.left: sidebar.right
                anchors.right: undefined
            }
            AnchorChanges {
                target: sidebar
                anchors.left: parent.left
                anchors.right: undefined
            }
        },
        State {
            name: "bottom"
            when: Config.bar.position === "bottom"

            AnchorChanges {
                target: utilities
                anchors.bottom: undefined
                anchors.top: parent.top
            }
            AnchorChanges {
                target: toasts
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: undefined
            }
            AnchorChanges {
                target: sidebar
                anchors.top: utilities.bottom
                anchors.bottom: parent.bottom
            }
            PropertyChanges {
                target: sidebar
                anchors.topMargin: -4
                anchors.bottomMargin: (root.notifAtBottom ? root.notifReservedHeight : 0)
                    + (sidebar.shouldPush ? popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge : 0)
            }
        }
    ]

    Item {
        id: osdWrapper

        property string vAnchor: "center"
        property string hAnchor: Config.bar.position === "right" ? "left" : "right"

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.leftMargin: Config.bar.position === "right" ? sidebar.width * (1 - sidebar.offsetScale) + session.width * (1 - session.offsetScale) : 0
        anchors.rightMargin: Config.bar.position !== "right" ? sidebar.width * (1 - sidebar.offsetScale) + session.width * (1 - session.offsetScale) : 0
        clip: sidebar.visible || session.visible
        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight
        visible: osd.offsetScale < 1

        Osd.Wrapper {
            id: osd

            screen: root.screen
            visibilities: root.visibilities
            sidebarOrSessionVisible: sidebar.visible || session.visible
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }
    Notifications.Wrapper {
        id: notifications

        readonly property string _notifV: root.notifPosition.split("-")[0]
        readonly property string _notifH: root.notifPosition.split("-")[1]
        property string vAnchor: _notifV
        property string hAnchor: _notifH
        property bool shouldPush: root.popoutIntersectsRight && !popoutsWrapper.content.isDockPopout && !sidebar.visible

        // Push offset when a bar popout would overlap this position
        readonly property real _pushOffset: shouldPush ? (popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge) : 0

        visibilities: root.visibilities
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper
        utilitiesPanel: utilities

        // Explicit size — never let anchors stretch the notification region
        width: implicitWidth
        height: implicitHeight

        // Position via x/y — avoids QML anchor-binding issues with conditional clearing
        x: {
            if (_notifH === "left") return 0;
            if (_notifH === "right") return Math.max(0, parent.width - implicitWidth);
            return Math.max(0, (parent.width - implicitWidth) / 2);
        }
        y: {
            if (_notifV === "top") return _pushOffset;
            return Math.max(0, parent.height - implicitHeight - _pushOffset);
        }
    }
    // Auto-avoidance: check cursor position when the first notification of a batch arrives.
    // If cursor is in the default corner, flip to opposite. On close, keep the flip until
    // the next fresh arrival re-evaluates — this prevents a flicker during dismiss animation.
    Connections {
        function onPopupCountChanged() {
            const len = Notifs.popupCount;
            // Only act on 0 → 1 transition (fresh batch arrival)
            if (len > 0 && root._prevPopupCount === 0 && GlobalConfig.notifs.position === "auto") {
                // Taken from notifAutoPosition rather than worked out again:
                // the second copy had drifted (it flipped on "left" where the
                // first flips on "right"), so with a side bar the avoidance
                // watched the corner opposite the one notifications were in.
                const defParts = root.notifAutoPosition.split("-");
                const defV = defParts[0];
                const defH = defParts[1];
                const notifW = Tokens.sizes.notifs.width;
                const notifH = Math.min(root.height / 2, 600);
                // Corner bounds in Panels-relative coordinates
                const panelX = root.cursorPos.x - root.leftMargin;
                const panelY = root.cursorPos.y - root.topMargin;
                const cornerX = defH === "right" ? (root.width - notifW) : 0;
                const cornerY = defV === "bottom" ? (root.height - notifH) : 0;
                const inCorner = panelX >= cornerX && panelX <= cornerX + notifW
                    && panelY >= cornerY && panelY <= cornerY + notifH;
                root.notifAutoFlipped = inCorner;
            }
            // Do NOT reset on close (len === 0) — avoids flicker during dismiss animation.
            // The flip resets implicitly on the next 0→1 transition above.
            root._prevPopupCount = len;
        }

        target: Notifs
    }
    Item {
        id: sessionWrapper

        property string vAnchor: "center"
        property string hAnchor: Config.bar.position === "right" ? "left" : "right"

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.leftMargin: Config.bar.position === "right" ? sidebar.width * (1 - sidebar.offsetScale) : 0
        anchors.rightMargin: Config.bar.position !== "right" ? sidebar.width * (1 - sidebar.offsetScale) : 0
        clip: sidebar.visible
        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight
        visible: session.offsetScale < 1

        Session.Wrapper {
            id: session

            visibilities: root.visibilities
            sidebarVisible: sidebar.visible
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }
    Launcher.Wrapper {
        id: launcher

        property string vAnchor: "bottom"
        property string hAnchor: "center"

        screen: root.screen
        visibilities: root.visibilities
        panels: root
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }
    Dashboard.Wrapper {
        id: dashboard

        property string vAnchor: "top"
        property string hAnchor: "center"

        visibilities: root.visibilities
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }
    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        property string vAnchor: (Config.bar.position === "top" || Config.bar.position === "bottom") ? Config.bar.position : "none"
        property string hAnchor: (Config.bar.position === "left" || Config.bar.position === "right") ? Config.bar.position : "none"

        screen: root.screen
        bar: root.bar
        borderThickness: root.borderThickness
        visibilities: root.visibilities
    }
    Utilities.Wrapper {
        id: utilities

        property string vAnchor: Config.bar.position === "bottom" ? "top" : "bottom"
        property string hAnchor: Config.bar.position === "right" ? "left" : "right"

        visibilities: root.visibilities
        sidebar: sidebar
        popouts: popoutsWrapper.content
        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }
    Toasts.Toasts {
        id: toasts

        property string vAnchor: "bottom"
        property string hAnchor: Config.bar.position === "bottom" ? "left" : (Config.bar.position === "right" ? "left" : "right")

        visibilities: root.visibilities
        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: sidebar.left
        anchors.margins: Tokens.padding.medium
    }
    Sidebar.Wrapper {
        id: sidebar

        property string vAnchor: "bottom"
        property string hAnchor: Config.bar.position === "right" ? "left" : "right"
        property bool shouldPush: root.popoutIntersectsSidebar && !popoutsWrapper.content.isDockPopout

        visibilities: root.visibilities
        popouts: popoutsWrapper.content
        utilities: utilities
        // Default (non-bottom-bar): sidebar fills from top or below notifications (when notif is at top)
        anchors.top: parent.top
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.topMargin: root.notifAtTop
            ? (root.notifReservedHeight + ((Config.bar.position === "top" && shouldPush) ? popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge : 0))
            : ((Config.bar.position === "top" && shouldPush) ? (popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge) : 0)
        anchors.bottomMargin: (Config.bar.position === "bottom" && shouldPush) ? (popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge) : 0
    }
    Overview.Wrapper {
        id: overview

        property string vAnchor: "center"
        property string hAnchor: "center"
        property var animConfig: root.overviewAnimConfig

        screen: root.screen
        visibilities: root.visibilities
        panels: root
    }
}
