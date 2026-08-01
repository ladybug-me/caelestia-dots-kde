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
    property var activeInfoClient: null
    
    signal requestWindowInfo(var client)

    Grid {
        id: gridItem
        anchors.centerIn: parent
        spacing: Tokens.spacing.large
        columns: {
            const count = root.activeWindows.length;
            if (count === 0) return 1;
            
            let bestCols = 1;
            let bestDiff = 9999;
            const targetRatio = root.width / Math.max(1, root.height);
            
            for (let c = 1; c <= count; c++) {
                const r = Math.ceil(count / c);
                const ratio = c / r;
                const diff = Math.abs(ratio - targetRatio);
                // Also give a slight penalty to having too many columns compared to rows
                // to prevent overly wide grids when count is small (e.g. 4 items -> 2x2 is better than 4x1)
                const adjustedDiff = diff + (c > r ? (c - r) * 0.1 : 0);
                
                if (adjustedDiff < bestDiff) {
                    bestDiff = adjustedDiff;
                    bestCols = c;
                }
            }
            
            // Fallbacks for very small numbers to keep them looking normal
            if (count === 2) return 2;
            if (count === 3) return 3;
            if (count === 4) return 2;
            
            return bestCols;
        }
        
        Repeater {
            model: root.activeWindows
            
            delegate: StyledRect {
                id: activeWin
                required property var modelData
                
                readonly property int cardWidth: {
                    const cols = gridItem.columns;
                    const rows = Math.ceil(root.activeWindows.length / cols) || 1;
                    
                    const maxW = (root.width * 0.9 - Tokens.spacing.large * (cols - 1)) / cols;
                    
                    const extra = Tokens.padding.medium * 2 + Tokens.spacing.small + 30; // padding, spacing, and title text height
                    const maxH = (root.height * 0.9 - Tokens.spacing.large * (rows - 1)) / rows;
                    const maxWFromH = (maxH - extra) * windowAspect;
                    
                    return Math.max(100, Math.min(1000, Math.min(maxW, maxWFromH)));
                }

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
                        
                        function updateStream() {
                            const isStolen = root.activeInfoClient && root.activeInfoClient.address === activeWin.modelData.address;
                            if (root.opacity > 0 && activeWin.modelData.address && !isStolen) {
                                if (!streamRequest) {
                                    streamRequest = ScreencastManager.requestStream(activeWin.modelData.address);
                                }
                            } else {
                                if (streamRequest) {
                                    ScreencastManager.releaseStream(activeWin.modelData.address);
                                    streamRequest = null;
                                }
                            }
                        }
                        
                        Connections {
                            target: root
                            function onOpacityChanged() {
                                thumb.updateStream();
                            }
                            function onActiveInfoClientChanged() {
                                thumb.updateStream();
                            }
                        }
                        
                        Component.onCompleted: updateStream()
                        
                        Component.onDestruction: {
                            if (streamRequest && activeWin.modelData.address) {
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
                            width: {
                                const wAspect = activeWin.windowAspect;
                                const containerAspect = thumb.width / Math.max(1, thumb.height);
                                return (wAspect > containerAspect) ? thumb.width : thumb.height * wAspect;
                            }
                            height: {
                                const wAspect = activeWin.windowAspect;
                                const containerAspect = thumb.width / Math.max(1, thumb.height);
                                return (wAspect > containerAspect) ? thumb.width / wAspect : thumb.height;
                            }
                            anchors.centerIn: parent
                            visible: thumb.screencastSerial !== 0
                            objectSerial: thumb.screencastSerial
                        }
                        
                        // Action buttons row (Info + Close)
                        RowLayout {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Tokens.padding.small
                            spacing: Tokens.spacing.small
                            opacity: hover.hovered ? 1 : 0
                            visible: opacity > 0.01
                            
                            Behavior on opacity { Anim {} }
                            
                            // Info button
                            StyledRect {
                                implicitWidth: infoIcon.implicitHeight + Tokens.padding.small * 2
                                implicitHeight: infoIcon.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.small
                                color: Colours.palette.m3secondaryContainer
                                
                                StateLayer {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.small
                                    onClicked: root.requestWindowInfo(activeWin.modelData)
                                }
                                
                                MaterialIcon {
                                    id: infoIcon
                                    anchors.centerIn: parent
                                    text: "chevron_right"
                                    color: Colours.palette.m3onSecondaryContainer
                                    fontStyle.pointSize: Tokens.font.body.medium.pointSize
                                }
                            }
                        
                            // Close button
                            StyledRect {
                                implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * 2
                                implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.small
                                color: Colours.palette.m3errorContainer
                                
                                StateLayer {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.small
                                    onClicked: {
                                        if (activeWin.modelData.address) {
                                            if (typeof KWinActiveWindowBridge !== "undefined") {
                                                KWinActiveWindowBridge.closeWindow(activeWin.modelData.address);
                                            } else {
                                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${activeWin.modelData.address}" })` : `closewindow address:0x${activeWin.modelData.address}`);
                                            }
                                        }
                                    }
                                }
                                
                                MaterialIcon {
                                    id: closeIcon
                                    anchors.centerIn: parent
                                    text: "close"
                                    color: Colours.palette.m3onErrorContainer
                                    fontStyle.pointSize: Tokens.font.body.medium.pointSize
                                }
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
