pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.nexus.common
import api 1.0

PageBase {
    id: root

    title: qsTr("Plugins")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Installed Plugins")
        }

        Repeater {
            model: CaelestiaApi.plugins.available

            delegate: ToggleRow {
                Layout.fillWidth: true
                first: index === 0
                last: index === (CaelestiaApi.plugins.available.count - 1)
                
                text: name
                subtext: path
                
                checked: enabled
                onToggled: {
                    PluginLoader.setPluginEnabled(name, checked);
                    // Shell restart is required to apply plugin changes completely
                    // but we update the settings immediately.
                }
            }
        }
        
        ConnectedRect {
            visible: CaelestiaApi.plugins.available.count === 0
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: status.implicitHeight + Tokens.padding.largeIncreased * 2

            RowLayout {
                id: status

                anchors.fill: parent
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    Layout.alignment: Qt.AlignTop
                    text: "extension_off"
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("No plugins installed")
                        font: Tokens.font.title.medium
                    }
                }
            }
        }
    }
}
