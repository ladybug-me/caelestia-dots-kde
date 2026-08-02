pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils
import Caelestia.Services

StyledRect {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset

    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property int indicatorSize: 120 // Increased height for rectangular box
    readonly property int size: implicitWidth

    readonly property int ws: groupOffset + index + 1
    readonly property int maxIcons: 8
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied
    property var kwinWindowList: KWinActiveWindowBridge.windowList
    
    readonly property bool active: activeWsId === ws

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: 200
    Layout.preferredHeight: indicatorSize

    implicitWidth: 200
    implicitHeight: indicatorSize

    radius: Tokens.rounding.large
    color: active ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) : (isOccupied ? Colours.tPalette.m3surfaceContainer : "transparent")
    
    border.color: active ? Colours.palette.m3primary : Colours.tPalette.m3outlineVariant
    border.width: active ? 2 : (isOccupied ? 0 : 2)

    Behavior on color { CAnim {} }
    Behavior on border.color { CAnim {} }

    signal selected()
    signal reselected()

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (active) {
                reselected();
                // Close overview if reselected
                let p = parent;
                while (p) {
                    if (p.requestClose) {
                        p.requestClose();
                        break;
                    }
                    p = p.parent;
                }
            } else {
                selected();
            }
        }
    }

    StyledText {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: Tokens.padding.small
        text: root.ws.toString()
        font.pixelSize: 24
        font.weight: Font.Bold
        color: Colours.tPalette.m3onSurfaceVariant
        opacity: 0.3
    }
    
    DropArea {
        anchors.fill: parent
        onDropped: drop => {
            const sourceItem = drop.source;
            if (sourceItem && sourceItem.clientAddress) {
                if (sourceItem.wsId !== root.ws) {
                    sourceItem.visible = false;
                    if (typeof KWinActiveWindowBridge !== "undefined") {
                        KWinActiveWindowBridge.setWindowDesktop(sourceItem.clientAddress, root.ws);
                    } else {
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.movetoworkspace({ workspace = "${root.ws}", window = "address:0x${sourceItem.clientAddress}" })` : `movetoworkspace ${root.ws},address:0x${sourceItem.clientAddress}`);
                    }
                }
                drop.accept();
            }
        }
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        rowSpacing: Tokens.padding.small
        columnSpacing: Tokens.padding.small
        
        readonly property int count: repeater.count
        columns: count <= 2 ? Math.max(1, count) : Math.ceil(count / 2)
        
        Repeater {
            id: repeater
            model: ScriptModel {
                values: {
                    const wsId = root.ws;
                    let windows = [];
                    const kwinList = root.kwinWindowList; 
                    if (typeof KWinActiveWindowBridge !== "undefined" && kwinList) {
                        const wins = kwinList;
                        for (let i = 0; i < wins.length; ++i) {
                            const w = wins[i];
                            if (w.workspace && (w.workspace.id === wsId || w.workspace.index === wsId) && w["class"] !== "quickshell" && w["class"] !== "plasmashell") {
                                windows.push(w);
                            }
                        }
                    } else if (typeof Hypr !== "undefined") {
                        const wins = Hypr.toplevels.values;
                        for (let i = 0; i < wins.length; ++i) {
                            if (wins[i].workspace && wins[i].workspace.id === wsId) {
                                windows.push(wins[i]);
                            }
                        }
                    }
                    const maxIcons = root.maxIcons;
                    return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                }
            }
            
            delegate: StyledRect {
                id: iconDelegate
                required property var modelData
                
                readonly property string clientAddress: modelData.address || ""
                readonly property int wsId: root.ws
                
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.small
                color: Colours.tPalette.m3surfaceContainerHigh
                
                property real dragStartX: 0
                property real dragStartY: 0
                property real dragStartWidth: 0
                property real dragStartHeight: 0
                
                property Item topLevel: null
                
                Drag.active: dragHandler.active
                Drag.source: iconDelegate
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                states: [
                    State {
                        when: dragHandler.active
                        ParentChange {
                            target: iconDelegate
                            parent: topLevel
                            x: iconDelegate.dragStartX
                            y: iconDelegate.dragStartY
                            width: iconDelegate.dragStartWidth
                            height: iconDelegate.dragStartHeight
                        }
                        PropertyChanges {
                            target: iconDelegate
                            opacity: 0.8
                            z: 999
                        }
                    }
                ]
                
                DragHandler {
                    id: dragHandler
                    onActiveChanged: {
                        if (active) {
                            let tl = iconDelegate;
                            while (tl.parent) tl = tl.parent;
                            iconDelegate.topLevel = tl;
                            
                            if (tl) {
                                const p = iconDelegate.mapToItem(tl, 0, 0);
                                iconDelegate.dragStartX = p.x;
                                iconDelegate.dragStartY = p.y;
                            }
                            iconDelegate.dragStartWidth = iconDelegate.width;
                            iconDelegate.dragStartHeight = iconDelegate.height;
                        } else {
                            iconDelegate.Drag.drop();
                        }
                    }
                }
                
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.min(parent.width, parent.height) * 0.6
                    asynchronous: true
                    source: modelData.iconName ? Icons.getAppIcon(modelData.iconName, "image-missing") : (modelData.class ? Icons.getAppIcon(modelData.class, "image-missing") : "")
                }
                
                StateLayer {
                    anchors.fill: parent
                    radius: parent.radius
                    onClicked: {
                        if (root.active) {
                            if (modelData.address) {
                                if (typeof KWinActiveWindowBridge !== "undefined") {
                                    KWinActiveWindowBridge.focusWindow(modelData.address);
                                } else {
                                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                                }
                                
                                // Try to close overview by finding WindowGrid root
                                let p = parent;
                                while (p) {
                                    if (p.requestClose) {
                                        p.requestClose();
                                        break;
                                    }
                                    p = p.parent;
                                }
                            }
                        } else {
                            root.selected();
                        }
                    }
                }
            }
        }
    }
}
