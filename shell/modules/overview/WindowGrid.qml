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
import qs.utils

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

    property var cardItems: []
    property alias grid: gridItem

    Grid {
        id: gridItem
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
                
                readonly property int cardWidth: Math.max(100, Math.min(400, root.width / 3 - Tokens.spacing.large))

                readonly property real windowAspect: {
                    const w = modelData.width;
                    const h = modelData.height;
                    return (w > 0 && h > 0) ? (w / h) : (16.0 / 10.0);
                }
                
                readonly property int thumbHeight: {
                    const raw = Math.round(activeWin.cardWidth / windowAspect);
                    const max = Math.round(activeWin.cardWidth * 1.6); // never taller than 1.6x width
                    const min = Math.round(activeWin.cardWidth * 0.4);
                    return Math.max(min, Math.min(max, raw));
                }
                
                implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
                
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.medium
                
                Component.onCompleted: {
                    root.cardItems = [...root.cardItems, activeWin];
                }
                Component.onDestruction: {
                    root.cardItems = root.cardItems.filter(x => x !== activeWin);
                }

                HoverHandler { id: hover }
                
                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    onClicked: {
                        if (activeWin.modelData.address) {
                            if (typeof KWinActiveWindowBridge !== "undefined") {
                                KWinActiveWindowBridge.focusWindow(activeWin.modelData.address);
                            } else {
                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${activeWin.modelData.address}" })` : `focuswindow address:0x${activeWin.modelData.address}`);
                            }
                        }
                        const v = Visibilities.getForActive();
                        if (v) v.overview = false;
                    }
                }

                ColumnLayout {
                    id: cardLayout
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small
                    
                    StyledClippingRect {
                        id: thumb
                        Layout.preferredWidth: activeWin.cardWidth
                        Layout.preferredHeight: activeWin.thumbHeight
                        color: Colours.tPalette.m3surfaceContainerHighest
                        radius: Tokens.rounding.medium
                        
                        property var streamRequest: null
                        Component.onCompleted: {
                            if (activeWin.modelData.address) {
                                streamRequest = ScreencastManager.requestStream(activeWin.modelData.address);
                            }
                        }
                        Component.onDestruction: {
                            if (activeWin.modelData.address) {
                                ScreencastManager.releaseStream(activeWin.modelData.address);
                            }
                        }
                        
                        readonly property int screencastSerial: streamRequest ? streamRequest.objectSerial : 0
                        
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: thumb.height * 0.5
                            asynchronous: true
                            visible: thumb.screencastSerial === 0
                            source: activeWin.modelData.iconName ? Icons.getAppIcon(activeWin.modelData.iconName, "image-missing") : (activeWin.modelData.class ? Icons.getAppIcon(activeWin.modelData.class, "image-missing") : "")
                        }
                        
                        Pipewire.PipeWireSourceItem {
                            anchors.fill: parent
                            visible: thumb.screencastSerial !== 0
                            objectSerial: thumb.screencastSerial
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
                                fontStyle.pointSize: Tokens.font.body.medium.pointSize
                            }
                        }
                    }
                    
                    StyledText {
                        id: titleText
                        Layout.preferredWidth: activeWin.cardWidth
                        text: activeWin.modelData.title || ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
