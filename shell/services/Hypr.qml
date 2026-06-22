pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config

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

    property bool hadKeyboard
    property string lastSpecialWorkspace: ""

    signal configReloaded

    function dispatch(request: string): void {
        if (request.startsWith("workspace ")) {
            const ws = request.split(" ")[1];
            Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/KWin", "setCurrentDesktop", ws]);
            return;
        }
    }

    function cycleSpecialWorkspace(direction: string): void {}
    function monitorNames(): list<string> { return ["DP-1"] }
    function monitorFor(screen: ShellScreen): var { return null }
    function reloadDynamicConfs(): void {}
}
