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
    readonly property real elementOffset: 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)

    implicitWidth: Math.max(300 * scaleOffset, _isSidebarOpen ? (Tokens.sizes.sidebar.width * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium * scaleOffset

    StyledText {
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: I18n.tr("Night Light")
        font.weight: 500
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.small * root.scaleOffset
        inactiveColour: HyprSunset.autoMode ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceVariant
        inactiveOnColour: HyprSunset.autoMode ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        verticalPadding: Tokens.padding.small * root.scaleOffset
        text: HyprSunset.autoMode ? I18n.tr("Auto") : I18n.tr("Manual")
        icon: "routine"
        
        onClicked: {
            HyprSunset.toggleAutoMode();
        }
    }

    // Daylight Temperature Slider (only visible in Auto mode)
    StyledText {
        visible: HyprSunset.autoMode
        Layout.topMargin: Tokens.spacing.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: I18n.tr("Daylight Temperature (%1K)").arg(Math.round(2000 + daySlider.pos * 4500))
        font.weight: Font.Medium
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
        font.features: { "tnum": 1 }
    }

    CustomMouseArea {
        visible: HyprSunset.autoMode
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3 * root.scaleOffset

        onWheel: event => {
            if (event.angleDelta.y > 0)
                HyprSunset.setDayTemperature(Math.min(6500, HyprSunset.dayTemperature + 100));
            else if (event.angleDelta.y < 0)
                HyprSunset.setDayTemperature(Math.max(2000, HyprSunset.dayTemperature - 100));
        }

        StyledSlider {
            id: daySlider

            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight

            value: Math.max(0, Math.min(1, (HyprSunset.dayTemperature - 2000) / 4500))
            onInteraction: v => HyprSunset.previewTemperature(Math.round(2000 + v * 4500))
            onReleased: v => {
                HyprSunset.stopPreview();
                HyprSunset.setDayTemperature(Math.round(2000 + v * 4500));
            }
        }
    }

    // Nightlight Temperature Slider
    StyledText {
        Layout.topMargin: Tokens.spacing.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: HyprSunset.autoMode ? I18n.tr("Nightlight Temperature (%1K)").arg(Math.round(2000 + nightSlider.pos * 4500)) : I18n.tr("Temperature (%1K)").arg(Math.round(2000 + nightSlider.pos * 4500))
        font.weight: Font.Medium
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
        font.features: { "tnum": 1 }
    }

    CustomMouseArea {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3 * root.scaleOffset

        onWheel: event => {
            if (event.angleDelta.y > 0)
                HyprSunset.setNightTemperature(Math.min(6500, HyprSunset.nightTemperature + 100));
            else if (event.angleDelta.y < 0)
                HyprSunset.setNightTemperature(Math.max(2000, HyprSunset.nightTemperature - 100));
        }

        StyledSlider {
            id: nightSlider

            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight

            value: Math.max(0, Math.min(1, (HyprSunset.nightTemperature - 2000) / 4500))
            onInteraction: v => HyprSunset.previewTemperature(Math.round(2000 + v * 4500))
            onReleased: v => {
                HyprSunset.stopPreview();
                HyprSunset.setNightTemperature(Math.round(2000 + v * 4500));
            }
        }
    }
}
