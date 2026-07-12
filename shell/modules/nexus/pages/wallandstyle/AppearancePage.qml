pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    isSubPage: true
    title: qsTr("Appearance")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.padding.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            ToggleRow {
                Layout.fillWidth: true
                first: true
                text: qsTr("Bezel mode (Pitch black)")
                subtext: qsTr("Make the shell pitch black to blend with display bezels")
                checked: Config.appearance.pitchBlack
                onToggled: GlobalConfig.appearance.pitchBlack = checked
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: qsTr("Islands")
                subtext: qsTr("Everything appears as its own floating widget (Very Experimental)")
                checked: GlobalConfig.appearance.islands
                onToggled: GlobalConfig.appearance.islands = checked
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: qsTr("Transparency")
                subtext: qsTr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
                checked: Colours.transparency.enabled
                onToggled: GlobalConfig.appearance.transparency.enabled = checked
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                last: true
                text: qsTr("Dark theme")
                checked: !Colours.light
                onToggled: Colours.setMode(checked ? "dark" : "light")
            }
        }
    }
}
