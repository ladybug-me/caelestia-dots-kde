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

    readonly property var device: Nmcli.activeEthernet

    title: qsTr("Ethernet")
    isSubPage: true

    Component.onCompleted: Nmcli.getEthernetDeviceDetails("", () => {})

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Connection")
        }

        InfoRow {
            icon: "lan"
            label: qsTr("Interface")
            value: root.device?.interface || qsTr("Not connected")
        }

        InfoRow {
            icon: "router"
            label: qsTr("IP address")
            value: root.device?.ipAddress || qsTr("—")
        }

        InfoRow {
            icon: "dns"
            label: qsTr("Gateway")
            value: root.device?.gateway || qsTr("—")
        }

        InfoRow {
            icon: "memory"
            label: qsTr("MAC address")
            value: root.device?.macAddress || qsTr("—")
        }

        InfoRow {
            icon: "speed"
            label: qsTr("Speed")
            value: root.device?.speed || qsTr("—")
        }

        ButtonRow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ButtonBase {
                fillWidth: true
                text: qsTr("Disconnect")
                onClicked: {
                    if (root.device)
                        Nmcli.disconnectEthernet(root.device.connection || root.device.interface, () => {});
                }
            }

            ButtonBase {
                fillWidth: true
                text: qsTr("Close")
                inactiveColour: Colours.palette.m3surfaceContainerHighest
                inactiveOnColour: Colours.palette.m3onSurface
                onClicked: root.nState.closeSubPage()
            }
        }
    }
}