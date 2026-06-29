pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root
    
    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight
    
    required property var bar
    required property ShellScreen screen
    required property bool fullscreen
    
    StyledClippingRect {
        id: container

        // Removed manual monitorCenter logic as it's handled natively by Bar.qml layout zones


        readonly property bool onSpecial: false
        property int activeWsId: 1
        
        Process {
            id: kwinDesktopPollerInit
            running: true
            command: ["qdbus6", "org.kde.KWin", "/KWin", "currentDesktop"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var val = parseInt(text.trim());
                    if (!isNaN(val)) container.activeWsId = val;
                }
            }
        }

        Process {
            id: kwinDesktopListener
            running: true
            command: ["dbus-monitor", "type='signal',interface='org.kde.KWin.VirtualDesktopManager',member='currentChanged'"]
            stdout: StdioCollector {
                waitForEnd: false
                onDataChanged: {
                    kwinDesktopPollerInit.running = true;
                }
            }
        }

        readonly property var occupied: {
            const occ = {};
            for (let i = 1; i <= Config.bar.workspaces.shown; i++) {
                occ[i] = true;
            }
            return occ;
        }
        readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

        property real blur: onSpecial ? 1 : 0

        readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

        implicitWidth: isHorizontal ? (layout.implicitWidth + Tokens.padding.small) : Tokens.sizes.bar.innerWidth
        implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : (layout.implicitHeight + Tokens.padding.small)

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        Item {
            anchors.fill: parent
            scale: container.onSpecial ? 0.8 : 1
            opacity: container.onSpecial ? 0.5 : 1
            visible: !root.fullscreen

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

                    model: Config.bar.workspaces.shown

                    Workspace {
                        activeWsId: container.activeWsId
                        occupied: container.occupied
                        groupOffset: container.groupOffset
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
                    if (container.activeWsId !== ws)
                        Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/KWin", "setCurrentDesktop", ws.toString()]);
                }
                onWheel: event => {
                    if (!Config.bar.scrollActions.workspaces) return;
                    
                    if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
                        Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/KWin", "previousDesktop"]);
                    } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
                        Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/KWin", "nextDesktop"]);
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
