pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    signal networkSelected(ap: Nmcli.AccessPoint)

    title: qsTr("Network")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            interval: GlobalConfig.nexus.networkRescanInterval
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        ToggleRow {
            first: true
            text: qsTr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        NetworkList {
            Layout.bottomMargin: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? 0 : -parent.spacing
            nState: root.nState
            limit: GlobalConfig.nexus.maxNetworksShown

            onNetworkSelected: root.networkSelected(ap)

            Behavior on Layout.bottomMargin {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            Layout.preferredHeight: Nmcli.wifiEnabled && Nmcli.networks.length > GlobalConfig.nexus.maxNetworksShown ? showAllLayout.implicitHeight + Tokens.padding.medium * 2 : 0
            clip: true

            Behavior on Layout.preferredHeight {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            StateLayer {
                onClicked: root.nState.openSubPage(5)
            }

            RowLayout {
                id: showAllLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "expand_content"
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Show all networks (%1)").arg(Nmcli.networks.length)
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    text: "chevron_right"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: savedNetworksLayout.implicitHeight + savedNetworksLayout.anchors.margins * 2

            StateLayer {
                onClicked: root.nState.openSubPage(6)
            }

            RowLayout {
                id: savedNetworksLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "bookmark"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                    fill: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Saved networks")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    text: "chevron_right"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        ItemList {
            id: vpnList

            showList: true
            placeholderIcon: "vpn_key_off"
            placeholderText: qsTr("No VPN profiles found")

            model: ScriptModel {
                values: [...Nmcli.vpnConnections]
            }

            delegate: StyledRect {
                id: vpn

                required property var modelData
                readonly property bool loading: Nmcli.vpnPendingConnection === modelData.name
                readonly property bool connected: modelData.connected === true
                property real textOpacity: loading ? 0.5 : 1

                anchors.left: vpnList.list.contentItem.left
                anchors.right: vpnList.list.contentItem.right
                implicitHeight: vpnLayout.implicitHeight + vpnLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                color: "transparent"

                Behavior on textOpacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                StateLayer {
                    disabled: vpn.loading
                    onClicked: {
                        if (vpn.loading)
                            return;

                        if (vpn.connected) {
                            Nmcli.disconnectVpn(vpn.modelData.name, () => {});
                        } else {
                            Nmcli.connectVpn(vpn.modelData.name, () => {});
                        }
                    }
                }

                RowLayout {
                    id: vpnLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: vpnIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: vpn.connected ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            id: vpnIcon

                            anchors.centerIn: parent
                            text: "vpn_key"
                            color: vpn.connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                            fontStyle: Tokens.font.icon.medium
                            opacity: vpn.textOpacity
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: vpn.textOpacity

                        StyledText {
                            Layout.fillWidth: true
                            text: vpn.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: vpn.connected ? qsTr("Connected") : qsTr("Available")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            animate: true
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        implicitWidth: height

                        AnimLoader {
                            anchors.centerIn: parent
                            sourceComp: vpn.loading ? vpnLoadingComp : vpnActionComp

                            Component {
                                id: vpnActionComp

                                MaterialIcon {
                                    text: vpn.connected ? "link_off" : "link"
                                    color: vpn.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.medium
                                    opacity: vpn.textOpacity
                                }
                            }

                            Component {
                                id: vpnLoadingComp

                                LoadingIndicator {
                                    implicitSize: Math.round(Tokens.font.icon.medium.pointSize * 1.3)
                                }
                            }
                        }
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: vpnProviderLayout.implicitHeight + vpnProviderLayout.anchors.margins * 2

            StateLayer {
                onClicked: root.nState.openSubPage(4)
            }

            RowLayout {
                id: vpnProviderLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "vpn_key"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("VPN providers")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                MaterialIcon {
                    text: "chevron_right"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: addNetworkLayout.implicitHeight + addNetworkLayout.anchors.margins * 2
            last: true

            StateLayer {
                onClicked: root.nState.openSubPage(2)
            }

            RowLayout {
                id: addNetworkLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased

                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "add"
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Add network")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
