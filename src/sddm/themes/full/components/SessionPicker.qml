pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    property bool expanded: false
    property int count: sessionModel ? sessionModel.count : 0
    property var items: []
    property int selectedIndex: 0
    property string currentText
    Component.onCompleted: {
        root.currentText = sessionArray.sessions[root.selectedIndex].name;
        const arr = [];
        for (let i = 0; i < sessionArray.sessions.length; i++) {
            arr.push(sessionArray.sessions[i].name);
        }
        root.items = arr;
    }
    onSelectedIndexChanged: {
        root.currentText = sessionArray.sessions[root.selectedIndex].name;
    }

    width: labelRect.width + expandBtn.width
    height: 40
    opacity: root.count > 0 ? 1 : 0
    enabled: root.count > 0

    Instantiator {
        id: sessionArray
        model: sessionModel
        property var sessions: []

        delegate: Item {
            required property int index
            required property var model

            Component.onCompleted: {
                sessionArray.sessions.push({
                    index: index,
                    name: model.name
                });
            }
        }
    }

    Rectangle {
        id: labelRect

        radius: height / 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        topLeftRadius: height / 2
        bottomLeftRadius: height / 2
        topRightRadius: 5
        bottomRightRadius: 5
        color: config.subComponents

        width: 210

        Row {
            id: labelRow

            anchors.verticalCenter: labelRect.verticalCenter
            anchors.left: labelRect.left
            anchors.leftMargin: 15
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "Material Symbols Rounded"
                font.pointSize: 16
                text: "widgets"
                color: config.primary
            }

            Text {
                id: labelText

                anchors.verticalCenter: parent.verticalCenter
                text: root.currentText
                color: config.text
                font.pixelSize: 14
                font.family: "Rubik"
                elide: Text.ElideRight
            }
        }

        LayerState {
            anchors.fill: parent
            parentWidth: labelRect.width
            parentHeight: labelRect.height
            parentRadius: labelRect.radius
            disabled: true
            topRightradius: labelRect.topRightRadius
            bottomRightradius: labelRect.bottomRightRadius
        }
    }

    Rectangle {
        id: expandBtn

        property real rad: root.expanded ? height / 2 : 5

        radius: height / 2
        anchors.left: labelRect.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        topLeftRadius: rad
        bottomLeftRadius: rad
        color: config.primary

        width: height

        Behavior on topLeftRadius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on bottomLeftRadius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutCubic
            }
        }

        Text {
            id: expandIcon

            anchors.centerIn: expandBtn
            anchors.horizontalCenterOffset: root.expanded ? 0 : -2
            font.family: "Material Symbols Rounded"
            font.pointSize: 18
            text: "expand_more"
            color: config.onPrimary
            rotation: root.expanded ? 180 : 0

            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.InOutCubic
                }
            }

            Behavior on rotation {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.InOutCubic
                }
            }
        }

        LayerState {
            anchors.fill: parent
            parentWidth: expandBtn.width
            parentHeight: expandBtn.height
            parentRadius: expandBtn.radius
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        id: menuRect

        visible: root.expanded
        color: config.subComponents
        radius: 8
        border.color: config.outline
        border.width: 1

        anchors.top: labelRect.bottom
        anchors.topMargin: 4
        anchors.left: labelRect.left
        anchors.leftMargin: -10
        width: 260
        height: Math.min(200, root.count * 36)

        clip: true

        opacity: root.expanded ? 1 : 0
        transform: Translate {
            y: root.expanded ? 0 : -10
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutCubic
            }
        }

        ListView {
            id: sessionList

            anchors.fill: parent
            anchors.margins: 4
            model: root.items
            currentIndex: root.selectedIndex
            clip: true
            boundsBehavior: ListView.StopAtBounds
            contentHeight: root.count * 32
            implicitHeight: contentHeight

            delegate: Rectangle {
                id: delegateItem

                required property int index

                width: parent.width
                height: 32
                radius: 4
                color: index === ListView.view.currentIndex ? config.primary : "transparent"
                opacity: index === ListView.view.currentIndex ? 0.2 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedIndex = delegateItem.index;
                        root.currentText = root.items[delegateItem.index];
                        root.expanded = false;
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.items[delegateItem.index]
                    color: config.text
                    font.pixelSize: 13
                    font.family: "Rubik"
                    elide: Text.ElideRight
                    leftPadding: 4
                    rightPadding: 4
                }
            }
        }
    }

    MouseArea {
        id: dismissArea

        anchors.fill: root
        z: -1
        enabled: root.expanded
        onClicked: root.expanded = false
    }
}
