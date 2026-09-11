import "../components"
import QtQuick

Item {
    id: root

    property real rectHeight
    property real rectWidth
    property real rectRadius
    property real rectBigRadius

    anchors.fill: parent

    Rectangle {
        id: powerBtn

        anchors.left: parent.left
        anchors.top: parent.top
        height: parent.rectHeight
        width: parent.rectWidth
        radius: parent.rectRadius
        color: config.subComponents
        clip: true

        MaterialIcon {
            id: powerIcon

            property bool hovered: false

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 50
            anchors.topMargin: 35
            text: "\ue8ac"
            color: config.secondary
            pointSize: 70
        }

        LayerState {
            anchors.fill: parent
            parentWidth: powerBtn.width
            parentHeight: powerBtn.height
            parentRadius: powerBtn.radius
            onClicked: {
                sddm.powerOff();
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    Rectangle {
        id: rebootBtn

        anchors.right: parent.right
        anchors.top: parent.top
        height: root.rectHeight
        width: root.rectWidth
        radius: root.rectRadius
        color: config.subComponents
        clip: true

        MaterialIcon {
            id: restartIcon

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 47
            anchors.topMargin: 35
            text: "\ue863"
            color: config.secondary
            pointSize: 70
        }

        LayerState {
            anchors.fill: parent
            parentWidth: rebootBtn.width
            parentHeight: rebootBtn.height
            parentRadius: rebootBtn.radius
            onClicked: {
                sddm.reboot();
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }
}
