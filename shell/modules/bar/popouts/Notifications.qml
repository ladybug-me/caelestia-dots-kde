pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal

    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.notifications) ? GlobalConfig.bar.previewScales.notifications : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.notifications) ? GlobalConfig.bar.previewFontScales.notifications : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)

    width: Math.max(300 * scaleOffset, _isSidebarOpen ? (Tokens.sizes.sidebar.width * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    implicitWidth: Math.max(300 * scaleOffset, _isSidebarOpen ? (Tokens.sizes.sidebar.width * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium * scaleOffset

    StyledText {
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: qsTr("Notifications")
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
            spacing: Tokens.spacing.medium * root.scaleOffset

            Toggle {
                label: qsTr("Do not disturb")
                checked: Notifs.dnd
                toggle.onToggled: Notifs.dnd = checked
            }

            StyledText {
                text: Notifs.dnd ? qsTr("Notifications off") : qsTr("%1 unread").arg(Notifs.notClosed.length)
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small * root.scaleOffset
        text: qsTr("Clear all")
        icon: "clear_all"

        onClicked: Notifs.clear()
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.small * root.scaleOffset
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
