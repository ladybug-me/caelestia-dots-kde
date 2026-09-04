pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Clock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Background")
            checked: root.nState.targetConfig.bar.clock.background
            onToggled: Globalroot.nState.targetConfig.bar.clock.background = checked
        }

        ToggleRow {
            text: qsTr("Show date")
            checked: root.nState.targetConfig.bar.clock.showDate
            onToggled: Globalroot.nState.targetConfig.bar.clock.showDate = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Show icon")
            checked: root.nState.targetConfig.bar.clock.showIcon
            onToggled: Globalroot.nState.targetConfig.bar.clock.showIcon = checked
        }
    }
}
