import QtQuick
import Quickshell
import Quickshell.Hyprland

Loader {
    id: root

    property string name: ""
    property string description: ""

    signal pressed()
    signal released()

    active: true

    sourceComponent: GlobalShortcut {
        appid: "caelestia"
        name: root.name
        description: root.description
        onPressed: root.pressed()
        onReleased: root.released()
    }
}
