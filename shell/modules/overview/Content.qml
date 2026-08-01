pragma ComponentBehavior: Bound

import QtQuick
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var panels

    WindowGrid {
        anchors.fill: parent
        opacity: root.visibilities.overview ? 1 : 0
        Behavior on opacity { Anim { type: Anim.DefaultEffects } }
    }
}
