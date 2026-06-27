pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Internal
import qs.components.misc

Singleton {
    id: root

    readonly property var toplevels: ToplevelManager.toplevels
    readonly property var workspaces: ({ "1": { id: 1, name: "1", windows: 1 } })
    readonly property var monitors: ({ "0": { id: 0, name: "DP-1" } })
    readonly property bool usingLua: false

    property int mockActiveWs: 1
    
    Process {
        id: wsPoller
        command: ["bash", "-c", "qdbus6 org.kde.KWin /KWin org.kde.KWin.currentDesktop"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const num = parseInt(text);
                if (!isNaN(num) && num > 0) root.mockActiveWs = num;
                wsTimer.start();
            }
        }
    }
    
    Timer {
        id: wsTimer
        interval: 1000
        onTriggered: wsPoller.running = true
    }

    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property var focusedWorkspace: ({ id: root.mockActiveWs, name: root.mockActiveWs.toString() })
    readonly property var focusedMonitor: ({ name: "DP-1" })
    readonly property int activeWsId: focusedWorkspace?.id ?? root.mockActiveWs

    readonly property bool capsLock: false
    readonly property bool numLock: false
    readonly property string defaultKbLayout: "??"
    readonly property string kbLayoutFull: "Unknown"
    readonly property string kbLayout: "??"
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property bool hadKeyboard
    property string lastSpecialWorkspace: ""

    signal configReloaded

    function dispatch(request: string): void {
        if (request.startsWith("workspace ")) {
            const ws = request.split(" ")[1];
            Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/KWin", "setCurrentDesktop", ws]);
            return;
        }
        Quickshell.execDetached(["hyprctl", "dispatch", ...request.split(" ")]);
    }

    function cycleSpecialWorkspace(direction: string): void {
        const openSpecials = workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0);

        if (openSpecials.length === 0)
            return;
        Quickshell.execDetached(["hyprctl", "dispatch", ...request.split(" ")]);

        const activeSpecial = focusedMonitor.lastIpcObject.specialWorkspace.name ?? "";

        if (!activeSpecial) {
            if (lastSpecialWorkspace) {
                const workspace = workspaces.values.find(w => w.name === lastSpecialWorkspace);
                if (workspace && workspace.lastIpcObject.windows > 0) {
                    dispatch(usingLua ? `hl.dsp.focus({ workspace = "${lastSpecialWorkspace}" })` : `workspace ${lastSpecialWorkspace}`);
                    return;
        Quickshell.execDetached(["hyprctl", "dispatch", ...request.split(" ")]);
                }
            }
            dispatch(usingLua ? `hl.dsp.focus({ workspace = "${openSpecials[0].name}" })` : `workspace ${openSpecials[0].name}`);
            return;
        Quickshell.execDetached(["hyprctl", "dispatch", ...request.split(" ")]);
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
        return ["DP-1"];
    }

    function monitorFor(screen: ShellScreen): var {
        return null;
    }

    function reloadDynamicConfs(): void {}

    Component.onCompleted: reloadDynamicConfs()

    onCapsLockChanged: {
        if (!GlobalConfig.utilities.toasts.capsLockChanged)
            return;
        Quickshell.execDetached(["hyprctl", "dispatch", ...request.split(" ")]);

        if (capsLock)
            Toaster.toast(qsTr("Caps lock enabled"), qsTr("Caps lock is currently enabled"), "keyboard_capslock_badge");
        else
            Toaster.toast(qsTr("Caps lock disabled"), qsTr("Caps lock is currently disabled"), "keyboard_capslock");
    }

    onNumLockChanged: {
        if (!GlobalConfig.utilities.toasts.numLockChanged)
            return;
        Quickshell.execDetached(["hyprctl", "dispatch", ...request.split(" ")]);

        if (numLock)
            Toaster.toast(qsTr("Num lock enabled"), qsTr("Num lock is currently enabled"), "looks_one");
        else
            Toaster.toast(qsTr("Num lock disabled"), qsTr("Num lock is currently disabled"), "timer_1");
    }

    onKbLayoutFullChanged: {
        if (hadKeyboard && GlobalConfig.utilities.toasts.kbLayoutChanged)
            Toaster.toast(qsTr("Keyboard layout changed"), qsTr("Layout changed to: %1").arg(kbLayoutFull), "keyboard");

        hadKeyboard = !!keyboard;
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
