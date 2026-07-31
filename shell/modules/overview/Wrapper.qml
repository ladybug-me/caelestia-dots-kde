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

    readonly property bool shouldBeActive: visibilities.overview

    property real offsetScale: shouldBeActive ? 0 : 1

    anchors.left: (Config.bar.position === "right") ? undefined : parent.left
    anchors.right: (Config.bar.position === "left") ? undefined : parent.right
    anchors.top: (Config.bar.position === "bottom") ? undefined : parent.top
    anchors.bottom: (Config.bar.position === "top") ? undefined : parent.bottom

    width: (Config.bar.position === "left" || Config.bar.position === "right") ? parent.width * (1 - offsetScale) : parent.width
    height: (Config.bar.position === "top" || Config.bar.position === "bottom") ? parent.height * (1 - offsetScale) : parent.height

    clip: false
    visible: offsetScale < 1
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        width: panels.width
        height: panels.height
        
        // Keep content visually static on screen during scale down
        anchors.left: (Config.bar.position === "right") ? undefined : parent.left
        anchors.right: (Config.bar.position === "left") ? undefined : parent.right
        anchors.top: (Config.bar.position === "bottom") ? undefined : parent.top
        anchors.bottom: (Config.bar.position === "top") ? undefined : parent.bottom

        active: root.shouldBeActive || root.visible

        sourceComponent: Component {
            Content {
                visibilities: root.visibilities
                panels: root.panels
            }
        }
    }
}
