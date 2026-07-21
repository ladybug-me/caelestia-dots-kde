pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components

StyledRect {
    id: root

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))
    readonly property var windows: (typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.windowList)
        ? KWinActiveWindowBridge.windowList
        : []

    function hasUnminimizedWindow(): bool {
        for (const win of root.windows) {
            if (win && win.address && !win.minimized)
                return true;
        }
        return false;
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    implicitWidth: isHorizontal ? (icon.implicitWidth + Tokens.padding.medium * 2) : barThickness
    implicitHeight: isHorizontal ? barThickness : (icon.implicitHeight + Tokens.padding.medium * 2)

    StateLayer {
        anchors.fill: parent
        radius: root.radius
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.windowList) {
                const shouldMinimize = root.hasUnminimizedWindow();
                for (const win of root.windows) {
                    if (win.address)
                        KWinActiveWindowBridge.setWindowProperty(String(win.address), "minimized", shouldMinimize);
                }
                return;
            }

            Quickshell.execDetached(["sh", "-c", "qdbus6 org.kde.KWin /KWin org.kde.KWin.toggleShowDesktop >/dev/null 2>&1 || qdbus6 org.kde.KWin /KWin org.kde.KWin.showDesktop >/dev/null 2>&1"]);
        }
    }

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        text: "vertical_align_bottom"
        color: Colours.palette.m3onSurface
    }
}