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

        property bool monitorCenter: Config.bar.workspaces.monitorCenter ?? true

        readonly property real _minGap: root.bar.vPadding + Tokens.spacing.medium
        property real _slotX: root.parent ? root.parent.x : 0
        property real _slotY: root.parent ? root.parent.y : 0
        property real _minBoundLeft: 0
        property real _maxBoundRight: root.bar.width
        property real _minBoundTop: 0
        property real _maxBoundBottom: root.bar.height

        function _updateBounds() {
            if (!root.parent || !root.bar.children) return;
            const children = root.bar.children;
            let dockIdx = -1;
            for (let i = 0; i < children.length; i++) {
                if (children[i] === root.parent) {
                    dockIdx = i;
                    break;
                }
            }
            if (dockIdx === -1) return;

            const minG = root.bar.vPadding;
            let minTop = minG;
            let minLeft = minG;
            let maxBottom = root.bar.height - minG;
            let maxRight = root.bar.width - minG;

            const idealAbsX = root.bar.isHorizontal ? (root.bar.width / 2) : 0;
            const idealAbsY = !root.bar.isHorizontal ? (root.bar.height / 2) : 0;

            for (let i = 0; i < children.length; i++) {
                if (i === dockIdx) continue;
                const child = children[i];
                if (child.visible && child.width > 0 && child.height > 0 && child.sourceComponent) {
                    const itemW = (child.item && child.item.implicitWidth > 0) ? child.item.implicitWidth : child.width;
                    const itemH = (child.item && child.item.implicitHeight > 0) ? child.item.implicitHeight : child.height;

                    if (root.bar.isHorizontal) {
                        const childRight = child.x + itemW;
                        const childLeft = child.x;
                        
                        if (childLeft < idealAbsX && childRight > idealAbsX) {
                            if (i < dockIdx) {
                                minLeft = Math.max(minLeft, childRight + Tokens.spacing.medium);
                            } else {
                                maxRight = Math.min(maxRight, childLeft - Tokens.spacing.medium);
                            }
                        } else if (childRight <= idealAbsX) {
                            minLeft = Math.max(minLeft, childRight + Tokens.spacing.medium);
                        } else {
                            maxRight = Math.min(maxRight, childLeft - Tokens.spacing.medium);
                        }
                    } else {
                        const childBottom = child.y + itemH;
                        const childTop = child.y;
                        
                        if (childTop < idealAbsY && childBottom > idealAbsY) {
                            if (i < dockIdx) {
                                minTop = Math.max(minTop, childBottom + Tokens.spacing.medium);
                            } else {
                                maxBottom = Math.min(maxBottom, childTop - Tokens.spacing.medium);
                            }
                        } else if (childBottom <= idealAbsY) {
                            minTop = Math.max(minTop, childBottom + Tokens.spacing.medium);
                        } else {
                            maxBottom = Math.min(maxBottom, childTop - Tokens.spacing.medium);
                        }
                    }
                }
            }

            _minBoundTop = minTop;
            _maxBoundBottom = maxBottom;
            _minBoundLeft = minLeft;
            _maxBoundRight = maxRight;
        }

        Connections {
            target: root.parent
            function onXChanged() { container._slotX = root.parent ? root.parent.x : 0; Qt.callLater(container._updateBounds) }
            function onYChanged() { container._slotY = root.parent ? root.parent.y : 0; Qt.callLater(container._updateBounds) }
        }
        Connections {
            target: root.bar
            function onWidthChanged()  { Qt.callLater(() => { container._slotX = root.parent ? root.parent.x : 0; container._updateBounds() }) }
            function onHeightChanged() { Qt.callLater(() => { container._slotY = root.parent ? root.parent.y : 0; container._updateBounds() }) }
        }

        readonly property real _centerInSlot: root.bar.isHorizontal
            ? (root.bar.width  / 2 - _slotX)
            : (root.bar.height / 2 - _slotY)

        x: {
            if (!root.bar.isHorizontal || !monitorCenter) return (root.parent ? root.parent.width : root.width) / 2 - width / 2;
            const ideal = _centerInSlot - width / 2;
            const minX = _minBoundLeft - _slotX;
            const maxX = _maxBoundRight - _slotX - width;
            return Math.max(minX, Math.min(ideal, maxX));
        }
        y: {
            if (root.bar.isHorizontal || !monitorCenter) return (root.parent ? root.parent.height : root.height) / 2 - height / 2;
            const ideal = _centerInSlot - height / 2;
            const minY = _minBoundTop - _slotY;
            const maxY = _maxBoundBottom - _slotY - height;
            return Math.max(minY, Math.min(ideal, maxY));
        }


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
