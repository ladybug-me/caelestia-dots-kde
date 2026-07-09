import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal

    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.lockStatus) ? GlobalConfig.bar.previewScales.lockStatus : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.lockStatus) ? GlobalConfig.bar.previewFontScales.lockStatus : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)

    implicitWidth: Math.max(300 * scaleOffset, _isSidebarOpen ? (Tokens.sizes.sidebar.width * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium * scaleOffset

    StyledText {
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: qsTr("Keyboard Locks")
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

            StyledText {
                text: qsTr("Capslock: %1").arg(Hypr.capsLock ? "Enabled" : "Disabled")
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }

            StyledText {
                text: qsTr("Numlock: %1").arg(Hypr.numLock ? "Enabled" : "Disabled")
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }
        }
    }
}
