pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property int currentIndex: 0
    required property var tabButtonList

    signal tabClicked(int index)

    function incrementCurrentIndex(): void {
        if (root.tabButtonList && root.tabButtonList.length > 0) {
            root.setCurrentIndex((root.currentIndex + 1) % root.tabButtonList.length);
        }
    }

    function decrementCurrentIndex(): void {
        if (root.tabButtonList && root.tabButtonList.length > 0) {
            root.setCurrentIndex((root.currentIndex - 1 + root.tabButtonList.length) % root.tabButtonList.length);
        }
    }

    function setCurrentIndex(index: int): void {
        if (root.currentIndex !== index) {
            root.currentIndex = index;
        }
        root.tabClicked(index);
    }

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    implicitWidth: contentItem.implicitWidth
    implicitHeight: 40

    Row {
        id: contentItem

        z: 1
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.tabButtonList

            delegate: Button {
                id: tabBtn

                required property int index

                readonly property var tabInfo: root.tabButtonList[tabBtn.index]
                property bool current: tabBtn.index === root.currentIndex

                implicitHeight: 36
                leftPadding: 16
                rightPadding: 16

                onClicked: {
                    root.setCurrentIndex(tabBtn.index);
                }

                background: Rectangle {
                    // Fade alpha to 0 instead of the literal "transparent" string,
                    // which would animate RGB through black.
                    color: tabBtn.current ? Colours.palette.m3secondaryContainer : Qt.alpha(Colours.palette.m3secondaryContainer, 0)
                    radius: height / 2

                    Behavior on color {
                        CAnim {}
                    }
                }

                contentItem: RowLayout {
                    spacing: 8

                    MaterialIcon {
                        text: tabBtn.tabInfo?.icon ?? ""
                        color: tabBtn.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: tabBtn.tabInfo?.name ?? ""
                        color: tabBtn.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
