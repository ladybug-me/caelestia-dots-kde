pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.nexus.common

PageBase {
    id: root
    
    title: qsTr("Plugins")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            text: qsTr("Automatic Updates")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Check for updates in background")
            subtext: qsTr("Periodically check GitHub for new Caelestia shell updates")
            checked: GlobalConfig.general.checkUpdates
            onClicked: GlobalConfig.general.checkUpdates = !GlobalConfig.general.checkUpdates
        }

        SectionHeader {
            text: qsTr("Installed Plugins")
        }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.extraLarge * 4

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Tokens.padding.extraSmall

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "extension"
                    color: Colours.palette.m3onSurface
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No third-party plugins installed")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.large
                }
            }
        }
    }
}
