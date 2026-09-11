pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

/**
 * Stops kde-material-you-colors when it gets stuck re-applying the Plasma
 * colour scheme.
 *
 * KMY can decide on every loop that something changed and re-apply the scheme
 * each main_loop_delay (one second by default) even though the palette is
 * identical. Every apply spawns plasma-apply-colorscheme, rewrites kdeglobals
 * and makes every window repaint - KWin decorations, plasmashell, this shell,
 * GTK apps. On screen that reads as the display flashing, the shell stalling
 * for about a second, and the colours breaking on a roughly one second rhythm.
 *
 * Restarting KMY clears the stuck state, so that is what happens first. If a
 * storm comes back after a restart, KMY is paused through its own pause_mode
 * setting instead, which stops it without losing the scheme it already applied.
 *
 * The applies are attributed before anything is touched: only
 * plasma-apply-colorscheme processes whose parent is a kde-material process
 * count, so a user or another tool applying a scheme is never mistaken for KMY.
 */
Singleton {
    id: root

    // Timestamps of the applies counted inside the current window.
    property var applies: []

    // Last time KMY was restarted, and whether an action is already in flight.
    property double restartedAt: 0

    property bool acting: false

    // Eight applies inside ten seconds. The storm that caused this ran at
    // about one apply a second; changing a wallpaper or theme applies a
    // handful and then stops.
    readonly property int windowMs: 10000

    readonly property int stormSamples: 8

    // A storm this soon after a restart means the restart did not help.
    readonly property int escalateWindowMs: 600000

    // One long-lived child so the watcher costs nothing on the QML thread. An
    // apply is counted once, by remembering its pid, rather than once per poll:
    // otherwise a slow apply counts several times and a fast one not at all.
    // The bracket in the pattern keeps pgrep from matching this command itself.
    readonly property var watchScript: [
        "last=",
        "while :; do",
        "  p=$(pgrep -f 'plasma-apply-colorschem[e]' | head -n1)",
        "  if [ -n \"$p\" ] && [ \"$p\" != \"$last\" ]; then",
        "    last=$p",
        "    pp=$(ps -o ppid= -p \"$p\" 2>/dev/null | tr -d ' ')",
        "    case \"$(cat /proc/$pp/comm 2>/dev/null)\" in",
        "      kde-material*) echo apply ;;",
        "    esac",
        "  fi",
        "  sleep 0.25",
        "done"
    ]

    function noteApply(): void {
        if (acting)
            return;

        const now = Date.now();
        const recent = [];
        for (const stamp of applies) {
            if (now - stamp < windowMs)
                recent.push(stamp);
        }
        recent.push(now);

        if (recent.length < stormSamples) {
            applies = recent;
            return;
        }

        applies = [];
        contain();
    }

    function contain(): void {
        acting = true;
        if (restartedAt > 0 && Date.now() - restartedAt < escalateWindowMs) {
            pauseProcess.running = true;
            return;
        }
        restartProcess.running = true;
    }

    function report(title: string, message: string, type: var): void {
        console.warn(`KMY guard: ${title} - ${message}`);
        Toaster.toast(title, message, "palette", type);
    }

    Process {
        id: watcher

        running: true
        command: ["sh", "-c", root.watchScript.join("\n")]
        stdout: SplitParser {
            onRead: line => {
                if ((line || "").trim() === "apply")
                    root.noteApply();
            }
        }
    }

    Process {
        id: restartProcess

        command: ["systemctl", "--user", "restart", "kde-material-you-colors"]
        onExited: code => {
            root.acting = false;
            if (code !== 0) {
                root.report(qsTr("Material You colours"), qsTr("kde-material-you-colors is re-applying the colour scheme in a loop and could not be restarted (exit code %1).").arg(code), Toast.Error);
                return;
            }
            root.restartedAt = Date.now();
            root.report(qsTr("Material You colours"), qsTr("kde-material-you-colors was re-applying the colour scheme in a loop, so it was restarted."), Toast.Warning);
        }
    }

    Process {
        id: pauseProcess

        command: ["bash", Quickshell.shellPath("scripts/sync-kmyc.sh"), "--set", "pause_mode", "True"]
        onExited: code => {
            root.acting = false;
            const hint = qsTr("Advanced Colors has the switch that turns it back on, or set pause_mode back to False.");
            if (code !== 0) {
                root.report(qsTr("Material You colours"), qsTr("kde-material-you-colors is still looping and could not be paused (exit code %1).").arg(code), Toast.Error);
                return;
            }
            root.report(qsTr("Material You colours paused"), qsTr("kde-material-you-colors kept re-applying the colour scheme after a restart, so it was paused. %1").arg(hint), Toast.Warning);
        }
    }

    // The watcher is a plain shell loop; put it back if it ever dies.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (!watcher.running)
                watcher.running = true;
        }
    }
}
