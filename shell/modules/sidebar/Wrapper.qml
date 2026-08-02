pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    property var popouts
    property var utilities
    readonly property Props props: Props {}
    readonly property bool shouldBeActive: visibilities.sidebar && Config.sidebar.enabled && !visibilities.overview
    property bool aiBusy: false
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.leftMargin: Config.bar.position === "right" ? (-implicitWidth - 5) * offsetScale : 0
    anchors.rightMargin: Config.bar.position !== "right" ? (-implicitWidth - 5) * offsetScale : 0
    implicitWidth: Tokens.sizes.sidebar.width
    opacity: 1 - offsetScale

    Connections {
        function onAiBusyChanged(): void {
            root.aiBusy = content.item ? content.item.aiBusy : false;
        }

        target: content.item
        ignoreUnknownSignals: true
    }
    Behavior on offsetScale {
        Anim {}
    }
    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)
        anchors.bottomMargin: 0
        // Closing the sidebar used to destroy the assistant along with any request
        // it had in flight, losing the answer. Stay loaded until it has finished.
        // root.aiBusy is assigned rather than bound: reading content.item from this
        // binding would make the loader's own contents decide whether it loads.
        active: root.shouldBeActive || root.visible || root.aiBusy
        sourceComponent: Content {
            implicitWidth: Tokens.sizes.sidebar.width - content.anchors.leftMargin - content.anchors.margins
            props: root.props
            visibilities: root.visibilities
            popouts: root.popouts
            utilities: root.utilities
        }
    }
}
