pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Services
import qs.components.misc
import qs.services

Scope {
    id: root

    property alias lock: lock
    readonly property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property bool kdeLocked: false

    function requestLock(): void {
        if (root.isHyprland)
            lock.locked = true;
        else {
            root.kdeLocked = true;
            Quickshell.execDetached(["loginctl", "lock-session"]);
        }
    }

    function requestUnlock(): void {
        if (root.isHyprland)
            lock.unlock();
        else {
            root.kdeLocked = false;
            Quickshell.execDetached(["loginctl", "unlock-session"]);
        }
    }

    WlSessionLock {
        id: lock

        signal unlock

        onUnlock: Audio.playUnlock()

        onLockedChanged: {
            // Nothing needed here anymore since we play sounds explicitly
        }

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    Connections {
        function onLockRequested(): void {
            if (!root.isHyprland)
                root.kdeLocked = true;
        }

        function onUnlockRequested(): void {
            if (!root.isHyprland)
                root.kdeLocked = false;
        }

        target: SessionManager
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "unlock"
        description: qsTr("Unlock the current session")
        onPressed: root.requestUnlock()
    }

    IpcHandler {
        function lock(): void {
            console.log("Lock IPC trigger received");
            root.requestLock();
            Audio.playLock();
        }

        function unlock(): void {
            root.requestUnlock();
        }

        function isLocked(): bool {
            return root.isHyprland ? lock.locked : root.kdeLocked;
        }

        target: "lock"
    }

    Timer {
        id: startupLockTimer

        interval: 750
        onTriggered: {
            if (GlobalConfig.lock.lockOnStartup) {
                root.requestLock();
            }
        }
    }

    Process {
        id: startupLockProc

        command: [
            "sh",
            "-c",
            "leader=$(loginctl show-session \"$XDG_SESSION_ID\" -p Leader --value 2>/dev/null); if [ -n \"$leader\" ]; then age=$(ps -o etimes= -p \"$leader\" | tr -d ' '); if [ -n \"$age\" ] && [ \"$age\" -lt 30 ]; then exit 0; else exit 1; fi; else age=$(awk '{print int($1)}' /proc/uptime); if [ -n \"$age\" ] && [ \"$age\" -lt 30 ]; then exit 0; else exit 1; fi; fi"
        ]
        onExited: code => {
            if (code === 0 && GlobalConfig.lock.lockOnStartup) {
                startupLockTimer.start();
            }
        }
    }

    Component.onCompleted: {
        if (GlobalConfig.lock.lockOnStartup) {
            startupLockProc.running = true;
        }
    }
}
