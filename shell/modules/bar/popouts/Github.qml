pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.bar.components as BarComponents
import qs.services as Services
import M3Shapes

ColumnLayout {
    id: root

    required property var popouts
    property var days: BarComponents.GithubStore.days || []
    property int total: BarComponents.GithubStore.total || 0
    property string username: BarComponents.GithubStore.username || ""
    property string lastError: BarComponents.GithubStore.lastError || ""

    width: 300
    spacing: Tokens.spacing.small

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.leftMargin: Tokens.padding.small
        text: qsTr("GitHub")
        font.weight: 500
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Services.Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: cardLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "person"
                    color: Services.Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.username.length > 0 ? `@${root.username}` : qsTr("Not authenticated")
                    color: Services.Colours.palette.m3onSurface
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                visible: root.lastError.length === 0

                MaterialIcon {
                    text: "history"
                    color: Services.Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Last 7 days")
                    color: Services.Colours.palette.m3onSurfaceVariant
                }

                StyledText {
                    text: qsTr("%1 commits").arg(root.total)
                    font.weight: 600
                    color: Services.Colours.palette.m3onSurface
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                visible: root.lastError.length > 0

                MaterialIcon {
                    text: "error"
                    color: Services.Colours.palette.m3error
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.lastError
                    color: Services.Colours.palette.m3error
                    wrapMode: Text.Wrap
                }
            }

        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Services.Colours.palette.m3primaryContainer
        inactiveOnColour: Services.Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small
        text: qsTr("Open profile")
        icon: "open_in_new"

        onClicked: {
            root.popouts.hasCurrent = false;
            Qt.openUrlExternally("https://github.com/" + root.username);
        }
    }
}
