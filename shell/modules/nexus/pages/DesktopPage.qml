pragma ComponentBehavior: Bound

import QtQuick.Layouts
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Desktop")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Desktop")
        }

        NavRow {
            first: true
            icon: "extension"
            label: qsTr("Desktop Addons")
            status: qsTr("Clock, Lyrics, Visualiser, Shimeji")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            last: true
            icon: "menu_open"
            label: qsTr("Right Click Menu")
            status: qsTr("Configure desktop right click menu")
            onClicked: root.nState.openSubPage(2)
        }
    }
}
