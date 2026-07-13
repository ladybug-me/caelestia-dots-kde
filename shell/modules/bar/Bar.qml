pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import "components/performance"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large
    readonly property real barScale: Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0)
    readonly property int thickness: Math.round(Tokens.sizes.bar.innerWidth * barScale)

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property real leftZoneSize: isHorizontal ? leftLayout.implicitWidth : leftLayout.implicitHeight
    readonly property real middleZoneSize: isHorizontal ? middleLayout.implicitWidth : middleLayout.implicitHeight
    readonly property real rightZoneSize: isHorizontal ? rightLayout.implicitWidth : rightLayout.implicitHeight

    property var leftEntries: {
        let entries = Config.bar.entries || [];
        return entries.filter(e => e.enabled && (!e.zone || e.zone === "left") && e.id !== "spacer");
    }
    property var middleEntries: {
        let entries = Config.bar.entries || [];
        return entries.filter(e => e.enabled && e.zone === "middle" && e.id !== "spacer");
    }
    property var rightEntries: {
        let entries = Config.bar.entries || [];
        return entries.filter(e => e.enabled && e.zone === "right" && e.id !== "spacer");
    }

    function getLoaderAt(x, y) {
        let items = [leftLayout, middleLayout, rightLayout];
        for (let i = 0; i < items.length; i++) {
            let layout = items[i];
            let localPos = mapToItem(layout, x, y);
            if (localPos.x >= 0 && localPos.x <= layout.width && localPos.y >= 0 && localPos.y <= layout.height) {
                let ch = layout.childAt(localPos.x, localPos.y);
                if (ch && ch.hasOwnProperty("id")) return ch; 
            }
        }
        return null;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        let repeaters = [leftRepeater, middleRepeater, rightRepeater];
        for (let r = 0; r < 3; r++) {
            let rep = repeaters[r];
            for (let i = 0; i < rep.count; i++) {
                const loader = rep.itemAt(i) as WrappedLoader;
                if (loader?.enabled && loader.id === "tray") {
                    const tray = loader.item as Tray;
                    if (Config.bar.popouts.tray || !tray.pinned) {
                        tray.expanded = false;
                        tray.pinned = false;
                    }
                }
            }
        }
    }

    function checkPopout(pos: real): void {
        const ch = getLoaderAt(isHorizontal ? pos : width / 2, isHorizontal ? height / 2 : pos) as WrappedLoader;

        if (ch?.id !== "tray")
            closeTray();

        if (!ch) {
            if (popouts.hasCurrent && (popouts.currentName === "dockcontext" || popouts.currentName === "dockhover" || popouts.currentName === "activewindow")) return;
            if (!Config.bar.popouts.tray && popouts.currentName.startsWith("traymenu")) return;
            // skip hover-driven tray recalculation in click mode
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        // top is absolute pos
        let mappedChPos = mapFromItem(ch, 0, 0);
        const top = isHorizontal ? mappedChPos.x : mappedChPos.y;

        if (id === "tray" && !Config.bar.popouts.tray) {
            return;
        } else if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const localPos = isHorizontal ? mapToItem(items, pos, 0).x : mapToItem(items, 0, pos).y;
            let icon = items.childAt(isHorizontal ? localPos : items.width / 2, isHorizontal ? items.height / 2 : localPos);
            if (!icon) {
                // Find nearest visible child by center distance
                let bestDist = 1e9;
                for (let i = 0; i < items.children.length; i++) {
                    const child = items.children[i];
                    if (!child.visible || !child.name) continue;
                    const center = isHorizontal
                        ? child.mapToItem(items, child.width / 2, 0).x
                        : child.mapToItem(items, 0, child.height / 2).y;
                    const dist = Math.abs(localPos - center);
                    if (dist < bestDist) {
                        bestDist = dist;
                        icon = child;
                    }
                }
            }
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
                const relPos = pos - top;
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
                const relPos = pos - top;
                item.handleHover(relPos, isHorizontal, popouts);
                return;
            }
            popouts.hasCurrent = false;
        } else if (id === "github") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
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
        const ch = getLoaderAt(isHorizontal ? pos : width / 2, isHorizontal ? height / 2 : pos) as WrappedLoader;
        
        if (ch?.id === "dock") {
            let mappedChPos = mapFromItem(ch, 0, 0);
            const top = isHorizontal ? mappedChPos.x : mappedChPos.y;
            const relPos = pos - top;
            const dockHit = ch.item ? ch.item.childAt(isHorizontal ? relPos : ch.width / 2, isHorizontal ? ch.height / 2 : relPos) : null;
            if (dockHit) return;
        }

        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if ((isHorizontal ? pos < screen.width / 2 : pos < screen.height / 2) && Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    clip: true

    GridLayout {
        id: leftLayout
        anchors.left: isHorizontal ? parent.left : undefined
        anchors.top: !isHorizontal ? parent.top : undefined
        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: !isHorizontal ? parent.horizontalCenter : undefined
        
        anchors.leftMargin: isHorizontal ? root.vPadding : 0
        anchors.topMargin: !isHorizontal ? root.vPadding : 0

        columns: isHorizontal ? -1 : 1
        rows: isHorizontal ? 1 : -1
        flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.medium

        Repeater {
            id: leftRepeater
            model: root.leftEntries
            delegate: barDelegate
        }
    }

    GridLayout {
        id: middleLayout

        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: !isHorizontal ? parent.horizontalCenter : undefined

        property real idealX: (parent.width - width) / 2
        property real minX: leftLayout.x + leftLayout.width + Tokens.spacing.medium
        property real maxX: rightLayout.x - width - Tokens.spacing.medium
        x: isHorizontal ? Math.max(minX, Math.min(idealX, maxX)) : undefined

        property real idealY: (parent.height - height) / 2
        property real minY: leftLayout.y + leftLayout.height + Tokens.spacing.medium
        property real maxY: rightLayout.y - height - Tokens.spacing.medium
        y: !isHorizontal ? Math.max(minY, Math.min(idealY, maxY)) : undefined

        columns: isHorizontal ? -1 : 1
        rows: isHorizontal ? 1 : -1
        flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.medium

        Repeater {
            id: middleRepeater
            model: root.middleEntries
            delegate: barDelegate
        }
    }

    GridLayout {
        id: rightLayout
        anchors.right: isHorizontal ? parent.right : undefined
        anchors.bottom: !isHorizontal ? parent.bottom : undefined
        anchors.verticalCenter: isHorizontal ? parent.verticalCenter : undefined
        anchors.horizontalCenter: !isHorizontal ? parent.horizontalCenter : undefined
        
        anchors.rightMargin: isHorizontal ? root.vPadding : 0
        anchors.bottomMargin: !isHorizontal ? root.vPadding : 0

        columns: isHorizontal ? -1 : 1
        rows: isHorizontal ? 1 : -1
        flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
        columnSpacing: Tokens.spacing.medium
        rowSpacing: Tokens.spacing.medium

        Repeater {
            id: rightRepeater
            model: root.rightEntries
            delegate: barDelegate
        }
    }

    DelegateChooser {
        id: barDelegate
        role: "id"

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
                    sourceComponent: Dock {
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
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
                    sourceComponent: Tray {
                        popouts: root.popouts
                    }
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
                roleValue: "kbLayoutIndicator"
                delegate: WrappedLoader {
                    visible: !root.fullscreen && (Hypr.kbLayout || "").length > 0
                    sourceComponent: KbLayoutIndicator {}
                }
            }
            DelegateChoice {
                roleValue: "notificationsIndicator"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: NotificationsIndicator {}
                }
            }
            DelegateChoice {
                roleValue: "perfCpu"
                delegate: WrappedLoader {
                    visible: !root.fullscreen && Cpu.name.length > 0
                    sourceComponent: PerfCpu {}
                }
            }
            DelegateChoice {
                roleValue: "perfMemory"
                delegate: WrappedLoader {
                    visible: !root.fullscreen && Memory.total > 1
                    sourceComponent: PerfMemory {}
                }
            }
            DelegateChoice {
                roleValue: "perfStorage"
                delegate: WrappedLoader {
                    visible: !root.fullscreen && Storage.disks.length > 0
                    sourceComponent: PerfStorage {}
                }
            }
            DelegateChoice {
                roleValue: "perfNetwork"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: PerfNetwork {}
                }
            }
            DelegateChoice {
                roleValue: "perfGpu"
                delegate: WrappedLoader {
                    visible: !root.fullscreen && Gpu.type !== Gpu.None
                    sourceComponent: PerfGpu {}
                }
            }
            DelegateChoice {
                roleValue: "perfBattery"
                delegate: WrappedLoader {
                    visible: !root.fullscreen && UPower.displayDevice.isLaptopBattery
                    sourceComponent: PerfBattery {}
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

    component WrappedLoader: Loader {
        required enabled
        required property string id
        required property int index

        asynchronous: false
        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter

        
        
        
        
        
        
        

        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.maximumWidth: implicitWidth
        Layout.maximumHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight

        visible: enabled
        active: enabled
    }
}
