pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Add network")
    isSubPage: true

    property bool hiddenNetwork: false

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Wi-Fi details")
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: formLayout.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: formLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small

                StyledTextField {
                    id: ssidField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Network name (SSID)")
                }

                StyledTextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password")
                    echoMode: TextInput.Password
                }

                ToggleRow {
                    text: qsTr("Hidden network")
                    checked: root.hiddenNetwork
                    onToggled: root.hiddenNetwork = checked
                }
            }
        }

        ButtonRow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ButtonBase {
                fillWidth: true
                text: qsTr("Connect")
                onClicked: {
                    const ssid = ssidField.text.trim();
                    if (!ssid)
                        return;

                    NetworkConnection.connectWithPassword({ ssid: ssid, bssid: "" }, passwordField.text, result => {
                        if (result?.success)
                            root.nState.closeSubPage();
                    });
                }
            }

            ButtonBase {
                fillWidth: true
                text: qsTr("Cancel")
                inactiveColour: Colours.palette.m3surfaceContainerHighest
                inactiveOnColour: Colours.palette.m3onSurface
                onClicked: root.nState.closeSubPage()
            }
        }
    }
}