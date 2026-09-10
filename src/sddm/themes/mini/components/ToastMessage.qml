import "../singletons"
import QtQuick
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property string message: ""
    property bool isOpen: false
    property color backgroundColor: Theme.withAlpha(Theme.mError, 0.95)
    property color textColor: Theme.mOnError
    property string iconText: "error"

    signal dismissed

    function show(msg, type) {
        if (type === "warning" || type === "info") {
            root.backgroundColor = Theme.withAlpha(Theme.mPrimary, 0.95);
            root.textColor = Theme.mOnPrimary;
            root.iconText = "info";
        } else {
            root.backgroundColor = Theme.withAlpha(Theme.mError, 0.95);
            root.textColor = Theme.mOnError;
            root.iconText = "error";
        }
        root.message = msg;
        root.isOpen = true;
        dismissTimer.restart();
    }

    function dismiss() {
        root.isOpen = false;
    }

    implicitWidth: toastContent.implicitWidth + 48
    implicitHeight: toastContent.implicitHeight + 24
    color: backgroundColor
    radius: Math.min(Theme.elementRadius, Math.min(root.width, root.height) / 2)
    opacity: isOpen ? 1 : 0
    scale: isOpen ? 1 : 0.6
    visible: opacity > 0

    RowLayout {
        id: toastContent

        anchors.centerIn: parent
        spacing: 12

        Text {
            renderType: Text.NativeRendering
            font.family: "Material Symbols Outlined"
            font.pixelSize: 17
            text: root.iconText
            color: root.textColor
        }

        Text {
            renderType: Text.NativeRendering
            font.family: Theme.fontFamily
            font.pixelSize: 16
            text: root.message
            color: root.textColor
        }
    }

    Timer {
        id: dismissTimer

        interval: 3000
        onTriggered: {
            root.dismiss();
        }
    }

    Connections {
        function onIsOpenChanged() {
            if (!root.isOpen)
                root.dismissed();
        }

        target: root
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animDurationFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animDurationFast
            easing.type: Easing.OutBack
        }
    }
}
