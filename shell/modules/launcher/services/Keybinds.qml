pragma Singleton

import QtQuick
import Caelestia.Services

QtObject {
    id: root

    readonly property bool initialized: true

    signal loaded

    function loadKeybinds() {
        // KeybindsModel is initialized synchronously in C++
        root.loaded();
    }

    function query(searchText) {
        return KeybindsModel.query(searchText);
    }

    property Connections _conn: Connections {
        target: KeybindsModel
        function onKeybindsChanged(): void { root.loaded(); }
    }

    Component.onCompleted: loadKeybinds()
}