pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

Column {
    id: root

    readonly property var excluded: Config.bar.status.peripheralBatteryExcluded

    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.peripheralBattery) ? GlobalConfig.bar.previewScales.peripheralBattery : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.peripheralBattery) ? GlobalConfig.bar.previewFontScales.peripheralBattery : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)

    spacing: Tokens.spacing.small * scaleOffset

    Repeater {
        model: ScriptModel {
            values: UPower.devices.values.filter(d => !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.isPresent && !root.excluded.some(e => e === d.model || e === d.nativePath))
        }

        Row {
            id: peripheralRow

            required property UPowerDevice modelData

            spacing: Tokens.spacing.small * root.scaleOffset

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    const t = peripheralRow.modelData.type;
                    if (t === UPowerDeviceType.Mouse || t === UPowerDeviceType.Touchpad)
                        return "mouse";
                    if (t === UPowerDeviceType.Keyboard)
                        return "keyboard";
                    if (t === UPowerDeviceType.Headset || t === UPowerDeviceType.Headphones)
                        return "headphones";
                    if (t === UPowerDeviceType.GamingInput)
                        return "sports_esports";
                    if (t === UPowerDeviceType.Pen)
                        return "stylus";
                    if (t === UPowerDeviceType.Speakers || t === UPowerDeviceType.OtherAudio)
                        return "speaker";
                    if (t === UPowerDeviceType.Phone)
                        return "smartphone";
                    return "battery_full";
                }
                color: Colours.palette.m3onSurface
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: (peripheralRow.modelData.model || "Device") + ": " + Math.round(peripheralRow.modelData.percentage * 100) + "%"
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }
        }
    }
}
