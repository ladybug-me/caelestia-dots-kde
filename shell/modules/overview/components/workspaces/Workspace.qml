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

    radius: Tokens.rounding.medium
    color: active ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 1) : (isOccupied ? Colours.tPalette.m3surfaceContainer : "transparent")
    
    border.color: active ? Colours.palette.m3primary : Colours.tPalette.m3outlineVariant
    border.width: active ? 2 : (isOccupied ? 0 : 2)

    Behavior on color { CAnim {} }
    Behavior on border.color { CAnim {} }

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
                required property var modelData
                
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Tokens.rounding.small
                color: Colours.tPalette.m3surfaceContainerHigh
                
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.min(parent.width, parent.height) * 0.6
                    asynchronous: true
                    source: modelData.iconName ? Icons.getAppIcon(modelData.iconName, "image-missing") : (modelData.class ? Icons.getAppIcon(modelData.class, "image-missing") : "")
                }
            }
        }
    }
}
