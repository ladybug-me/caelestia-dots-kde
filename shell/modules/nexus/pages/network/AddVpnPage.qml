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

    title: qsTr("VPN providers")
    isSubPage: true

    function setProvider(name: string): void {
        GlobalConfig.utilities.vpn.provider = [{ enabled: true, name: name }];
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Built-in providers")
        }

        ProviderRow {
            providerName: "wireguard"
            displayName: qsTr("WireGuard")
            description: qsTr("Use a local WireGuard tunnel")
        }

        ProviderRow {
            providerName: "warp"
            displayName: qsTr("Cloudflare WARP")
            description: qsTr("Cloudflare's privacy VPN")
        }

        ProviderRow {
            providerName: "netbird"
            displayName: qsTr("NetBird")
            description: qsTr("Self-managed mesh VPN")
        }

        ProviderRow {
            providerName: "tailscale"
            displayName: qsTr("Tailscale")
            description: qsTr("WireGuard-based mesh VPN")
        }

        ButtonRow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            ButtonBase {
                fillWidth: true
                text: qsTr("Close")
                inactiveColour: Colours.palette.m3surfaceContainerHighest
                inactiveOnColour: Colours.palette.m3onSurface
                onClicked: root.nState.closeSubPage()
            }
        }
    }

    component ProviderRow: ConnectedRect {
        id: row

        required property string providerName
        required property string displayName
        required property string description

        readonly property bool selected: VPN.providerName === providerName

        Layout.fillWidth: true
        implicitHeight: providerLayout.implicitHeight + providerLayout.anchors.margins * 2

        StateLayer {
            onClicked: root.setProvider(row.providerName)
        }

        RowLayout {
            id: providerLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.largeIncreased
            anchors.rightMargin: Tokens.padding.largeIncreased
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: selected ? "radio_button_checked" : "radio_button_unchecked"
                color: selected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: displayName
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: description
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            MaterialIcon {
                text: "chevron_right"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
            }
        }
    }
}