pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia

Singleton {
    id: root

    readonly property alias temperature: props.temperature
    readonly property alias active: props.active
    property bool available: true // We assume it's available or we can check with `which hyprsunset`

    function nightLightToast(message: string): void {
        Toaster.toast(qsTr("Night Light"), qsTr(message), "dark_mode");
    }

    function start(temp): void {
        if (temp !== undefined && temp !== null)
            props.temperature = temp;
        props.active = true;
    }

    function stop(): void {
        props.active = false;
    }

    function toggle(temp): void {
        if (props.active)
            stop();
        else
            start(temp);
    }

    PersistentProperties {
        id: props

        property int temperature: 6000
        property bool active: false

        reloadableId: "hyprSunset"
    }

    Process {
        id: sunsetProc
        command: ["hyprsunset", "--temperature", props.temperature.toString()]
        running: props.active

        stdout: StdioCollector {
            id: out
        }
        stderr: StdioCollector {
            id: err
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0 && props.active) {
                console.error("[HyprSunset] exited with code " + code + ": " + err.text);
                props.active = false; // Turn off if it crashed
            }
        }
    }
}
