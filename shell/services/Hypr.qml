pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.Internal
import Caelestia.Services
import qs.components.misc
import qs.services

Singleton {
    id: root

    readonly property var toplevels: ToplevelManager.toplevels
    // Workspaces mock: must support .values (used like a Map/iterable throughout the
    // codebase).  Provide sane defaults so optional-chaining paths do not crash.
    readonly property var workspaces: (() => {
        const ws = {
            "1": { id: 1, name: "1", windows: 0, lastIpcObject: null, monitor: 0,
                   toplevels: { values: [] }, workspace: { id: 1 } }
        };
        ws["1"].lastIpcObject = ws["1"];
        // Inject .values() and .values as both a function and a property for
        // compatibility — the codebase uses both forms.
        ws.values = Object.values(ws).filter(v => typeof v === "object" && v !== null && v.id !== undefined);
        ws.values.find = function(pred) { return Array.prototype.find.call(this, pred); };
        ws.values.filter = function(pred) { return Array.prototype.filter.call(this, pred); };
        ws.values.map = function(pred) { return Array.prototype.map.call(this, pred); };
        ws.values.some = function(pred) { return Array.prototype.some.call(this, pred); };
        return ws;
    })()
    property var monitorState: []
    property var _monitorCache: ({})

    // Referenced by focusedWorkspace/activeWsId below as the single mock
    // workspace id used throughout the KDE fallback bridge (there is no real
    // Hyprland workspace concept under KWin). This property was previously
    // never declared, so every read of root.mockActiveWs resolved to
    // undefined - causing "Cannot call method 'toString' of undefined" and
    // "Unable to assign [undefined] to ..." warnings wherever it was used.
    readonly property int mockActiveWs: 1

    readonly property var monitors: {
        const screens = [...Quickshell.screens];
        const screenNames = screens.map(s => s.name);
        const cachedNames = Object.keys(root._monitorCache).filter(key => key !== "values");
        const topologyChanged = cachedNames.length !== screenNames.length || cachedNames.some(name => !screenNames.includes(name));

        if (topologyChanged) {
            for (const name of cachedNames) {
                if (!screenNames.includes(name))
                    delete root._monitorCache[name];
            }
            for (let i = 0; i < screens.length; i++) {
                const screen = screens[i];
                if (!root._monitorCache[screen.name])
                    root._monitorCache[screen.name] = root.createMonitorMock(screen.name, i);
            }
        }

        for (let i = 0; i < screens.length; i++) {
            const monitor = root._monitorCache[screens[i].name];
            monitor.id = i;
            monitor.focused = i === 0;
        }
        // Inject .values so for-of loops and .some()/.find() on Hypr.monitors work.
        // The codebase expects monitors to behave like a Map/iterable.
        const cache = root._monitorCache;
        const vals = Object.values(cache).filter(v => typeof v === "object" && v !== null);
        cache.values = vals;
        cache.values.find = function(pred) { return Array.prototype.find.call(vals, pred); };
        cache.values.filter = function(pred) { return Array.prototype.filter.call(vals, pred); };
        cache.values.some = function(pred) { return Array.prototype.some.call(vals, pred); };
        cache.values.every = function(pred) { return Array.prototype.every.call(vals, pred); };
        return cache;
    }

    // Native Wayland/DBus state bindings are handled by Caelestia C++ services

    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property var focusedWorkspace: ({ id: root.mockActiveWs, name: root.mockActiveWs.toString() })
    readonly property var focusedMonitor: {
        let _ = root.monitors;

        let targetName = "";
        if (typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.activeOutputName) {
            targetName = KWinActiveWindowBridge.activeOutputName;
        }

        if (targetName !== "") {
            for (let key in root._monitorCache) {
                if (root._monitorCache[key].name === targetName) {
                    return root._monitorCache[key];
                }
            }
        }

        for (let key in root._monitorCache) {
            if (root._monitorCache[key].focused) {
                return root._monitorCache[key];
            }
        }

        let keys = Object.keys(root._monitorCache);
        if (keys.length > 0) return root._monitorCache[keys[0]];
        return null;
    }
    // On KDE, use KWinWorkspaceState.activeId so workspace switches invalidate
    // any binding that reads this property (e.g. ContentWindow.hasFullscreen).
    readonly property int activeWsId: {
        if (typeof KWinWorkspaceState !== "undefined")
            return KWinWorkspaceState.activeId;
        return focusedWorkspace?.id ?? root.mockActiveWs;
    }

    readonly property bool capsLock: CUtils.capsLock
    readonly property bool numLock: CUtils.numLock
    readonly property string defaultKbLayout: ""
    readonly property string kbLayoutFull: KbLayout.activeLabel
    readonly property string kbLayout: KbLayout.activeShortLabel
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property bool hadKeyboard
    property string lastSpecialWorkspace: ""

    signal configReloaded

    function createMonitorMock(name: string, index: int): var {
        const fallback = Qt.createQmlObject(`
            import QtQuick
            QtObject {
                property int id: 0
                property string name: ""
                property bool focused: false
                property real scale: 1.0
                property real x: 0
                property real y: 0
                // activeWorkspace must include toplevels.values for
                // optional-chaining code paths (e.g. hasFullscreen checks)
                property var activeWorkspace: ({ id: 1, toplevels: { values: [] } })
                property var specialWorkspace: ({ name: "", toplevels: { values: [] } })
                property var lastIpcObject: null

                Component.onCompleted: lastIpcObject = this
            }
        `, root, "monitorMock");
        fallback.name = name;
        fallback.id = index;
        fallback.focused = index === 0;
        return fallback;
    }

    function hasFullscreen(): bool {
        if (typeof KWinActiveWindowBridge !== "undefined") {
            const wins = KWinActiveWindowBridge.windowList || [];
            // KWin serialises fullscreen as a boolean, not Hyprland's integer
            // level (0/1/2), so `> 1` is always false. Use === true instead.
            for (let i = 0; i < wins.length; i++) {
                if (wins[i].fullscreen === true)
                    return true;
            }
            return false;
        }
        const monVals = root.monitors.values || [];
        for (let i = 0; i < monVals.length; i++) {
            const toplevels = monVals[i]?.activeWorkspace?.toplevels?.values || [];
            for (let j = 0; j < toplevels.length; j++) {
                if ((toplevels[j]?.lastIpcObject?.fullscreen ?? 0) > 1)
                    return true;
            }
        }
        return false;
    }

    // Per-monitor fullscreen check for multi-monitor setups.
    // On KDE, each window entry carries an `output` field (screen name) and a
    // `workspace.id` that matches KWinWorkspaceState.activeId, so we scope the
    // check to windows on this output AND the currently active workspace.
    // On Hyprland, monitor.activeWorkspace already provides workspace scoping.
    // Falls back to the global check if no screen name is given.
    function hasFullscreenOn(screenName: string): bool {
        if (!screenName)
            return hasFullscreen();
        if (typeof KWinActiveWindowBridge !== "undefined") {
            const wins = KWinActiveWindowBridge.windowList || [];
            const activeWsId = (typeof KWinWorkspaceState !== "undefined")
                ? KWinWorkspaceState.activeId : -1;
            for (let i = 0; i < wins.length; i++) {
                if (!wins[i].fullscreen)
                    continue;
                if (wins[i].output !== screenName)
                    continue;
                // Only count windows on the active workspace (ignore other desktops).
                if (activeWsId !== -1 && wins[i].workspace?.id !== activeWsId)
                    continue;
                return true;
            }
            return false;
        }
        const monVals = root.monitors.values || [];
        for (let i = 0; i < monVals.length; i++) {
            const mon = monVals[i];
            if (mon?.lastIpcObject?.name !== screenName)
                continue;
            // activeWorkspace already scopes to the current workspace on Hyprland.
            const toplevels = mon?.activeWorkspace?.toplevels?.values || [];
            for (let j = 0; j < toplevels.length; j++) {
                if ((toplevels[j]?.lastIpcObject?.fullscreen ?? 0) > 1)
                    return true;
            }
        }
        return false;
    }

    // Whether any window on `screenName` overlaps the given rect, which is in
    // the same absolute multi-monitor coordinates KWin reports geometry in.
    //
    // Used by the bar's dodge mode. Minimized windows are skipped, and so are
    // windows on other virtual desktops — a window you cannot see should not
    // push the bar away. Returns false off KDE: the Hyprland path has no
    // equivalent window list here, and reporting "nothing overlaps" leaves the
    // bar visible rather than stuck hidden.
    function hasWindowOverlapping(screenName: string, x: real, y: real, width: real, height: real, focusedOnly: bool): bool {
        if (typeof KWinActiveWindowBridge === "undefined")
            return false;

        const wins = KWinActiveWindowBridge.windowList || [];
        const activeWsId = (typeof KWinWorkspaceState !== "undefined") ? KWinWorkspaceState.activeId : -1;
        const activeAddr = focusedOnly ? String(KWinActiveWindowBridge.activeWindow?.address ?? "") : "";

        // Nothing focused means nothing to dodge, rather than everything.
        if (focusedOnly && !activeAddr)
            return false;

        for (let i = 0; i < wins.length; i++) {
            const win = wins[i];
            if (win.minimized === true)
                continue;
            if (focusedOnly && String(win.address) !== activeAddr)
                continue;
            if (screenName && win.output !== screenName)
                continue;
            if (activeWsId !== -1 && win.workspace?.id !== activeWsId)
                continue;
            // Touching edges are not an overlap, hence the strict comparisons.
            if (win.x < x + width && win.x + win.width > x && win.y < y + height && win.y + win.height > y)
                return true;
        }
        return false;
    }

    function dispatch(request: string): void {
        const isKDE = typeof KWinActiveWindowBridge !== "undefined";

        // ── workspace (absolute) ──────────────────────────────────────
        if (request.startsWith("workspace ")) {
            const ws = request.split(" ").slice(1).join(" ");
            if (isKDE) {
                // Relative workspace scrolling: "r+1" / "r-1"
                if (/^r[+-]\d+$/.test(ws)) {
                    if (ws.charAt(1) === "+") {
                        KWinWorkspaceState.nextDesktop();
                    } else {
                        KWinWorkspaceState.previousDesktop();
                    }
                } else {
                    KWinWorkspaceState.switchTo(ws);
                }
            }
            return;
        }

        // ── focuswindow address:0x<hex> ───────────────────────────────
        if (request.startsWith("focuswindow address:0x")) {
            if (isKDE) {
                const prefix = "focuswindow address:0x";
                KWinActiveWindowBridge.focusWindow(request.slice(prefix.length).trim());
            }
            return;
        }

        // ── closewindow address:0x<hex> ───────────────────────────────
        if (request.startsWith("closewindow address:0x")) {
            if (isKDE) {
                const prefix = "closewindow address:0x";
                KWinActiveWindowBridge.closeWindow(request.slice(prefix.length).trim());
            }
            return;
        }

        // ── movetoworkspace <id>,address:0x<hex> ─────────────────────
        const moveMatch = request.match(/^movetoworkspace\s+(\S+),address:0x/);
        if (moveMatch) {
            if (isKDE) {
                const desktopId = parseInt(moveMatch[1], 10);
                const addr = request.slice(moveMatch[0].length).trim();
                if (!isNaN(desktopId))
                    KWinActiveWindowBridge.setWindowDesktop(addr, desktopId);
            }
            return;
        }

        // ── dpms off / dpms on ───────────────────────────────────────
        if (request === "dpms off" || request === "dpms on") {
            if (isKDE) {
                const method = (request === "dpms on") ? "turnOn" : "turnOff";
                Quickshell.execDetached([
                    "qdbus6", "org.kde.Solid.PowerManagement",
                    "/org/kde/Solid/PowerManagement/Actions/DPMSControl",
                    "org.kde.Solid.PowerManagement.Actions.DPMSControl." + method
                ]);
            }
            return;
        }

        // ── togglespecialworkspace ────────────────────────────────────
        // KDE has no special/scratchpad workspace concept; log and ignore.
        if (request.startsWith("togglespecialworkspace")) {
            if (!isKDE) {
                // On actual Hyprland this would be handled by the IPC, but
                // we no longer have a socket — log for visibility.
                console.log("Hypr.dispatch: special workspace toggle not supported on KDE");
            }
            return;
        }

        // ── unrecognised ──────────────────────────────────────────────
        console.log("Hypr.dispatch: unhandled request: " + request);
    }

    function cycleSpecialWorkspace(direction: string): void {
        const openSpecials = workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0);

        if (openSpecials.length === 0)
            return;

        const activeSpecial = focusedMonitor.lastIpcObject.specialWorkspace.name ?? "";

        if (!activeSpecial) {
            if (lastSpecialWorkspace) {
                const workspace = workspaces.values.find(w => w.name === lastSpecialWorkspace);
                if (workspace && workspace.lastIpcObject.windows > 0) {
                    dispatch(usingLua ? `hl.dsp.focus({ workspace = "${lastSpecialWorkspace}" })` : `workspace ${lastSpecialWorkspace}`);
                    return;
                }
            }
            dispatch(usingLua ? `hl.dsp.focus({ workspace = "${openSpecials[0].name}" })` : `workspace ${openSpecials[0].name}`);
            return;
        }

        const currentIndex = openSpecials.findIndex(w => w.name === activeSpecial);
        let nextIndex = 0;

        if (currentIndex !== -1) {
            if (direction === "next")
                nextIndex = (currentIndex + 1) % openSpecials.length;
            else
                nextIndex = (currentIndex - 1 + openSpecials.length) % openSpecials.length;
        }

        dispatch(usingLua ? `hl.dsp.focus({ workspace = "${openSpecials[nextIndex].name}" })` : `workspace ${openSpecials[nextIndex].name}`);
    }

    function monitorNames(): list<string> {
        let names = [];
        for (let key in root.monitors) {
            names.push(root.monitors[key].name);
        }
        return names;
    }

    function monitorFor(screen: ShellScreen): var {
        const monitors = root.monitors;
        const cache = monitors;
        let cached = root._monitorCache[screen.name];
        if (!cached) {
            cached = root.createMonitorMock(screen.name, Object.keys(cache).filter(key => key !== "values").length);
            root._monitorCache[screen.name] = cached;
        }
        return cached;
    }

    function reloadDynamicConfs(): void {}

    Component.onCompleted: reloadDynamicConfs()

    onCapsLockChanged: {
        if (!GlobalConfig.utilities.toasts.capsLockChanged)
            return;

        if (capsLock)
            Toaster.toast(qsTr("Caps lock enabled"), qsTr("Caps lock is currently enabled"), "keyboard_capslock_badge");
        else
            Toaster.toast(qsTr("Caps lock disabled"), qsTr("Caps lock is currently disabled"), "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!GlobalConfig.utilities.toasts.numLockChanged)
            return;

        if (numLock)
            Toaster.toast(qsTr("Num lock enabled"), qsTr("Num lock is currently enabled"), "looks_one");
        else
            Toaster.toast(qsTr("Num lock disabled"), qsTr("Num lock is currently disabled"), "timer_1");
    }

    onKbLayoutFullChanged: {
        if (hadKeyboard && GlobalConfig.utilities.toasts.kbLayoutChanged)
            Toaster.toast(qsTr("Keyboard layout changed"), qsTr("Layout changed to: %1").arg(kbLayoutFull), "keyboard");

        hadKeyboard = kbLayoutFull.length > 0;
    }



    FileView {
        id: kbLayoutFile

        path: Quickshell.env("CAELESTIA_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                const lines = layoutMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                const lines = variantMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
        }
    }

    IpcHandler {
        function refreshDevices(): void {
            extras.refreshDevices();
        }

        function cycleSpecialWorkspace(direction: string): void {
            root.cycleSpecialWorkspace(direction);
        }

        function listSpecialWorkspaces(): string {
            return root.workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0).map(w => w.name).join("\n");
        }

        function getFocusedMonitor(): string {
            let m = root.focusedMonitor;
            if (!m) return "null";
            return JSON.stringify({
                id: m.id,
                name: m.name,
                focused: m.focused,
                activeWorkspace: m.activeWorkspace,
                specialWorkspace: m.specialWorkspace
            }, null, 2);
        }

        function listMonitors(): string {
            return root.monitorNames().join(", ");
        }

        target: "hypr"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "refreshDevices"
        description: "Reload devices"
        onPressed: extras.refreshDevices()
        onReleased: extras.refreshDevices()
    }

    HyprExtras {
        id: extras

        usingLua: false
    }
}
