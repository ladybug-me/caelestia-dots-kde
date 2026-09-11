pragma ComponentBehavior: Bound
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects

Item {
    id: blurCard

    property real targetWidth: 200
    property real targetHeight: 200
    property real startWidth: targetWidth / 10
    property real startHeight: targetHeight / 10
    property int animDuration: 600
    property int animDurationOpacity: 0
    property real radius: 20
    property bool blurEnabled: true
    property real blurAmount: 1
    property real bgOpacity: 0.3
    property string bgColor: "#000000"
    property real colorOpacity: 1
    property bool visibleState: true
    property url source: Qt.resolvedUrl("../assets/background")
    property var videoSourceItem: null

    function startAnimation() {
        widthAnim.start();
        heightAnim.start();
    }

    onVisibleStateChanged: {
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
        opacity: blurCard.visibleState ? 1 : 0
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
            opacity: blurCard.visibleState ? 1 : 0
            onStatusChanged: {
                if (status === Image.Error)
                    console.log("Background missing, using fallback color");
            }

            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: blurCard.videoSourceItem
                visible: blurCard.videoSourceItem !== null
            }
        }

        MultiEffect {
            anchors.fill: backgroundBlur
            source: backgroundBlur
            blurEnabled: blurCard.blurEnabled
            blur: blurCard.blurAmount
            blurMax: 64
            blurMultiplier: 1
            autoPaddingEnabled: false
            opacity: blurCard.visibleState ? 1 : 0

            Behavior on blur {
                NumberAnimation {
                    duration: blurCard.animDuration
                    easing.type: Easing.InOutCubic
                }
            }
        }

        Rectangle {
            anchors.fill: backgroundBlur
            color: Qt.rgba(parseInt(config.background.substring(1, 3), 16) / 255, parseInt(config.background.substring(3, 5), 16) / 255, parseInt(config.background.substring(5, 7), 16) / 255, 1)
            opacity: blurCard.visibleState ? parseFloat(config.mainCardColorOpacity) : 0
        }

        layer.effect: OpacityMask {

            maskSource: Rectangle {
                width: rootRect.width
                height: rootRect.height
                radius: rootRect.radius
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: blurCard.animDurationOpacity
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
