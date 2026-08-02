pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.modules.windowinfo as WInfo

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var panels
    property var animConfig
    property alias windowGrid: windowGrid

    Connections {
        function onOverviewChanged() {
            if (root.visibilities.overview) {
                windowGrid.forceActiveFocus()
            }
        }

        target: root.visibilities
    }
    WindowGrid {
        id: windowGrid

        panels: root.panels
        anchors.fill: parent
        opacity: root.visibilities.overview ? 1 : 0
        // activeInfoClient is managed manually to ensure synchronous release before WindowInfo requests it
        onRequestWindowInfo: client => {
            windowGrid.activeInfoClient = client
            windowInfoOverlay.clientAddress = client.address
        }
        onRequestClose: {
            root.visibilities.overview = false
        }

        Behavior on opacity { NumberAnimation { duration: root.animConfig ? root.animConfig.gridDuration : 1500; easing.type: root.animConfig ? root.animConfig.easingType : Easing.OutCubic } }
    }
    Shortcut {
        sequence: "Escape"
        onActivated: root.visibilities.overview = false
        enabled: root.visibilities.overview
    }
    Item {
        id: windowInfoOverlay

        property string clientAddress: ""

        z: 100
        anchors.fill: parent
        visible: opacity > 0
        opacity: clientAddress ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        Rectangle {
            x: -root.panels.leftMargin
            y: -root.panels.topMargin
            width: root.panels.screen.width
            height: root.panels.screen.height
            color: Qt.rgba(0, 0, 0, 0.5)

            HoverHandler { } // block hover
            WheelHandler { } // block scroll
            TapHandler {
                onTapped: {
                    windowInfoOverlay.clientAddress = ""
                    windowGrid.activeInfoClient = null
                }
            }
        }
        Item {
            anchors.centerIn: parent
            width: Math.min(parent.width * 0.8, 900)
            height: Math.min(parent.height * 0.8, 600)

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            TapHandler { }
            WInfo.WindowInfo {
                id: winInfoItem

                anchors.fill: parent
                clientAddress: windowInfoOverlay.clientAddress
                onCloseRequested: {
                    windowInfoOverlay.clientAddress = ""
                    windowGrid.activeInfoClient = null
                }
            }
        }
    }
}
