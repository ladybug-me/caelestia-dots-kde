pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import Quickshell

Item {
    id: root

    required property int wsId
    required property var list
    
    readonly property var wsData: {
        if (typeof KWinWorkspaceState !== "undefined") {
            const w = KWinWorkspaceState.workspaces;
            for (let i = 0; i < w.length; ++i) {
                if (w[i].index === wsId) return w[i];
            }
        }
        return null;
    }

    readonly property bool active: {
        if (typeof KWinWorkspaceState !== "undefined") {
            return KWinWorkspaceState.activeId === wsId;
        }
        return false;
    }

    readonly property var windows: {
        const kwinList = typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList : null;
        let arr = [];
        if (kwinList) {
            for (let i = 0; i < kwinList.length; ++i) {
                const w = kwinList[i];
                if (w.workspace && w.workspace.id === wsId) {
                    arr.push(w);
                }
            }
        }
        return arr;
    }

    width: 350
    height: list.height
    
    readonly property real screenAspect: {
        const s = QsWindow.window ? QsWindow.window.screen : null;
        if (s && s.height > 0) return s.width / s.height;
        return 16.0 / 9.0;
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: root.wsData ? root.wsData.name : "Workspace " + wsId
                font: Tokens.font.title.medium
                color: Colours.palette.m3onSurface
            }

            IconButton {
                icon: "close"
                visible: root.list.count > 1
                onClicked: {
                    if (typeof KWinActiveWindowBridge !== "undefined") {
                        KWinActiveWindowBridge.runArbitraryScript(`
                            let d = workspace.desktops;
                            for (let i = 0; i < d.length; ++i) {
                                if (i + 1 === ${wsId}) {
                                    workspace.removeDesktop(d[i]);
                                    break;
                                }
                            }
                        `);
                    }
                }
            }
        }

        StyledRect {
            id: dropAreaRect
            Layout.fillWidth: true
            Layout.preferredHeight: width / screenAspect
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerHigh
            
            border.width: root.active ? 2 : (dropArea.containsDrag ? 2 : 0)
            border.color: Colours.palette.m3primary
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (typeof KWinActiveWindowBridge !== "undefined") {
                        KWinActiveWindowBridge.setDesktop(wsId);
                        const v = Visibilities.getForActive();
                        if (v) v.overview = false;
                    }
                }
            }
            
            DropArea {
                id: dropArea
                anchors.fill: parent
                onDropped: (drag) => {
                    if (drag.source && drag.source.windowAddress) {
                        if (typeof KWinActiveWindowBridge !== "undefined") {
                            KWinActiveWindowBridge.setWindowDesktop(drag.source.windowAddress, wsId);
                        }
                    }
                }
            }

            Repeater {
                model: root.windows
                delegate: WindowPreview {
                    windowData: modelData
                    workspaceWidth: dropAreaRect.width
                    workspaceHeight: dropAreaRect.height
                }
            }
        }
        
        Item {
            Layout.fillHeight: true
        }
    }
}
