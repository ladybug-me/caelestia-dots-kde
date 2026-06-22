import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import "../../../components"

Item {
    id: root
    property alias currentIndex: tabBar.currentIndex
    required property var tabButtonList

    function incrementCurrentIndex() {
        tabBar.incrementCurrentIndex();
    }
    function decrementCurrentIndex() {
        tabBar.decrementCurrentIndex();
    }
    function setCurrentIndex(index) {
        tabBar.setCurrentIndex(index);
    }

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    implicitWidth: contentItem.implicitWidth
    implicitHeight: 40

    TabBar {
        id: tabBar
        visible: false
        Repeater {
            model: root.tabButtonList.length
            delegate: TabButton {
                background: null
            }
        }
    }

    Row {
        id: contentItem
        z: 1
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.tabButtonList
            delegate: Button {
                id: tabBtn
                property bool current: index === tabBar.currentIndex
                implicitHeight: 36
                implicitWidth: contentLayout.implicitWidth + 24
                
                background: Rectangle {
                    color: tabBtn.current ? Colours.palette.m3secondaryContainer : "transparent"
                    radius: height / 2
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                contentItem: Row {
                    id: contentLayout
                    spacing: 8
                    anchors.centerIn: parent
                    
                    MaterialIcon {
                        text: modelData.icon
                        color: tabBtn.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: modelData.name
                        color: tabBtn.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                onClicked: {
                    root.setCurrentIndex(index);
                }
            }
        }
    }
}
