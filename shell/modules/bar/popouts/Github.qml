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

    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.github) ? GlobalConfig.bar.previewScales.github : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.github) ? GlobalConfig.bar.previewFontScales.github : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)

    width: 300 * scaleOffset
    spacing: Tokens.spacing.small * scaleOffset

    StyledText {
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: qsTr("GitHub")
        font.weight: 500
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Services.Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: cardLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small * root.scaleOffset

                MaterialIcon {
                    text: "person"
                    color: Services.Colours.palette.m3onSurfaceVariant
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.username.length > 0 ? `@${root.username}` : qsTr("Not authenticated")
                    color: Services.Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small * root.scaleOffset
                visible: root.lastError.length === 0

                MaterialIcon {
                    text: "history"
                    color: Services.Colours.palette.m3onSurfaceVariant
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Last 7 days")
                    color: Services.Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                }

                StyledText {
                    text: qsTr("%1 commits").arg(root.total)
                    font.weight: 600
                    color: Services.Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small * root.scaleOffset
                visible: root.lastError.length > 0

                MaterialIcon {
                    text: "error"
                    color: Services.Colours.palette.m3error
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.lastError
                    color: Services.Colours.palette.m3error
                    wrapMode: Text.Wrap
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                }
            }

        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Services.Colours.palette.m3primaryContainer
        inactiveOnColour: Services.Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small * root.scaleOffset
        text: qsTr("Open profile")
        icon: "open_in_new"

        onClicked: {
            root.popouts.hasCurrent = false;
            Qt.openUrlExternally("https://github.com/" + root.username);
        }
    }
}
