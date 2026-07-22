pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property string ssid: nState.selectedNetworkSsid
    readonly property var ap: Nmcli.findNetwork(root.ssid)
    readonly property var details: Nmcli.wirelessDeviceDetails
    readonly property bool isActive: !!Nmcli.active && Nmcli.active.ssid === root.ssid

    title: root.ssid || qsTr("Network details")
    isSubPage: true

    Component.onCompleted: {
        Nmcli.getWirelessDeviceDetails("", () => {});
    }

    Connections {
        function onActiveChanged(): void {
            if (root.isActive)
                Nmcli.getWirelessDeviceDetails("", () => {});
        }

        target: Nmcli
    }

    onApChanged: {
        if (!nState.networkDetailsFromSaved && !root.ap)
            nState.closeSubPage();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ButtonRow {
            Layout.bottomMargin: Tokens.spacing.large - parent.spacing
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumWidth: Math.round(root.cappedWidth * (root.isActive ? 0.7 : 0.5))
            spacing: Tokens.spacing.small

            ButtonBase {
                fillWidth: true
                shapeMorph: root.isActive
                isRound: true
                inactiveColour: Colours.palette.m3errorContainer
                inactiveOnColour: Colours.palette.m3onErrorContainer
                text: qsTr("Forget")
                onClicked: Nmcli.forgetNetwork(root.ssid, () => root.nState.closeSubPage())
            }

            ButtonBase {
                visible: root.isActive
                fillWidth: true
                shapeMorph: true
                isRound: true
                inactiveColour: Colours.palette.m3primaryContainer
                inactiveOnColour: Colours.palette.m3onPrimaryContainer
                text: qsTr("Disconnect")
                onClicked: {
                    Nmcli.disconnectFromNetwork();
                    root.nState.closeSubPage();
                }
            }

            ButtonBase {
                visible: !root.isActive
                fillWidth: true
                shapeMorph: true
                isRound: true
                inactiveColour: Colours.palette.m3primaryContainer
                inactiveOnColour: Colours.palette.m3onPrimaryContainer
                text: qsTr("Connect")
                onClicked: {
                    if (root.ap)
                        NetworkConnection.handleConnect(root.ap);
                }
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Connection")
            visible: root.isActive
        }

        InfoRow {
            icon: "signal_wifi_4_bar"
            label: qsTr("Signal")
            value: root.ap ? qsTr("%1%").arg(root.ap.strength) : qsTr("—")
            visible: root.isActive
        }

        InfoRow {
            icon: "lock"
            label: qsTr("Security")
            value: root.ap?.security || qsTr("Open")
            visible: root.isActive
        }

        InfoRow {
            icon: "graphic_eq"
            label: qsTr("Frequency")
            value: root.ap && root.ap.frequency > 0 ? qsTr("%1 MHz").arg(root.ap.frequency) : qsTr("—")
            visible: root.isActive
        }

        InfoRow {
            icon: "lan"
            label: qsTr("IP address")
            value: root.details?.ipAddress || qsTr("—")
            visible: root.isActive
        }

        InfoRow {
            icon: "router"
            label: qsTr("Gateway")
            value: root.details?.gateway || qsTr("—")
            visible: root.isActive
        }

        InfoRow {
            icon: "memory"
            label: qsTr("MAC address")
            value: root.details?.macAddress || qsTr("—")
            visible: root.isActive
        }

        SectionHeader {
            first: !root.isActive
            text: qsTr("Behaviour")
        }

        InfoRow {
            icon: "autorenew"
            label: qsTr("Auto connect")
            value: Nmcli.hasSavedProfile(root.ssid) ? qsTr("Saved") : qsTr("Not saved")
        }
    }
}