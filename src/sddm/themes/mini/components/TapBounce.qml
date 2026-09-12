import QtQuick

Item {
    id: control

    property real peak: 0.05
    property int upDuration: 90
    property int downDuration: 220
    property real bounce: 0

    function trigger() {
        bounceAnim.restart();
    }

    SequentialAnimation {
        id: bounceAnim

        NumberAnimation {
            target: control
            property: "bounce"
            to: control.peak
            duration: control.upDuration
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: control
            property: "bounce"
            to: 0
            duration: control.downDuration
            easing.type: Easing.OutBack
        }
    }
}
