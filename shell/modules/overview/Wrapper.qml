pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels
    property var animConfig
    readonly property bool shouldBeActive: visibilities.overview
    property var windowGrid: content.item ? content.item.windowGrid : null

    width: (shouldBeActive || opacity > 0) ? (root.panels ? root.panels.parent.width : parent.width) : 0
    height: (shouldBeActive || opacity > 0) ? (root.panels ? root.panels.parent.height : parent.height) : 0
    x: root.panels ? -root.panels.leftMargin : 0
    y: root.panels ? -root.panels.topMargin : 0
    visible: shouldBeActive || opacity > 0
    opacity: shouldBeActive ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: root.animConfig ? root.animConfig.gridDuration : 1500; easing.type: root.animConfig ? root.animConfig.easingType : Easing.OutCubic }
    }
    Loader {
        id: content

        anchors.fill: parent
        active: root.shouldBeActive || root.visible
        sourceComponent: Component {
            Content {
                screen: root.screen
                visibilities: root.visibilities
                panels: root.panels
                animConfig: root.animConfig
            }
        }
    }
}
