pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.misc
import qs.services
import Caelestia.Config

Scope {
    property alias lock: lock

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

    Loader {
        asynchronous: true
        active: true
        onLoaded: active = false

        // Force a load of a screencopy so the one in the lock works
        // My guess is the ICC backend loads async on first request, which if the lock is
        // the first request it fails to capture (because it's async and the compositor
        // refuses capture when locked)
        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "lock"
        description: "Lock the current session"
        onPressed: {
            lock.locked = true;
            Audio.playLock();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        function lock(): void {
            lock.locked = true;
            Audio.playLock();
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        target: "lock"
    }

    Timer {
        id: startupLockTimer

        interval: 750
        onTriggered: {
            if (GlobalConfig.lock.lockOnStartup) {
                lock.locked = true;
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

