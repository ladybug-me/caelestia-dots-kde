pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import org.kde.pipewire as Pipewire
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import ".."

Item {
    id: root

    required property var windowData
    required property real workspaceWidth
    required property real workspaceHeight

    readonly property string windowAddress: windowData.address

    readonly property var screen: QsWindow.window ? QsWindow.window.screen : null
    readonly property real sWidth: screen ? screen.width : 1920
    readonly property real sHeight: screen ? screen.height : 1080

    readonly property real scaleX: workspaceWidth / sWidth
    readonly property real scaleY: workspaceHeight / sHeight

    x: (windowData.x || 0) * scaleX
    y: (windowData.y || 0) * scaleY
    width: (windowData.width || 0) * scaleX
    height: (windowData.height || 0) * scaleY

    z: Drag.active ? 100 : 1

    Drag.active: dragArea.drag.active
    Drag.source: root
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    StyledRect {
        id: bg
        anchors.fill: parent
        color: Colours.tPalette.m3surface
        radius: Tokens.rounding.small
        
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        
        Loader {
            id: screencastLoader
            active: true
            sourceComponent: WindowScreencastRequest {
                uuid: root.windowData.address
            }
        }
        
        readonly property int serial: screencastLoader.item ? screencastLoader.item.objectSerial : 0
        
        Pipewire.PipeWireSourceItem {
            anchors.fill: parent
            anchors.margins: 1
            visible: bg.serial !== 0
            objectSerial: bg.serial
        }
        
        IconImage {
            anchors.centerIn: parent
            implicitSize: 32
            asynchronous: true
            visible: bg.serial === 0
            source: root.windowData.iconName ? Icons.getAppIcon(root.windowData.iconName, "image-missing") : (root.windowData.class ? Icons.getAppIcon(root.windowData.class, "image-missing") : "")
        }
        
        MouseArea {
            id: dragArea
            anchors.fill: parent
            drag.target: root
            cursorShape: Qt.OpenHandCursor
            
            onPressed: cursorShape = Qt.ClosedHandCursor
            onReleased: {
                cursorShape = Qt.OpenHandCursor
                if (drag.active) {
                    root.Drag.drop();
                }
            }
            onClicked: {
                if (typeof KWinActiveWindowBridge !== "undefined") {
                    KWinActiveWindowBridge.focusWindow(root.windowData.address);
                    const v = Visibilities.getForActive();
                    if (v) v.overview = false;
                }
            }
        }
    }
}
