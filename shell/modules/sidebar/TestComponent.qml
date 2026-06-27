import QtQuick
import Quickshell

Item {
    Component {
        id: testComp
        FloatingWindow {
            id: win
            color: "red"
            implicitWidth: 100
            implicitHeight: 100
            title: "Test"
            MouseArea {
                anchors.fill: parent
                onClicked: console.log("CLICKED")
            }
        }
    }

    Component.onCompleted: {
        var w = testComp.createObject(null)
        w.visible = true
    }
}
