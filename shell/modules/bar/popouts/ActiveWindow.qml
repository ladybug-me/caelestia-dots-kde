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

    Column {
        id: child

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        ClippingWrapperRectangle {
            color: "transparent"
            radius: Tokens.rounding.medium

            AnimatedImage {
                id: preview
                
                cache: false
                source: root.gifPath
                fillMode: root.gifPath.includes("morning.gif") ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                
                width: Tokens.sizes.bar.windowPreviewSize
                height: Tokens.sizes.bar.windowPreviewSize
            }
        }
    }
}
