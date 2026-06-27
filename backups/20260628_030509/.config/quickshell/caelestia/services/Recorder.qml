pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property bool needsStart
    property list<string> startArgs
    property bool needsStop
    property bool needsPause

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs;
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    function launchSpectacle(): void {
        Quickshell.execDetached(["spectacle", "-R", "r"]);
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0 // Might get too large for int

        reloadableId: "recorder"
    }

    property bool _wasRunning: false

    Process {
        id: checkProc

        command: ["sh", "-c", "pidof gpu-screen-recorder >/dev/null && test -f $HOME/.local/state/caelestia/record/recording.mp4"]
        onExited: code => { // qmllint disable signal-handler-parameters
            let isRunning = (code === 0);

            if (isRunning && !root._wasRunning) {
                props.elapsed = 0;
                props.paused = false;
            }
            
            root._wasRunning = isRunning;
            props.running = isRunning;

            if (isRunning) {
                if (root.needsStop) {
                    Quickshell.execDetached(["caelestia", "record"]);
                } else if (root.needsPause) {
                    Quickshell.execDetached(["caelestia", "record", "-p"]);
                    props.paused = !props.paused;
                }
            } else if (root.needsStart) {
                Quickshell.execDetached(["caelestia", "record", ...root.startArgs]);
            }

            root.needsStart = false;
            root.needsStop = false;
            root.needsPause = false;
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (!checkProc.running) {
                checkProc.running = true;
            }
        }
    }

    Connections {
        // enabled: props.running && !props.paused
        function onSecondsChanged(): void {
            props.elapsed++;
        }

        target: Time // qmllint disable incompatible-type
    }
}
