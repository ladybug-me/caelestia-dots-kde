pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

// How the shell starts other people's applications.
//
// Spawning them as plain children hands them the shell's stdio, and the shell
// may have been started detached (`quickshell -d`, `caelestia shell -d`), which
// points stdout and stderr at /dev/null. Vesktop deadlocks when a call starts
// in exactly that state - issue #402, reproducible on its own with
// `vesktop >/dev/null 2>&1`.
//
// So the launch is wrapped in systemd-cat, which execs the application with
// its output on the journal and changes nothing else about how it runs.
//
// Nothing else about it, deliberately. Launching applications as transient
// systemd *services* also fixes this, and additionally gives them the session
// environment and their own unit - but a service's lifetime is tied to its
// main process, and desktop launchers do not survive that. Heroic gets moved
// into KDE's own app-heroic-<pid>.scope as soon as its window appears, which
// empties the unit systemd was watching; systemd then tears the unit down and
// signals whatever is still in the cgroup, which is the game. umu-run dies in
// its signal handler and the game is left on a blank window.
//
// app2unit stays available for anyone who wants the app in its own unit, under
// services.useSystemd. It uses a scope by default, which does not have the
// lifetime problem a service does.
Singleton {
    id: root

    // Set once the probe below has run. Until then launches use the plain
    // command, which is the old behaviour rather than a failure.
    property bool hasSystemdCat: false
    property bool hasApp2Unit: false

    /// Wraps a command so it does not run on the shell's stdio.
    /// Returns the command unchanged when nothing is available to wrap it.
    function wrap(command: list<string>): list<string> {
        if (command.length === 0)
            return command;

        if (GlobalConfig.services.useSystemd && root.hasApp2Unit)
            return ["app2unit", "--", ...command];

        if (root.hasSystemdCat)
            return ["systemd-cat", "--", ...command];

        return command;
    }

    /// Launches a command, detached from the shell.
    function exec(command: list<string>): void {
        if (command.length > 0)
            Quickshell.execDetached(root.wrap(command));
    }

    /// Launches a desktop entry, honouring its working directory and its
    /// request to run in a terminal.
    function launchEntry(entry: DesktopEntry): void {
        if (entry.runInTerminal)
            Quickshell.execDetached({
                command: root.wrap([...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...entry.command]),
                workingDirectory: entry.workingDirectory
            });
        else
            Quickshell.execDetached({
                command: root.wrap(entry.command),
                workingDirectory: entry.workingDirectory
            });
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v systemd-cat >/dev/null 2>&1 && echo cat; command -v app2unit >/dev/null 2>&1 && echo unit"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasSystemdCat = text.includes("cat");
                root.hasApp2Unit = text.includes("unit");
            }
        }
    }
}
