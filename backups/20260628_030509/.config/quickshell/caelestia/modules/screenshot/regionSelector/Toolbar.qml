import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services

Item {
    id: root

    property bool enableShadow: true
    property real padding: 8
    property color colBackground: Colours.palette.m3surfaceContainer
    property alias spacing: toolbarLayout.spacing
    default property alias toolbarData: toolbarLayout.data
    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight
    property alias radius: background.radius

    Rectangle {
        id: background
        anchors.fill: parent
        color: root.colBackground
        implicitHeight: 56
        implicitWidth: toolbarLayout.implicitWidth + root.padding * 2
        radius: height / 2

        RowLayout {
            id: toolbarLayout
            spacing: 4
            anchors {
                fill: parent
                margins: root.padding
            }
        }
    }
}
