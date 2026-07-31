pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import Quickshell
import Quickshell.Widgets
import org.kde.pipewire as Pipewire
import ".."

Item {
    id: root

    readonly property int activeWsId: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.activeId : 1

    readonly property var activeWindows: {
        const kwinList = typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList : null;
        let arr = [];
        if (kwinList) {
            for (let i = 0; i < kwinList.length; ++i) {
                const w = kwinList[i];
                if (w.workspace && w.workspace.id === activeWsId) {
                    arr.push(w);
                }
            }
        }
        return arr;
    }
    
    onActiveWindowsChanged: console.log("ActiveWorkspaceWindows: active windows count is", activeWindows.length)

    Grid {
        anchors.centerIn: parent
        spacing: Tokens.spacing.large
        columns: {
            const count = root.activeWindows.length;
            if (count <= 3) return Math.max(1, count);
            if (count === 4) return 2;
            if (count <= 6) return 3;
            return 4;
        }
        
        Repeater {
            model: root.activeWindows
            
            delegate: StyledRect {
                id: activeWin
                required property var modelData
                
                readonly property real windowAspect: {
                    const w = modelData.width;
                    const h = modelData.height;
                    return (w > 0 && h > 0) ? (w / h) : (16.0 / 9.0);
                }
                
                width: Math.max(100, Math.min(400, root.width / 3 - Tokens.spacing.large))
                height: width / windowAspect
                
                color: "transparent"
                radius: Tokens.rounding.medium
                
                HoverHandler { id: hover }
                
                border.width: hover.hovered ? 2 : 0
                border.color: Colours.palette.m3primary
                
                WindowScreencastRequest {
                    id: screencast
                    uuid: activeWin.modelData.address || ""
                }
                
                Pipewire.PipeWireSourceItem {
                    anchors.fill: parent
                    visible: screencast.objectSerial !== 0
                    objectSerial: screencast.objectSerial
                }
                
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 64
                    asynchronous: true
                    visible: screencast.objectSerial === 0
                    source: activeWin.modelData.iconName ? Icons.getAppIcon(activeWin.modelData.iconName, "image-missing") : (activeWin.modelData.class ? Icons.getAppIcon(activeWin.modelData.class, "image-missing") : "")
                }
                
                StyledRect {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: Tokens.padding.small
                    color: Colours.tPalette.m3surfaceVariant
                    radius: Tokens.rounding.small
                    implicitWidth: titleText.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: titleText.implicitHeight + Tokens.padding.small * 2
                    
                    StyledText {
                        id: titleText
                        anchors.centerIn: parent
                        text: activeWin.modelData.title
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, activeWin.width - Tokens.padding.large * 2)
                    }
                }
                
                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    onClicked: {
                        if (activeWin.modelData.address) {
                            if (typeof KWinActiveWindowBridge !== "undefined") {
                                KWinActiveWindowBridge.focusWindow(activeWin.modelData.address);
                            }
                        }
                        const v = Visibilities.getForActive();
                        if (v) v.overview = false;
                    }
                }
                
                // Add close button
                StyledRect {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Tokens.padding.small
                    implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * 2
                    implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.small
                    color: Colours.tPalette.m3surfaceVariant
                    opacity: hover.hovered ? 1 : 0
                    visible: opacity > 0.01
                    
                    Behavior on opacity { Anim {} }
                    
                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.small
                        onClicked: {
                            if (activeWin.modelData.address && typeof KWinActiveWindowBridge !== "undefined") {
                                KWinActiveWindowBridge.closeWindow(activeWin.modelData.address);
                            }
                        }
                    }
                    
                    MaterialIcon {
                        id: closeIcon
                        anchors.centerIn: parent
                        text: "close"
                    }
                }
            }
        }
    }
}
