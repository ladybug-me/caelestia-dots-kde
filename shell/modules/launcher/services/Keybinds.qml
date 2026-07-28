pragma Singleton

import QtQuick
import Caelestia.Services

QtObject {
    id: root

    readonly property var keybinds: KeybindsModel.keybinds
    readonly property bool initialized: KeybindsModel.initialized

    signal loaded

    function loadKeybinds() {
        if (KeybindsModel.initialized && KeybindsModel.keybinds.length > 0) {
            return;
        }
        KeybindsModel.load();
    }

    function query(searchText) {
        let results = KeybindsModel.query(searchText);
        results = results.filter(item => item.bind && item.bind !== "");
        results.sort((a, b) => {
            let strA = (a.description || a.name || "").toLowerCase();
            let strB = (b.description || b.name || "").toLowerCase();
            return strA.localeCompare(strB);
        });
        return results;
    }

    property Connections _conn: Connections {
        target: KeybindsModel
        function onLoaded(): void { root.loaded(); }
    }

    Component.onCompleted: loadKeybinds()
}