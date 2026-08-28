pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import api 1.0

Item {
    id: pluginLoader

    property var loadedPlugins: []
    property var discovered: []
    
    property bool loadRequested: false
    property bool finalized: false

    property int pendingMeta: 0

    property Settings pluginSettings: Settings {
        category: "Plugins"
        property var disabledPlugins: []
    }

    function setPluginEnabled(name, enable) {
        let disabled = pluginSettings.disabledPlugins || [];
        let index = disabled.indexOf(name);
        if (enable && index > -1) {
            disabled.splice(index, 1);
            pluginSettings.disabledPlugins = disabled;
        } else if (!enable && index === -1) {
            disabled.push(name);
            pluginSettings.disabledPlugins = disabled;
        }
        
        let av = CaelestiaApi.plugins.available;
        for (let i = 0; i < av.count; i++) {
            if (av.get(i).id === name || av.get(i).name === name) {
                av.setProperty(i, "enabled", enable);
            }
        }
    }

    function checkAndFinalize() {
        if (pendingMeta > 0) return;
        if (finalized) return;
        
        finalized = true;
        CaelestiaApi.plugins.available.clear();
        
        // Unload old ones (simplified, we just drop the refs for now)
        for (let j = 0; j < loadedPlugins.length; j++) {
            if (loadedPlugins[j]) loadedPlugins[j].destroy();
        }
        loadedPlugins = [];

        for (let k = 0; k < discovered.length; k++) {
            let meta = discovered[k];
            CaelestiaApi.plugins.available.append(meta);
            
            if (meta.enabled && meta.type === "quickshell") {
                let mainFile = meta.path + "/main.qml";
                let component = Qt.createComponent("file://" + mainFile);
                if (component.status === Component.Ready) {
                    let plugin = component.createObject(pluginLoader);
                    if (plugin !== null) {
                        loadedPlugins.push(plugin);
                        console.log("Successfully loaded plugin from: " + mainFile);
                    } else {
                        console.log("Error creating plugin object from: " + mainFile);
                    }
                } else if (component.status === Component.Error) {
                    console.log("Error compiling plugin component from: " + mainFile + "\n" + component.errorString());
                }
            }
        }
        console.log("Plugins finalized! Discovered count: ", discovered.length);
    }

    function readMetadata(pluginInfo) {
        let metaPath = pluginInfo.path + "/metadata.json";
        pendingMeta++;
        
        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["cat", "${metaPath}"]
                stdout: StdioCollector { id: out }
                onExited: (code) => {
                    if (code === 0) {
                        try {
                            let meta = JSON.parse(out.text);
                            meta.path = "${pluginInfo.path}";
                            meta.source = "${pluginInfo.source}";
                            
                            let disabled = pluginLoader.pluginSettings.disabledPlugins || [];
                            meta.enabled = (disabled.indexOf(meta.id) === -1 && disabled.indexOf(meta.name) === -1);
                            
                            pluginLoader.discovered.push(meta);
                        } catch(e) {
                            console.log("Failed to parse metadata.json for", "${pluginInfo.id}", e);
                        }
                    }
                    pluginLoader.pendingMeta--;
                    pluginLoader.checkAndFinalize();
                    destroy();
                }
            }
        `, pluginLoader, "metaReader_" + pluginInfo.id);
        proc.running = true;
    }

    function loadPlugins(): void {
        loadRequested = true;
        discovered = [];
        finalized = false;
        pendingMeta = 0;
        
        let configHome = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        let script = Quickshell.env("CAELESTIA_LIB_DIR") + "/scripts/list-plugins.sh";
        if (!Quickshell.env("CAELESTIA_LIB_DIR")) {
            // fallback
            script = configHome + "/quickshell/caelestia/scripts/list-plugins.sh";
        }
        
        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "${script}"]
                stdout: StdioCollector { id: out }
                onExited: (code) => {
                    if (code === 0) {
                        try {
                            let list = JSON.parse(out.text);
                            if (list.length === 0) {
                                pluginLoader.checkAndFinalize();
                            }
                            for (let i = 0; i < list.length; i++) {
                                pluginLoader.readMetadata(list[i]);
                            }
                        } catch(e) {
                            console.log("Error parsing plugin list:", e);
                            pluginLoader.checkAndFinalize();
                        }
                    } else {
                        pluginLoader.checkAndFinalize();
                    }
                    destroy();
                }
            }
        `, pluginLoader, "listPluginsProc");
        proc.running = true;
    }
    
    function reloadPlugins() {
        loadPlugins();
    }
}
