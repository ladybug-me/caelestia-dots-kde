pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether EasyEffects is running, and a way to start or stop it.
//
// EasyEffects has no D-Bus surface worth talking to for this, so it is the
// process itself that is the state: running means the effects chain is applied
// to the audio graph, not running means it is not. Both the native package and
// the Flatpak are checked, because either can be the one installed.
Singleton {
    id: root

    /// Whether EasyEffects is installed at all. Toggles hide themselves when not.
    property bool available: false
    property bool active: false

    function refresh(): void {
        activeProc.running = true;
    }

    function enable(): void {
        Quickshell.execDetached(["bash", "-c",
            "easyeffects --hide-window --service-mode >/dev/null 2>&1 || "
            + "flatpak run com.github.wwmm.easyeffects --hide-window --service-mode >/dev/null 2>&1"]);
        confirmTimer.restart();
    }

    function disable(): void {
        Quickshell.execDetached(["bash", "-c",
            "pkill -x easyeffects >/dev/null 2>&1 || "
            + "flatpak kill com.github.wwmm.easyeffects >/dev/null 2>&1"]);
        confirmTimer.restart();
    }

    /// Opens the EasyEffects window, where its presets and the effect chain are
    /// configured -- the toggle only starts and stops it.
    ///
    /// It quits first rather than just launching. EasyEffects is single
    /// instance, so a second launch reaches the running one and exits, and an
    /// instance started with --hide-window stays hidden when it does: measured
    /// on 8.2.8, a plain launch returns 0 and no window ever appears. Quitting
    /// and starting again without that flag is what actually puts it on screen.
    ///
    /// The cost is a moment without effects while it restarts. That is worth
    /// naming, but a right click that silently does nothing is worse, and the
    /// windowed instance goes on applying the same chain once it is up.
    function open(): void {
        Quickshell.execDetached(["bash", "-c",
            "easyeffects -q >/dev/null 2>&1; flatpak kill com.github.wwmm.easyeffects >/dev/null 2>&1; "
            + "easyeffects >/dev/null 2>&1 || flatpak run com.github.wwmm.easyeffects >/dev/null 2>&1"]);
        confirmTimer.restart();
    }

    function toggle(): void {
        if (root.active)
            root.disable();
        else
            root.enable();
    }

    Process {
        id: availableProc

        command: ["bash", "-c",
            "command -v easyeffects >/dev/null 2>&1 || flatpak info com.github.wwmm.easyeffects >/dev/null 2>&1"]
        running: true
        onExited: code => {
            root.available = code === 0;
            if (root.available)
                root.refresh();
        }
    }
    Process {
        id: activeProc

        command: ["bash", "-c",
            "pidof -q easyeffects || flatpak ps --columns=application 2>/dev/null | grep -qx com.github.wwmm.easyeffects"]
        onExited: code => root.active = code === 0
    }
    // Starting and stopping are fire-and-forget, so the state is read back
    // rather than assumed: a launch that fails, or a stop that does not take,
    // would otherwise leave the toggle showing something that is not true.
    Timer {
        id: confirmTimer

        interval: 1200
        onTriggered: root.refresh()
    }
}
