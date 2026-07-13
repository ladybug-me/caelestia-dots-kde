pragma ComponentBehavior: Bound

import QtQuick.Layouts
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Taskbar Elements")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Main sections")
        }

        NavRow {
            first: true
            icon: "workspaces"
            label: qsTr("Workspaces")
            status: qsTr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "web_asset"
            label: qsTr("Active window")
            status: qsTr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "widgets"
            label: qsTr("Tray")
            status: qsTr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            label: qsTr("Status icons")
            status: qsTr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            icon: "schedule"
            label: qsTr("Clock")
            status: qsTr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        NavRow {
            icon: "dock"
            label: qsTr("Dock")
            status: Strings.localizeEnglishSpelling(qsTr("Positioning, recolouring"))
            onClicked: root.nState.openSubPage(11)
        }

        NavRow {
            last: true
            icon: "code"
            label: qsTr("GitHub")
            status: qsTr("Contributions, token setup")
            onClicked: root.nState.openSubPage(12)
        }
    }
}
