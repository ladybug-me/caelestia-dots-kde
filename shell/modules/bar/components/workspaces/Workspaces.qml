pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property var bar
    required property ShellScreen screen
    required property bool fullscreen
    readonly property int barThickness: bar.thickness

    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight

    StyledClippingRect {
        id: container
        // Removed manual monitorCenter logic as it's handled natively by Bar.qml layout zones

        readonly property bool onSpecial: false
        property int workspaceCount: {
            if (typeof KWinWorkspaceState !== "undefined" && KWinWorkspaceState.workspaces.length > 0) {
                return KWinWorkspaceState.workspaces.length;
            }
            return Config.bar.workspaces.shown;
        }
        property int activeWsId: {
            if (typeof KWinWorkspaceState === "undefined")
                return 1;
            // With KWin's per-output virtual desktops each screen has its own
            // current desktop, and activeId -- which comes from D-Bus -- only
            // ever reports the focused screen's. Reading it here showed that one
            // on every bar, and made all of them appear to switch whenever the
            // pointer crossed to another monitor.
            const perOutput = KWinWorkspaceState.activeByOutput[root.screen.name];
            if (perOutput > 0)
                return perOutput;
            // Nothing from the tracker yet, or per-output desktops are off, in
            // which case one current desktop is the truth for every screen.
            if (KWinWorkspaceState.activeId > 0)
                return KWinWorkspaceState.activeId;
            return 1;
        }
        readonly property var occupied: {
            let occ = {};
            const count = container.workspaceCount;
            for (let i = 1; i <= count; ++i) {
                occ[i] = false;
            }
            const kwinList = container.kwinWindowList;
            if (kwinList) {
                for (let i = 0; i < kwinList.length; ++i) {
                    const w = kwinList[i];
                    // KDE's virtual desktops span every screen, so a desktop is
                    // "occupied" globally the moment anything is on it anywhere.
                    // This bar belongs to one screen, and saying a desktop is
                    // busy because of a window the user cannot see from here is
                    // not useful -- it reports a full desktop as full and an
                    // empty one as full too.
                    if (w.output !== root.screen.name)
                        continue;
                    if (w.workspace && typeof w.workspace.id === "number") {
                        occ[w.workspace.id] = true;
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
        readonly property int groupOffset: Math.floor((activeWsId - 1) / container.workspaceCount) * container.workspaceCount
        property real blur: onSpecial ? 1 : 0
        readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
        // Force QML dependency tracker to bind to windowList correctly
        property var kwinWindowList: KWinActiveWindowBridge.windowList

        implicitWidth: isHorizontal ? (layout.implicitWidth + Tokens.padding.small) : barThickness
        implicitHeight: isHorizontal ? barThickness : (layout.implicitHeight + Tokens.padding.small)
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        Connections {
            function onWorkspacesChanged() {
                if (typeof KWinActiveWindowBridge !== "undefined") {
                    KWinActiveWindowBridge.refreshWindows();
                }
            }

            target: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState : null
        }
        Item {
            anchors.fill: parent
            scale: container.onSpecial ? 0.8 : 1
            opacity: container.onSpecial ? 0.5 : 1
            layer.enabled: container.blur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: container.blur
                blurMax: 32
            }

            Loader {
                asynchronous: true
                active: Config.bar.workspaces.occupiedBg
                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                sourceComponent: OccupiedBg {
                    workspaces: workspaces
                    occupied: container.occupied
                    groupOffset: container.groupOffset
                }
            }
            GridLayout {
                id: layout

                anchors.centerIn: parent
                columns: isHorizontal ? -1 : 1
                rows: isHorizontal ? 1 : -1
                flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
                columnSpacing: Math.floor(Tokens.spacing.small)
                rowSpacing: Math.floor(Tokens.spacing.small)

                Repeater {
                    id: workspaces

                    model: container.workspaceCount

                    Workspace {
                        activeWsId: container.activeWsId
                        groupOffset: container.groupOffset
                        occupied: container.occupied
                        screenName: root.screen.name
                    }
                }
            }
            Loader {
                asynchronous: true
                anchors.horizontalCenter: isHorizontal ? undefined : parent.horizontalCenter
                anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
                active: Config.bar.workspaces.activeIndicator
                sourceComponent: ActiveIndicator {
                    activeWsId: container.activeWsId
                    workspaces: workspaces
                    mask: layout
                    fullscreen: root.fullscreen
                }
            }
            MouseArea {
                anchors.fill: layout
                onClicked: event => {
                    const ws = (layout.childAt(event.x, event.y) as Workspace)?.ws;
                    if (!ws)
                        return;
                    if (container.activeWsId !== ws) {
                        if (typeof KWinWorkspaceState !== "undefined") {
                            KWinWorkspaceState.setDesktop(ws);
                        }
                    }
                }
                onWheel: event => {
                    if (!Config.bar.scrollActions.workspaces) return;

                    if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
                        KWinWorkspaceState.previousDesktop();
                    } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
                        KWinWorkspaceState.nextDesktop();
                    }
                }
            }
            Behavior on scale {
                Anim {}
            }
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
        Loader {
            id: specialWs

            asynchronous: true
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall
            active: opacity > 0
            scale: container.onSpecial ? 1 : 0.5
            opacity: container.onSpecial ? 1 : 0
            sourceComponent: SpecialWorkspaces {
                screen: root.screen
            }

            Behavior on scale {
                Anim {}
            }
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
        Behavior on blur {
            Anim {
                type: Anim.StandardSmall
            }
        }
    }
}
