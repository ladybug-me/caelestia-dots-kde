import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Main surfaces")
        }

        NavRow {
            first: true
            icon: "dashboard"
            label: qsTr("Dashboard")
            status: Config.dashboard.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            last: true
            icon: "dock_to_bottom"
            label: qsTr("Taskbar")
            status: Config.bar.persistent ? qsTr("Always visible") : Config.bar.showOnHover ? qsTr("Reveal on hover") : qsTr("Reveal on drag")
            onClicked: root.nState.openSubPage(2)
        }

        SectionHeader {
            text: qsTr("Launch & utilities")
        }

        NavRow {
            first: true
            icon: "apps"
            label: qsTr("Launcher")
            status: Config.launcher.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            last: true
            icon: "dock_to_right"
            label: qsTr("Sidebar")
            status: Config.sidebar.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: root.nState.openSubPage(4)
        }
    }
}
