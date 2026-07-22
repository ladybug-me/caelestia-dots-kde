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

    title: qsTr("Saved networks")
    isSubPage: true

    Component.onCompleted: Nmcli.loadSavedConnections(() => {})

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ItemList {
            id: savedList

            showList: true
            first: true
            last: true
            placeholderIcon: "wifi_find"
            placeholderText: qsTr("No saved networks")

            model: ScriptModel {
                values: [...Nmcli.savedConnectionSsids].sort((a, b) => a.localeCompare(b))
            }

            delegate: StateLayer {
                id: saved

                required property int index
                required property var modelData
                readonly property var ap: Nmcli.findNetwork(modelData)
                readonly property bool isActive: !!Nmcli.active && Nmcli.active.ssid === modelData

                anchors.left: savedList.list.contentItem.left
                anchors.right: savedList.list.contentItem.right
                implicitHeight: savedLayout.implicitHeight + savedLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                bottomLeftRadius: root?.last && index === savedList.list.count - 1 ? Tokens.rounding.extraLarge : radius
                bottomRightRadius: root?.last && index === savedList.list.count - 1 ? Tokens.rounding.extraLarge : radius

                onClicked: {
                    root.nState.selectedNetworkSsid = modelData;
                    root.nState.networkDetailsFromSaved = true;
                    root.nState.openSubPage(3);
                }

                RowLayout {
                    id: savedLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: isActive ? "settings" : "bookmark"
                        color: isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: isActive ? qsTr("Connected") : ap ? qsTr("Available") : qsTr("Saved")
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
    }
}