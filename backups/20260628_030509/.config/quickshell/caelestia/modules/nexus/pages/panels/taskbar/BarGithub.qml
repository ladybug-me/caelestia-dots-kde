pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common
import qs.services
import Quickshell
import Quickshell.Io

PageBase {
    id: root

    title: qsTr("GitHub")
    isSubPage: true

    function saveToken(token) {
        if (!token) {
            Quickshell.execDetached(["secret-tool", "clear", "service", "caelestia-shell", "account", "github"]);
        } else {
            Quickshell.execDetached(["bash", "-c", "secret-tool store --label=\"Caelestia GitHub Token\" service caelestia-shell account github <<< \"$1\"", "--", token]);
        }
    }

    property Process readTokenProc: Process {
        id: readTokenProc
        command: ["secret-tool", "lookup", "service", "caelestia-shell", "account", "github"]
        stdout: StdioCollector {
            onStreamFinished: {
                tokenInput.text = text.trim();
            }
        }
    }

    Component.onCompleted: readTokenProc.running = true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Configuration")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Component background")
            subtext: qsTr("Render a solid background behind the GitHub activity widget")
            checked: Config.bar.github.background
            onToggled: GlobalConfig.bar.github.background = checked
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: contentRow.implicitHeight + Tokens.padding.medium * 2

            ConnectedRect {
                id: bg
                anchors.fill: parent
                last: true
            }

            RowLayout {
                id: contentRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                Column {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: qsTr("Personal Access Token")
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: qsTr("Used to fetch your contribution graph (read:user)")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3outline
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 32
                    radius: Tokens.rounding.small
                    color: Colours.layer(Colours.palette.m3surfaceVariant, 2)
                    
                    StyledTextField {
                        id: tokenInput
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        verticalAlignment: TextInput.AlignVCenter
                        placeholderText: "ghp_..."
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        onAccepted: root.saveToken(text)
                    }
                }

                IconButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    icon: "save"
                    onClicked: root.saveToken(tokenInput.text)
                }

                IconButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    icon: "close"
                    onClicked: {
                        tokenInput.text = ""
                        root.saveToken("")
                    }
                }
            }
        }
    }
}
