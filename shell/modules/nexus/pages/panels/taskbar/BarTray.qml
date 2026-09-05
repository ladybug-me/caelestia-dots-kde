pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Tray")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Background")
            checked: root.nState.targetConfig.bar.tray.background
            onToggled: Globalroot.nState.targetConfig.bar.tray.background = checked
        }

        ToggleRow {
            text: qsTr("Recolor icons")
            checked: root.nState.targetConfig.bar.tray.recolour
            onToggled: Globalroot.nState.targetConfig.bar.tray.recolour = checked
        }

        ToggleRow {
            text: qsTr("Compact")
            checked: root.nState.targetConfig.bar.tray.compact
            onToggled: Globalroot.nState.targetConfig.bar.tray.compact = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show the tray menu popout when hovering")
            checked: root.nState.targetConfig.bar.popouts.tray
            onToggled: Globalroot.nState.targetConfig.bar.popouts.tray = checked
        }
    }
}
