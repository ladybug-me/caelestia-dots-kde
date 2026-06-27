pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var keybinds: []
    property bool initialized: false

    property Process reader: Process {
        running: false
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const binds = JSON.parse(text);
                    const formattedBinds = [];

                    for (const b of binds) {
                        const action = b.dispatcher ? (b.dispatcher + (b.arg ? " " + b.arg : "")) : (b.command || "");
                        const description = b.description ? b.description : action;
                        
                        let mods = [];
                        const m = b.modmask;
                        if (m & 64) mods.push("Super");
                        if (m & 8) mods.push("Alt");
                        if (m & 4) mods.push("Ctrl");
                        if (m & 1) mods.push("Shift");
                        
                        let keyText = b.key;
                        if (keyText === "") {
                            if (b.catch_all) {
                                keyText = "Catchall";
                            } else {
                                continue;
                            }
                        }

                        let bindText = mods.join(" + ");
                        if (bindText !== "") bindText += " + ";
                        bindText += keyText;

                        formattedBinds.push({
                            bind: bindText,
                            action: action,
                            description: description
                        });
                    }
                    
                    keybinds = formattedBinds;
                    initialized = true;
                    root.loaded();
                } catch (e) {
                    console.error("Failed to parse hyprctl binds -j: " + e);
                }
            }
        }
    }

    signal loaded

    function loadKeybinds() {
        if (initialized && keybinds.length > 0) {
            return;
        }
        keybinds = [];
        initialized = false;
        reader.running = true;
    }

    function query(searchText) {
        if (!searchText)
            return keybinds;

        const queryText = searchText.toLowerCase();
        return keybinds.filter(k => k.bind.toLowerCase().includes(queryText) || k.description.toLowerCase().includes(queryText));
    }

    Component.onCompleted: loadKeybinds()
}