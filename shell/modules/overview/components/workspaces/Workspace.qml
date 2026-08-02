pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import Caelestia.Services

GridLayout {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset

    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property bool isHorizontal: true
    readonly property int indicatorSize: 40 // Default size for the workspace indicator

    // Unanimated prop for others to use as reference
    readonly property int size: implicitWidth + (hasWindows ? Tokens.padding.extraSmall : 0)

    readonly property int ws: groupOffset + index + 1
    readonly property int maxIcons: Config.bar.workspaces.maxWindowIcons
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows
    property var kwinWindowList: KWinActiveWindowBridge.windowList

    columns: -1
    rows: 1
    flow: GridLayout.LeftToRight

    Layout.alignment: Qt.AlignVCenter
    Layout.preferredWidth: size
    Layout.preferredHeight: -1

    columnSpacing: 0
    rowSpacing: 0

    Loader {
        id: indicator

        Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
        Layout.preferredWidth: indicatorSize - Tokens.padding.small
        Layout.preferredHeight: indicatorSize - Tokens.padding.small

        asynchronous: true
        sourceComponent: Config.bar.workspaces.useIcon ? iconComponent : textComponent
    }

    Component {
        id: textComponent

        StyledText {
            anchors.fill: parent
            animate: true
            text: {
                const wsName = root.ws;
                let displayName = wsName.toString();
                if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                    displayName = displayName.toUpperCase();
                } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                    displayName = displayName.toLowerCase();
                }
                const label = Config.bar.workspaces.label || displayName;
                const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
                return root.activeWsId === root.ws ? activeLabel : root.isOccupied ? occupiedLabel : label;
            }
            color: Config.bar.workspaces.occupiedBg || root.isOccupied || root.activeWsId === root.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        Item {
            id: iconRoot

            // Track if this position was active (independent of which workspace)
            readonly property bool active: root.activeWsId === root.ws
            property int randShape: MaterialShape.Slanted
            property bool wasPositionActive: false
            property int lastKnownWs: -1
            property int prevActiveWsId: -1

            // Track the previous workspace at this position (before current change)
            property int prevWs: -1

            // Watch for workspace ID changes while inactive by using a binding
            property int watchedWs: root.ws

            // Track the last watched ws separately for detecting changes
            property int lastWatchedWs: -1

            // JavaScript functions
            function handleActivation() {
                const wsChanged = lastKnownWs !== root.ws;
                if (active && (!wasPositionActive || wsChanged)) {
                    const shapes = [MaterialShape.Slanted, MaterialShape.Arch, MaterialShape.Oval, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Arrow, MaterialShape.Diamond, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.VerySunny, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.Clover8Leaf, MaterialShape.SoftBurst, MaterialShape.Ghostish];
                    const shuffled = [...shapes].sort(() => Math.random() - 0.5);
                    randShape = shuffled[0];
                    wsShape.shape = randShape;
                    wsShape.scale = 1 / 3;
                    deactivateAnim.stop();
                    activateAnim.fromValue = 1 / 3;
                    activateAnim.toValue = 2 / 3;
                    activateAnim.running = true;
                } else if (!active && (wasPositionActive || wsChanged)) {
                    const targetShape = root.isOccupied ? MaterialShape.Square : MaterialShape.Circle;
                    wsShape.shape = targetShape;
                    wsShape.scale = 1 / 3;
                    activateAnim.stop();
                    deactivateAnim.stop();
                }
                wasPositionActive = active;
                prevWs = lastKnownWs;
                lastKnownWs = root.ws;
                prevActiveWsId = root.activeWsId;
            }

            // Signal handlers
            onWatchedWsChanged: {
                if (lastWatchedWs !== -1 && watchedWs !== lastWatchedWs && !active) {
                    activateAnim.stop();
                    deactivateAnim.stop();
                    wsShape.shape = root.isOccupied ? MaterialShape.Square : MaterialShape.Circle;
                    wsShape.scale = 1 / 3;
                }
                lastWatchedWs = watchedWs;
            }

            onPrevActiveWsIdChanged: {
                if (prevActiveWsId !== -1 && prevActiveWsId !== root.activeWsId && active) {
                    handleActivation();
                }
            }

            onActiveChanged: handleActivation()

            // Bindings
            implicitWidth: indicatorSize - Tokens.padding.small
            implicitHeight: indicatorSize - Tokens.padding.small

            // Initialize state when component is created
            Component.onCompleted: {
                if (active) {
                    handleActivation();
                } else {
                    wsShape.shape = root.isOccupied ? MaterialShape.Square : MaterialShape.Circle;
                }
                wasPositionActive = active;
                prevWs = -1;
                lastKnownWs = root.ws;
                prevActiveWsId = root.activeWsId;
                lastWatchedWs = root.ws;
            }

            MaterialShape {
                id: wsShape

                anchors.centerIn: parent
                implicitSize: iconRoot.width
                width: implicitWidth
                height: implicitHeight
                scale: iconRoot.active ? 2 / 3 : 1 / 3
                color: Config.bar.workspaces.occupiedBg || root.isOccupied || root.activeWsId === root.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)

                Behavior on color {
                    CAnim {}
                }

                Behavior on scale {
                    enabled: !activateAnim.running && !deactivateAnim.running

                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                SequentialAnimation {
                    id: activateAnim

                    property real fromValue: 1 / 3
                    property real toValue: 2 / 3

                    Anim {
                        target: wsShape
                        property: "scale"
                        from: activateAnim.fromValue
                        to: activateAnim.toValue
                        type: Anim.FastSpatial
                    }
                }

                SequentialAnimation {
                    id: deactivateAnim

                    property real fromValue: 2 / 3
                    property real toValue: 1 / 3

                    Anim {
                        target: wsShape
                        property: "scale"
                        from: deactivateAnim.fromValue
                        to: deactivateAnim.toValue
                        type: Anim.FastSpatial
                    }
                }
            }
        }
    }

    Loader {
        id: windows

        asynchronous: true

        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: enabled
        Layout.topMargin: 0
        Layout.leftMargin: -indicatorSize / 10

        visible: active
        active: root.hasWindows

        sourceComponent: rowComponent
    }

    Component {
        id: rowComponent

        Row {
            spacing: 0

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: {
                        const ws = root.ws;
                        let windows = [];
                        const kwinList = root.kwinWindowList; // Force QML dependency tracker
                        if (typeof KWinActiveWindowBridge !== "undefined" && kwinList) {
                            const wins = kwinList;
                            for (let i = 0; i < wins.length; ++i) {
                                const w = wins[i];
                                if (w.workspace && (w.workspace.id === ws || w.workspace.index === ws) && w["class"] !== "quickshell" && w["class"] !== "plasmashell") {
                                    windows.push(w);
                                }
                            }
                        } else if (typeof Hypr !== "undefined") {
                            const wins = Hypr.toplevels.values;
                            for (let i = 0; i < wins.length; ++i) {
                                if (wins[i].workspace && wins[i].workspace.id === ws) {
                                    windows.push(wins[i]);
                                }
                            }
                        }
                        const maxIcons = root.maxIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                MaterialIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject ? modelData.lastIpcObject["class"] : modelData["class"], "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    Behavior on Layout.preferredWidth {
        Anim {}
    }
}
