pragma ComponentBehavior: Bound

import QtQuick
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var panels
    property var animConfig

    property alias windowGrid: windowGrid

    WindowGrid {
        id: windowGrid
        anchors.fill: parent
        opacity: root.visibilities.overview ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.animConfig ? root.animConfig.gridDuration : 1500; easing.type: root.animConfig ? root.animConfig.easingType : Easing.OutCubic } }
    }
}
