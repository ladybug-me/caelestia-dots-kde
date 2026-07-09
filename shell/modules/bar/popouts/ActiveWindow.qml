import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    implicitWidth: child.implicitWidth
    implicitHeight: child.implicitHeight

    readonly property string gifPath: {
        const hr = new Date().getHours();
        if (hr >= 5 && hr < 12) return Qt.resolvedUrl("../../../assets/morning.gif");
        if (hr >= 12 && hr < 17) return Qt.resolvedUrl("../../../assets/afternoon.gif");
        if (hr >= 17 && hr < 20) return Qt.resolvedUrl("../../../assets/evening.gif");
        return Qt.resolvedUrl("../../../assets/night.gif");
    }
    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.activeWindow) ? GlobalConfig.bar.previewScales.activeWindow : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.activeWindow) ? GlobalConfig.bar.previewFontScales.activeWindow : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)
    readonly property int previewSize: Math.round(Tokens.sizes.bar.windowPreviewSize * scaleOffset)

    Column {
        id: child

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        ClippingWrapperRectangle {
            color: "transparent"
            radius: Tokens.rounding.medium
            implicitWidth: previewSize
            implicitHeight: previewSize

            AnimatedImage {
                id: preview
                
                cache: false
                source: root.gifPath
                fillMode: root.gifPath.includes("morning.gif") ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                
                width: previewSize
                height: previewSize
            }
        }
    }
}
