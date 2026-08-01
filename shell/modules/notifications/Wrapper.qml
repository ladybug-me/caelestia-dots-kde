import QtQuick
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel

    visible: height > 0 && !visibilities.overview
    readonly property real baseTopMargin: -5
    anchors.topMargin: baseTopMargin
    implicitWidth: Math.max(sidebarPanel.width, content.implicitWidth)
    implicitHeight: content.implicitHeight

    Content {
        id: content

        anchors.topMargin: -root.baseTopMargin
        visibilities: root.visibilities
    }
}
