pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property bool disabled: false
    property color rippleColor: config.inverseOnSurface
    property real radius: 8
    property real topRightradius: root.parentRadius
    property real topLeftradius: root.parentRadius
    property real bottomRightradius: root.parentRadius
    property real bottomLeftradius: root.parentRadius
    property real parentWidth
    property real parentHeight
    property real parentRadius

    signal clicked

    anchors.fill: parent
    layer.enabled: true

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.disabled
        cursorShape: Qt.PointingHandCursor
        onPressed: event => {
            ripple.x = event.x;
            ripple.y = event.y;
            const dist = (ox, oy) => {
                return ox * ox + oy * oy;
            };
            let r = Math.sqrt(Math.max(dist(event.x, event.y), dist(event.x, height - event.y), dist(width - event.x, event.y), dist(width - event.x, height - event.y)));
            ripple.width = 0;
            ripple.height = 0;
            ripple.opacity = 0.15;
            anim.to = r * 2;
            anim.restart();
        }
        onClicked: root.clicked()
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftradius
        topRightRadius: root.topRightradius
        bottomLeftRadius: root.bottomLeftradius
        bottomRightRadius: root.bottomRightradius
        color: mouse.pressed ? Qt.rgba(root.rippleColor.r, root.rippleColor.g, root.rippleColor.b, 0.2) : mouse.containsMouse ? Qt.rgba(root.rippleColor.r, root.rippleColor.g, root.rippleColor.b, 0.15) : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
    }

    Rectangle {
        id: ripple

        radius: width / 2
        color: Qt.lighter(root.rippleColor, 1.5)
        opacity: 0

        transform: Translate {
            x: -ripple.width / 2
            y: -ripple.height / 2
        }
    }

    NumberAnimation {
        id: anim

        target: ripple
        properties: "width,height"
        duration: 300
        easing.type: Easing.OutQuad
        onStopped: fade.start()
    }

    NumberAnimation {
        id: fade

        target: ripple
        property: "opacity"
        to: 0
        duration: 200
    }
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.parentWidth
            height: root.parentHeight
            topRightRadius: root.topRightradius
            topLeftRadius: root.topLeftradius
            bottomLeftRadius: root.bottomLeftradius
            bottomRightRadius: root.bottomRightradius
        }
    }
}
