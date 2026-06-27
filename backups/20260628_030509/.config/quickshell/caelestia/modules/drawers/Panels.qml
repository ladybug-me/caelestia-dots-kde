import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property DrawerVisibilities visibilities
    required property Bar.BarWrapper bar
    required property real borderThickness

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

    readonly property real leftMargin: anchors.leftMargin
    readonly property real rightMargin: anchors.rightMargin
    readonly property real topMargin: anchors.topMargin
    readonly property real bottomMargin: anchors.bottomMargin

    anchors.fill: parent
    anchors.leftMargin: (Config.bar.position === "left" ? bar.implicitWidth + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))
    anchors.rightMargin: (Config.bar.position === "right" ? bar.implicitWidth + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))
    anchors.topMargin: (Config.bar.position === "top" ? bar.implicitHeight + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))
    anchors.bottomMargin: (Config.bar.position === "bottom" ? bar.implicitHeight + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge * 2 : 0) : borderThickness + (GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0))

    states: [
        State {
            name: "right"
            Config.screen: root.screen.name
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
                target: notifications
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
            Config.screen: root.screen.name
            when: Config.bar.position === "bottom"

            AnchorChanges {
                target: notifications
                anchors.top: undefined
                anchors.bottom: parent.bottom
            }
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
                anchors.bottom: notifications.top
            }
            PropertyChanges {
                target: sidebar
                anchors.topMargin: -4
            }
        }
    ]

    Item {
        id: osdWrapper

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

        property bool shouldPush: popoutsWrapper.offsetScale < 1 && !popoutsWrapper.content.isDockPopout && !sidebar.visible

        visibilities: root.visibilities
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper
        utilitiesPanel: utilities

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: (Config.bar.position === "top" && shouldPush) ? (popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge) : 0
        anchors.bottomMargin: (Config.bar.position === "bottom" && shouldPush) ? (popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge) : 0
    }

    Item {
        id: sessionWrapper

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

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {
        id: dashboard

        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        bar: root.bar
        borderThickness: root.borderThickness
        visibilities: root.visibilities
    }

    Utilities.Wrapper {
        id: utilities

        visibilities: root.visibilities
        sidebar: sidebar
        popouts: popoutsWrapper.content

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: sidebar.left
        anchors.margins: Tokens.padding.medium
    }

    Sidebar.Wrapper {
        id: sidebar

        visibilities: root.visibilities
        popouts: popoutsWrapper.content
        utilities: utilities

        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
        property bool shouldPush: popoutsWrapper.offsetScale < 1 && !popoutsWrapper.content.isDockPopout

        anchors.topMargin: (Config.bar.position === "top" && shouldPush) ? (popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge) : -notifications.anchors.topMargin
        anchors.bottomMargin: (Config.bar.position === "bottom" && shouldPush) ? (popoutsWrapper.implicitHeight + Tokens.spacing.extraLarge) : 0
    }
}
