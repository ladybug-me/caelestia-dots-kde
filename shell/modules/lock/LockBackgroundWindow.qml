pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.modules.drawers.blur

Window {
    id: root

    required property var targetScreen

    readonly property real lockHeight: Math.min(root.targetScreen?.width ?? root.width, root.targetScreen?.height ?? root.height)
    readonly property bool isPortrait: (root.targetScreen?.width ?? root.width) < (root.targetScreen?.height ?? root.height)
    property bool contentReady: Colours.schemeLoaded

    color: "black"
    visible: true
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint
    width: root.targetScreen?.width ?? 1920
    height: root.targetScreen?.height ?? 1080

    contentItem.Config.screen: targetScreen.name
    contentItem.Tokens.screen: targetScreen.name

    Timer {
        id: fallbackReadyTimer

        interval: 250
        running: !root.contentReady
        onTriggered: root.contentReady = true
    }

    Shortcut {
        sequences: ["Escape"]
        onActivated: Qt.quit()
    }

    TapHandler {
        onTapped: (eventPoint) => {
            const mapped = root.contentItem.mapToItem(lockContent, eventPoint.position.x, eventPoint.position.y);
            if (!lockContent.contains(mapped)) {
                Qt.quit();
            }
        }
    }

    QtObject {
        id: mockLock

        property bool locked: true
        property bool secure: true
        property bool unlocking: false
        property var pam: pamModule

        signal unlock()

        onUnlock: {
            Quickshell.execDetached(["loginctl", "unlock-session"]);
            Qt.quit();
        }
    }

    Pam {
        id: pamModule

        lock: mockLock
    }

    Loader {
        id: wallpaperLoader

        anchors.fill: parent
        asynchronous: true
        active: true

        source: "../background/Wallpaper.qml"

        onLoaded: {
            item.screen = root.targetScreen;
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Tokens.padding.large * 4
        readonly property int radius: size / 4 * Tokens.rounding.scale

        readonly property real lockLong: root.lockHeight * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio
        readonly property real lockShort: root.lockHeight * Tokens.sizes.lock.heightMult

        anchors.centerIn: parent
        implicitWidth: root.isPortrait ? lockShort : lockLong
        implicitHeight: root.isPortrait ? lockLong : lockShort
        opacity: root.contentReady ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Elevation {
            anchors.fill: lockBg
            radius: lockBg.radius
            level: 2
        }

        ShaderEffectSource {
            id: bgSource

            anchors.fill: lockBg
            sourceItem: wallpaperLoader
            sourceRect: Qt.rect(lockContent.x, lockContent.y, lockContent.width, lockContent.height)

            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blurMax: 64
                blur: 1.0
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: lockBg.width
                        height: lockBg.height
                        radius: lockBg.radius
                    }
                }
            }
        }

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Colours.palette.m3surface
            radius: lockContent.Tokens.rounding.extraLarge * 1.5
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1
        }

        MaterialIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "lock"
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(4).weight(Font.Bold).build()
            opacity: 0 // Hide lock icon since KDE has its own
        }

        BackgroundContent {
            id: content

            isPortrait: root.isPortrait
            lockHeight: root.lockHeight

            anchors.centerIn: parent
            width: lockContent.implicitWidth - Tokens.padding.extraLargeIncreased
            height: lockContent.implicitHeight - Tokens.padding.extraLargeIncreased

            lock: mockLock
        }
    }
}
