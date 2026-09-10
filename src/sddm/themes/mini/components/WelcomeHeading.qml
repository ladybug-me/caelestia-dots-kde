import "../singletons"
import Qt5Compat.GraphicalEffects
import QtQuick

Text {
    id: root

    property string userName: ""
    property bool isActive: true

    renderType: Text.NativeRendering
    anchors.centerIn: parent
    text: Theme.welcomeMessage.replace("$USER", userName).trim()
    visible: Theme.welcomeMessage !== ""
    font.family: Theme.fontFamily
    font.pixelSize: 90
    font.variableAxes: ({
            "wght": 600,
            "wdth": 90,
            "ROND": 25,
            "opsz": 90
        })
    color: Theme.mOnSurface
    opacity: isActive ? 1 : 0
    scale: isActive ? 1 : 0.8
    layer.enabled: true

    layer.effect: DropShadow {
        transparentBorder: true
        horizontalOffset: 0
        verticalOffset: 6
        radius: 24
        samples: 40
        color: Theme.withAlpha(Theme.mSurface, 0.65)
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDurationNormal
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animDurationNormal
            easing.type: Easing.OutCubic
        }
    }
}
