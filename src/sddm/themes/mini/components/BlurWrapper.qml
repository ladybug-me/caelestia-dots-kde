pragma ComponentBehavior: Bound
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects

import "../singletons"

Item {
    id: blurCard

    property real targetWidth: 200
    property real targetHeight: 200
    property real startWidth: targetWidth / 10
    property real startHeight: targetHeight / 10
    property int animDuration: 600
    property real radius: 20
    property bool blurEnabled: true
    property real blurAmount: 0.6
    property url source: ""

    function startAnimation() {
        widthAnim.start();
        heightAnim.start();
    }

    Component.onCompleted: startAnimation()

    Rectangle {
        id: rootRect

        width: blurCard.startWidth
        height: blurCard.startHeight
        radius: blurCard.radius
        color: "transparent"
        anchors.centerIn: parent
        clip: true
        layer.enabled: true

        AnimatedImage {
            id: backgroundBlur

            anchors.centerIn: parent
            width: 1920
            height: 1080
            source: blurCard.source
            fillMode: Image.PreserveAspectCrop

            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: Theme.videoItem
                visible: Theme.videoActive
            }
        }

        MultiEffect {
            anchors.fill: backgroundBlur
            source: backgroundBlur
            blurEnabled: blurCard.blurEnabled
            blur: blurCard.blurAmount
            blurMax: 64
            autoPaddingEnabled: false
        }

        layer.effect: OpacityMask {

            maskSource: Rectangle {
                width: rootRect.width
                height: rootRect.height
                radius: rootRect.radius
            }
        }
    }

    PropertyAnimation {
        id: widthAnim

        target: rootRect
        property: "width"
        from: blurCard.startWidth
        to: blurCard.targetWidth
        duration: blurCard.animDuration
        easing.type: Easing.OutBack
    }

    PropertyAnimation {
        id: heightAnim

        target: rootRect
        property: "height"
        from: blurCard.startHeight
        to: blurCard.targetHeight
        duration: blurCard.animDuration
        easing.type: Easing.OutBack
    }
}
