pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.images
import qs.services
import qs.utils

StyledRect {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset
    readonly property bool isWorkspace: true
    property real scaleFactor: 1.0
    property real swipeOffset: 0.0
    property bool isSwiping: false
    readonly property int baseIndicatorSize: 120
    readonly property int baseWidth: 200
    readonly property int indicatorSize: Math.floor(baseIndicatorSize * scaleFactor)
    readonly property int size: implicitWidth
    readonly property int ws: groupOffset + index + 1
    readonly property int maxIcons: 8
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied
    property var kwinWindowList: KWinActiveWindowBridge.windowList
    readonly property bool active: activeWsId === ws
    readonly property real swipeWeight: {
        if (!isSwiping || swipeOffset === 0.0) return active ? 1.0 : 0.0;
        const activeIdx = activeWsId - 1;
        const targetIdx = swipeOffset > 0 ? activeIdx + 1 : activeIdx - 1;
        const t = Math.abs(swipeOffset);
        const myIdx = ws - 1;
        if (myIdx === activeIdx) return 1.0 - t;
        if (myIdx === targetIdx) return t;
        return 0.0;
    }
    property real smoothSwipeWeight: swipeWeight

    signal selected()
    signal reselected()

    implicitWidth: Math.floor(baseWidth * scaleFactor)
    implicitHeight: indicatorSize
    radius: Tokens.rounding.large
    color: active ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) : (isOccupied ? Colours.tPalette.m3surfaceContainer : "transparent")
    border.color: isSwiping ? Qt.rgba(
        Colours.palette.m3primary.r * smoothSwipeWeight + Colours.tPalette.m3outlineVariant.r * (1.0 - smoothSwipeWeight),
        Colours.palette.m3primary.g * smoothSwipeWeight + Colours.tPalette.m3outlineVariant.g * (1.0 - smoothSwipeWeight),
        Colours.palette.m3primary.b * smoothSwipeWeight + Colours.tPalette.m3outlineVariant.b * (1.0 - smoothSwipeWeight),
        Colours.palette.m3primary.a * smoothSwipeWeight + Colours.tPalette.m3outlineVariant.a * (1.0 - smoothSwipeWeight))
        : (active ? Colours.palette.m3primary : Colours.tPalette.m3outlineVariant)
    border.width: active ? 2 : (isOccupied ? 0 : 2)
    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: Math.floor(baseWidth * scaleFactor)
    Layout.preferredHeight: indicatorSize
    Drag.active: workspaceDragHandler.active
    Drag.source: root
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    transform: Translate {
        x: workspaceDragHandler.active ? workspaceDragHandler.translation.x : 0
        y: workspaceDragHandler.active ? workspaceDragHandler.translation.y : 0
    }
    states: [
        State {
            when: workspaceDragHandler.active

            PropertyChanges {
                target: root
                opacity: 0.8
                z: 999
            }
        }
    ]

    Behavior on color { CAnim {} }
    Behavior on smoothSwipeWeight {
        enabled: root.isSwiping

        SmoothedAnimation {
            velocity: -1
            duration: 60
            easing.type: Easing.Linear
        }
    }
    DragHandler {
        id: workspaceDragHandler

        target: null
        onActiveChanged: {
            if (!active) {
                root.Drag.drop();
            }
        }
    }
    StateLayer {
        id: workspaceMouseArea

        anchors.fill: parent
        radius: parent.radius
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
                if (typeof KWinWorkspaceState !== "undefined") {
                    const wId = KWinWorkspaceState.workspaces[root.ws - 1]?.id || root.ws.toString();
                    KWinWorkspaceState.switchTo(wId);
                } else {
                    const isKWin = typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.windowList;
                    if (isKWin) {
                        KWinWorkspaceState.setDesktop(root.ws);
                    } else {
                        Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/KWin", "setCurrentDesktop", root.ws.toString()]);
                    }
                }
                selected();
            }
        }
    }
    Item {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Tokens.padding.small
        width: Math.floor(28 * root.scaleFactor)
        height: Math.floor(28 * root.scaleFactor)
        z: 99
        opacity: 1.0
        enabled: true

        Behavior on opacity { CAnim { duration: 150 } }
        StateLayer {
            id: closeBtn

            anchors.fill: parent
            radius: parent.width / 2
            onClicked: {
                if (typeof KWinWorkspaceState !== "undefined") {
                    const wId = KWinWorkspaceState.workspaces[root.ws - 1].id;
                    if (wId) KWinWorkspaceState.removeWorkspace(wId);
                }
            }
        }
        MaterialIcon {
            anchors.centerIn: parent
            text: "close"
            fontStyle.pixelSize: Math.max(10, Math.floor(18 * root.scaleFactor))
            color: Colours.palette.m3onSurfaceVariant
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
        readonly property int count: repeater.count

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        rowSpacing: Tokens.padding.small
        columnSpacing: Tokens.padding.small
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
                property real dragStartX: 0
                property real dragStartY: 0
                property real dragStartWidth: 0
                property real dragStartHeight: 0
                property Item topLevel: null

                radius: Tokens.rounding.small
                color: Colours.tPalette.m3surfaceContainerHigh
                Layout.fillWidth: true
                Layout.fillHeight: true
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
