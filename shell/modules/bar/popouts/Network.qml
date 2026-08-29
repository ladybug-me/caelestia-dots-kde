pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    property string connectingToSsid: ""
    property string view: "wireless" // "wireless" or "ethernet"
    property var passwordNetwork: null
    property bool showPasswordDialog: false
    property bool _isSidebarOpen: false

    readonly property var activeDeviceDetails: root.view === "wireless" ? Nmcli.wirelessDeviceDetails : Nmcli.ethernetDeviceDetails
    readonly property var activeDetails: {
        const d = root.activeDeviceDetails;
        if (!d || typeof d !== "object" || Object.keys(d).length === 0)
            return { visible: false, rows: [] };

        const dnsList = Array.isArray(d.dns) ? d.dns : [];
        return {
            visible: true,
            rows: [
                { label: qsTr("IP address"), value: d.ipAddress ?? "" },
                { label: qsTr("Subnet mask"), value: d.subnet ?? "" },
                { label: qsTr("Gateway"), value: d.gateway ?? "" },
                { label: qsTr("DNS"), value: dnsList.join(", ") },
                { label: qsTr("MAC address"), value: d.macAddress ?? "" }
            ]
        };
    }

    // Injected by Content.qml's Popout.
    property real scaleOffset: 1.0
    property real fontScale: 1.0

    spacing: Tokens.spacing.medium * scaleOffset
    width: Math.max(300 * scaleOffset, _isSidebarOpen ? (Tokens.sizes.sidebar.width * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)

    StyledText {
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: qsTr("Network")
        font.weight: 500
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: cardLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

    // Wireless section
    StyledText {
        visible: root.view === "wireless"
        
        Layout.topMargin: visible ? Tokens.padding.medium * root.scaleOffset : 0
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("Wireless")
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    Toggle {
        visible: root.view === "wireless"
        
        label: qsTr("Enabled")
        checked: Nmcli.wifiEnabled
        toggle.onToggled: Nmcli.enableWifi(checked)
    }

    StyledText {
        visible: root.view === "wireless"
        
        Layout.topMargin: visible ? Tokens.spacing.small * root.scaleOffset : 0
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("%1 networks available").arg(Nmcli.networks.length) // qmllint disable missing-property
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
    }

    Repeater {
        visible: root.view === "wireless"
        model: ScriptModel {
            values: [...Nmcli.networks].sort((a, b) => {
                if (a.active !== b.active)
                    return b.active - a.active;
                return b.strength - a.strength;
            }).slice(0, 8)
        }

        ListRow {
            id: networkItem

            required property Nmcli.AccessPoint modelData
            readonly property bool isConnecting: root.connectingToSsid === modelData.ssid
            readonly property bool loading: networkItem.isConnecting

            rowScale: root.scaleOffset
            visible: root.view === "wireless"

            MaterialIcon {
                text: Icons.getNetworkIcon(networkItem.modelData.strength)
                color: networkItem.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            MaterialIcon {
                visible: networkItem.modelData.isSecure
                text: "lock"
                fontStyle.pointSize: Tokens.font.icon.small.pointSize * root.fontScale
            }

            StyledText {
                Layout.leftMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.rightMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.fillWidth: true
                text: networkItem.modelData.ssid
                elide: Text.ElideRight
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                color: networkItem.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
            }

            ConnectButton {
                iconScale: root.scaleOffset
                active: networkItem.modelData.active
                loading: networkItem.loading
                interactive: Nmcli.wifiEnabled

                onClicked: {
                    if (networkItem.modelData.active) {
                        Nmcli.disconnectFromNetwork();
                    } else {
                        root.connectingToSsid = networkItem.modelData.ssid;
                        NetworkConnection.handleConnect(networkItem.modelData, null, network => {
                            // Password is required - show password dialog
                            root.passwordNetwork = network;
                            root.showPasswordDialog = true;
                            root.popouts.currentName = "wirelesspassword";
                        });

                        // Clear connecting state if connection succeeds immediately (saved profile)
                        // This is handled by the onActiveChanged connection below
                    }
                }
            }
        }
    }

    StyledRect {
        visible: root.view === "wireless"
        
        Layout.topMargin: visible ? Tokens.spacing.small * root.scaleOffset : 0
        Layout.fillWidth: true
        implicitHeight: rescanBtn.implicitHeight + Tokens.padding.small * root.scaleOffset

        radius: Tokens.rounding.full * root.scaleOffset
        color: Colours.palette.m3primaryContainer

        StateLayer {
            color: Colours.palette.m3onPrimaryContainer
            disabled: Nmcli.scanning || !Nmcli.wifiEnabled
            onClicked: Nmcli.rescanWifi()
        }

        RowLayout {
            id: rescanBtn

            anchors.centerIn: parent
            spacing: Tokens.spacing.small * root.scaleOffset
            opacity: Nmcli.scanning ? 0 : 1

            MaterialIcon {
                id: scanIcon

                Layout.topMargin: Math.round(fontInfo.pointSize * 0.0575)
                animate: true
                text: "wifi_find"
                color: Colours.palette.m3onPrimaryContainer
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            StyledText {
                Layout.topMargin: -Math.round(scanIcon.fontInfo.pointSize * 0.0575)
                text: qsTr("Rescan networks")
                color: Colours.palette.m3onPrimaryContainer
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        CircularIndicator {
            anchors.centerIn: parent
            strokeWidth: Tokens.padding.extraSmall / 2 * root.scaleOffset
            bgColour: "transparent"
            implicitSize: parent.implicitHeight - Tokens.padding.large * root.scaleOffset
            running: Nmcli.scanning
        }
    }

    // VPN section
    StyledText {
        visible: root.view === "wireless"

        Layout.topMargin: visible ? Tokens.spacing.small * root.scaleOffset : 0
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("VPN")
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    StyledText {
        visible: root.view === "wireless"

        Layout.topMargin: visible ? Tokens.spacing.extraSmall * root.scaleOffset : 0
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("%1 profiles available").arg(Nmcli.vpnConnections.length)
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
    }

    Repeater {
        visible: root.view === "wireless"
        model: ScriptModel {
            values: [...Nmcli.vpnConnections].slice(0, 8)
        }

        ListRow {
            id: vpnItem

            required property var modelData
            readonly property bool loading: Nmcli.vpnPendingConnection === modelData.name

            rowScale: root.scaleOffset
            visible: root.view === "wireless"

            MaterialIcon {
                text: "vpn_key"
                color: vpnItem.modelData.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            StyledText {
                Layout.leftMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.rightMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.fillWidth: true
                text: vpnItem.modelData.name
                elide: Text.ElideRight
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                color: vpnItem.modelData.connected ? Colours.palette.m3primary : Colours.palette.m3onSurface
            }

            ConnectButton {
                iconScale: root.fontScale
                active: vpnItem.modelData.connected
                loading: vpnItem.loading

                onClicked: {
                    if (vpnItem.modelData.connected) {
                        Nmcli.disconnectVpn(vpnItem.modelData.name, () => {});
                    } else {
                        Nmcli.connectVpn(vpnItem.modelData.name, () => {});
                    }
                }
            }
        }
    }

    StyledText {
        visible: root.view === "wireless" && Nmcli.vpnConnections.length === 0

        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("No VPN profiles found")
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
    }

    // Ethernet section
    StyledText {
        visible: root.view === "ethernet"
        
        Layout.topMargin: visible ? Tokens.padding.medium * root.scaleOffset : 0
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("Ethernet")
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    StyledText {
        visible: root.view === "ethernet"
        
        Layout.topMargin: visible ? Tokens.spacing.small * root.scaleOffset : 0
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("%1 devices available").arg(Nmcli.ethernetDevices.length)
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
    }

    Repeater {
        visible: root.view === "ethernet"
        model: ScriptModel {
            values: [...Nmcli.ethernetDevices].sort((a, b) => {
                if (a.connected !== b.connected)
                    return b.connected - a.connected;
                return (a.interface || "").localeCompare(b.interface || "");
            }).slice(0, 8)
        }

        ListRow {
            id: ethernetItem

            required property var modelData
            readonly property bool loading: false

            rowScale: root.scaleOffset
            visible: root.view === "ethernet"

            MaterialIcon {
                text: "cable"
                color: ethernetItem.modelData.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            StyledText {
                Layout.leftMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.rightMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.fillWidth: true
                text: ethernetItem.modelData.interface || qsTr("Unknown")
                elide: Text.ElideRight
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                color: ethernetItem.modelData.connected ? Colours.palette.m3primary : Colours.palette.m3onSurface
            }

            ConnectButton {
                iconScale: root.fontScale
                active: ethernetItem.modelData.connected
                loading: ethernetItem.loading

                onClicked: {
                    if (ethernetItem.modelData.connected && ethernetItem.modelData.connection) {
                        Nmcli.disconnectEthernet(ethernetItem.modelData.connection, () => {});
                    } else {
                        Nmcli.connectEthernet(ethernetItem.modelData.connection || "", ethernetItem.modelData.interface || "", () => {});
                    }
                }
            }
        }
    }

    // Connection details (IP / subnet / gateway / DNS / MAC) for the active device
    StyledText {
        visible: root.activeDetails.visible
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: qsTr("Connection details")
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    Repeater {
        model: root.activeDetails.rows

        RowLayout {
            required property var modelData

            visible: modelData.value !== ""

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            StyledText {
                Layout.fillWidth: true
                text: modelData.label
                font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
            }

            StyledText {
                text: modelData.value
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
            }
        }
    }
        }
    }

    Connections {
        function onActiveChanged(): void {
            if (Nmcli.active && root.connectingToSsid === Nmcli.active.ssid) {
                root.connectingToSsid = "";
                // Close password dialog if we successfully connected
                if (root.showPasswordDialog && root.passwordNetwork && Nmcli.active.ssid === root.passwordNetwork.ssid) {
                    root.showPasswordDialog = false;
                    root.passwordNetwork = null;
                    if (root.popouts.currentName === "wirelesspassword") {
                        root.popouts.currentName = "network";
                    }
                }
            }
        }

        function onScanningChanged(): void {
            if (!Nmcli.scanning)
                scanIcon.rotation = 0;
        }

        target: Nmcli
    }

    Connections {
        function onCurrentNameChanged(): void {
            // Clear password network when leaving password dialog
            if (root.popouts.currentName !== "wirelesspassword" && root.showPasswordDialog) {
                root.showPasswordDialog = false;
                root.passwordNetwork = null;
            }
        }

        target: root.popouts
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        spacing: Tokens.spacing.medium * root.scaleOffset

        StyledText {
            Layout.fillWidth: true
            text: parent.label
            font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
        }

        StyledSwitch {
            id: toggle
        }
    }
}
