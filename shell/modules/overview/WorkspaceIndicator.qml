pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import Quickshell
import "components/workspaces" as WsComponents
import Caelestia.Services

Item {
    id: root
    
    property int count: 0
    property int currentIndex: 0
    signal workspaceSelected(int index)
    signal workspaceReselected(int index)
    signal createWorkspaceRequest()

    implicitWidth: layout.implicitWidth + Tokens.padding.small
    implicitHeight: layout.implicitHeight + Tokens.padding.small

    readonly property int activeWsId: currentIndex + 1

    property int maxWidth: 1000
    readonly property real requiredWidth: (count + 1) * 200 + count * Tokens.spacing.small
    readonly property real scaleFactor: requiredWidth > maxWidth ? maxWidth / requiredWidth : 1.0

    readonly property var occupied: {
        let occ = {};
        for (let i = 1; i <= root.count; ++i) {
            occ[i] = false;
        }
        
        const kwinList = root.kwinWindowList;
        if (kwinList) {
            for (let i = 0; i < kwinList.length; ++i) {
                const w = kwinList[i];
                if (w.workspace) {
                    const wid = typeof w.workspace.id === "number" ? w.workspace.id : (typeof w.workspace.index === "number" ? w.workspace.index : null);
                    if (wid !== null) occ[wid] = true;
                }
            }
        } else if (typeof Hypr !== "undefined") {
            const wins = Hypr.toplevels.values;
            for (let i = 0; i < wins.length; ++i) {
                if (wins[i].workspace && typeof wins[i].workspace.id === "number") {
                    occ[wins[i].workspace.id] = true;
                }
            }
        }
        return occ;
    }

    // Force QML dependency tracker to bind to windowList correctly
    property var kwinWindowList: KWinActiveWindowBridge.windowList

    Connections {
        target: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState : null
        function onWorkspacesChanged() {
            if (typeof KWinActiveWindowBridge !== "undefined") {
                KWinActiveWindowBridge.refreshWindows();
            }
        }
    }

    Item {
        anchors.fill: parent

        Loader {
            asynchronous: true
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: WsComponents.OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: 0
            }
        }

        Loader {
            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
            active: true

            sourceComponent: WsComponents.ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
            }
        }

        GridLayout {
            id: layout

            anchors.centerIn: parent
            columns: -1
            rows: 1
            flow: GridLayout.LeftToRight
            columnSpacing: Math.floor(Tokens.spacing.small)
            rowSpacing: Math.floor(Tokens.spacing.small)

            Repeater {
                id: workspaces

                model: root.count

                WsComponents.Workspace {
                    scaleFactor: root.scaleFactor
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: 0
                    onSelected: root.workspaceSelected(ws - 1)
                    onReselected: root.workspaceReselected(ws - 1)
                }
            }
            
            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.floor(200 * root.scaleFactor)
                Layout.preferredHeight: Math.floor(120 * root.scaleFactor)
                
                radius: Tokens.rounding.large
                color: "transparent"
                border.color: Colours.tPalette.m3outlineVariant
                border.width: 2
                
                StyledText {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: Math.max(12, Math.floor(24 * root.scaleFactor))
                    font.weight: Font.Bold
                    color: Colours.tPalette.m3onSurfaceVariant
                    opacity: 0.5
                }
                
                StateLayer {
                    anchors.fill: parent
                    radius: parent.radius
                    onClicked: {
                        if (typeof KWinWorkspaceState !== "undefined") {
                            KWinWorkspaceState.createWorkspace();
                        } else if (typeof Hypr !== "undefined") {
                            Hypr.dispatch("workspace empty");
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: layout
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                if (!Config.bar.scrollActions.workspaces) return;
                
                if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
                    if (root.currentIndex > 0) {
                        root.workspaceSelected(root.currentIndex - 1);
                    }
                } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
                    if (root.currentIndex < root.count - 1) {
                        root.workspaceSelected(root.currentIndex + 1);
                    }
                }
            }
        }
    }
}
