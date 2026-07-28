import QtQuick
import Quickshell
import Quickshell.Hyprland as Hypr
import Caelestia.Services as Caelestia

Loader {
    id: root

    property string name: ""
    property string description: ""
    property string key: ""

    signal pressed()
    signal released()

    active: true

    // Report to the keybind cheatsheet directly. Doing it here means a
    // shortcut whose name or key comes from a variable, ternary or template
    // literal is listed exactly like one written as a plain string.
    function publishKeybind(): void {
        Caelestia.KeybindsModel.registerKeybind(root, root.name, root.key, root.description);
    }

    onNameChanged: publishKeybind()
    onKeyChanged: publishKeybind()
    onDescriptionChanged: publishKeybind()

    Component.onCompleted: publishKeybind()
    Component.onDestruction: Caelestia.KeybindsModel.unregisterKeybind(root)

    sourceComponent: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? hyprShortcut : kdeShortcut

    Component {
        id: hyprShortcut
        Hypr.GlobalShortcut {
            appid: "caelestia"
            name: root.name
            description: root.description
            onPressed: root.pressed()
            onReleased: root.released()
        }
    }

    Component {
        id: kdeShortcut
        Caelestia.GlobalShortcut {
            name: root.name
            key: root.key
            description: root.description
            onActivated: {
                root.pressed()
                root.released()
            }
        }
    }
}
