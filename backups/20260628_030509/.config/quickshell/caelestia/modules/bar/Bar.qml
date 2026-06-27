pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

GridLayout {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    readonly property real spacing: isHorizontal ? columnSpacing : rowSpacing

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const loader = repeater.itemAt(i) as WrappedLoader;
            if (loader?.enabled && loader.id === "tray") {
                (loader.item as Tray).expanded = false;
            }
        }
    }

    function checkPopout(pos: real): void {
        const ch = childAt(isHorizontal ? pos : width / 2, isHorizontal ? height / 2 : pos) as WrappedLoader;

        if (ch?.id !== "tray")
            closeTray();

        if (!ch) {
            if (popouts.hasCurrent && (popouts.currentName === "dockcontext" || popouts.currentName === "dockhover" || popouts.currentName === "activewindow")) return;
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const top = isHorizontal ? ch.x : ch.y;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = items.childAt(isHorizontal ? mapToItem(items, pos, 0).x : items.width / 2, isHorizontal ? items.height / 2 : mapToItem(items, 0, pos).y);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = isHorizontal ? icon.mapToItem(null, icon.implicitWidth / 2, 0).x : icon.mapToItem(null, 0, icon.implicitHeight / 2).y;
                popouts.hasCurrent = true;
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "tray" && Config.bar.popouts.tray && !visibilities.sidebar) {
            const tray = ch.item as Tray;
            const mouseMap = mapToItem(tray.expandIcon, isHorizontal ? pos : tray.implicitWidth / 2, isHorizontal ? tray.implicitHeight / 2 : pos);
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mouseMap))) {
                const traySize = isHorizontal ? tray.layout.implicitWidth : tray.layout.implicitHeight;
                const index = Math.floor(((pos - top - tray.padding * 2 + tray.spacing) / traySize) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = isHorizontal ? trayItem.mapToItem(null, trayItem.implicitWidth / 2, 0).x : trayItem.mapToItem(null, 0, trayItem.implicitHeight / 2).y;
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - (isHorizontal ? ch.x : ch.y);
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = id.toLowerCase();
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "dock") {
            if (popouts.hasCurrent && (popouts.currentName === "dockcontext" || popouts.currentName === "activewindow")) return;
            
            const item = ch.item;
            if (item && typeof item.handleHover === "function") {
                const relPos = pos - (isHorizontal ? ch.x : ch.y);
                item.handleHover(relPos, isHorizontal, popouts);
                return;
            }
            popouts.hasCurrent = false;
        } else if (id === "github") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - (isHorizontal ? ch.x : ch.y);
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = "github";
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = childAt(isHorizontal ? pos : width / 2, isHorizontal ? height / 2 : pos) as WrappedLoader;
        
        if (ch?.id === "dock") {
            const relPos = pos - (isHorizontal ? ch.x : ch.y);
            const dockHit = ch.item ? ch.item.childAt(isHorizontal ? relPos : ch.width / 2, isHorizontal ? ch.height / 2 : relPos) : null;
            if (dockHit) return;
        }

        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if ((isHorizontal ? pos < screen.width / 2 : pos < screen.height / 2) && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    columns: isHorizontal ? -1 : 1
    rows: isHorizontal ? 1 : -1
    flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom

    columnSpacing: Tokens.spacing.medium
    rowSpacing: Tokens.spacing.medium
    
    clip: true

    Repeater {
        id: repeater

        model: Config.bar.entries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    size: {
                        let entries = Config.bar.entries;
                        return (entries && entries[index] && entries[index].size !== undefined) ? entries[index].size : undefined;
                    }
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    sourceComponent: OsIcon {}
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    Layout.fillWidth: root.isHorizontal
                    Layout.fillHeight: !root.isHorizontal
                    sourceComponent: Workspaces {
                        bar: root
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "dock"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    Layout.fillWidth: root.isHorizontal
                    Layout.fillHeight: !root.isHorizontal
                    sourceComponent: Dock {
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    Layout.fillWidth: true
                    visible: !root.fullscreen
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: Clock {}
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: StatusIcons {}
                }
            }
            DelegateChoice {
                roleValue: "github"
                delegate: WrappedLoader {
                    visible: enabled && !root.fullscreen && GithubStore.available
                    sourceComponent: GithubActivity {
                        popouts: root.popouts
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
        }
    }

    component WrappedLoader: Loader {
        required enabled
        required property string id
        required property int index
        property var size

        function findFirstEnabled(): Item {
            const count = repeater.count;
            for (let i = 0; i < count; i++) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        function findLastEnabled(): Item {
            for (let i = repeater.count - 1; i >= 0; i--) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        asynchronous: false
        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter

        Layout.leftMargin: (root.isHorizontal && findFirstEnabled() === this) ? root.vPadding : 0
        Layout.rightMargin: (root.isHorizontal && findLastEnabled() === this) ? root.vPadding : 0
        Layout.topMargin: (!root.isHorizontal && findFirstEnabled() === this) ? root.vPadding : 0
        Layout.bottomMargin: (!root.isHorizontal && findLastEnabled() === this) ? root.vPadding : 0

        property bool isFlexible: (id === "spacer" && size === undefined) || id === "dock"
        Layout.fillWidth: root.isHorizontal ? isFlexible : false
        Layout.fillHeight: !root.isHorizontal ? isFlexible : false
        
        Layout.preferredWidth: root.isHorizontal ? (isFlexible ? -1 : (id === "spacer" && size !== undefined ? size : implicitWidth)) : implicitWidth
        Layout.preferredHeight: !root.isHorizontal ? (isFlexible ? -1 : (id === "spacer" && size !== undefined ? size : implicitHeight)) : implicitHeight
        
        Layout.maximumWidth: root.isHorizontal ? (isFlexible ? -1 : (id === "spacer" && size !== undefined ? size : implicitWidth)) : implicitWidth
        Layout.maximumHeight: !root.isHorizontal ? (isFlexible ? -1 : (id === "spacer" && size !== undefined ? size : implicitHeight)) : implicitHeight
        
        Layout.minimumWidth: root.isHorizontal ? (isFlexible ? 0 : (id === "spacer" && size !== undefined ? size : implicitWidth)) : implicitWidth
        Layout.minimumHeight: !root.isHorizontal ? (isFlexible ? 0 : (id === "spacer" && size !== undefined ? size : implicitHeight)) : implicitHeight

        visible: enabled
        active: enabled

        Component.onCompleted: {
            if (id === "spacer") {
                console.log("Spacer loaded with size:", size, "isFlexible:", isFlexible, "preferredWidth:", Layout.preferredWidth);
            }
        }
    }
}
