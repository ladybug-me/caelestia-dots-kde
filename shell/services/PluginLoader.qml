pragma Singleton

import qs.services.api
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Item {
    id: pluginLoader

    // Map of plugin id -> live QML object instance
    property var pluginInstances: ({})

    property var discovered: []
    property bool loadRequested: false
    property bool finalized: false
    property int pendingMeta: 0

    property Settings pluginSettings: Settings {
        property var disabledPlugins: []

        category: "Plugins"
    }

    signal pluginsReloaded()

    function loadPlugin(meta) {
        let id = meta.id || meta.name;
        if (pluginInstances[id]) return; // already loaded
        if (meta.type !== "quickshell") return;

        let mainFile = meta.path + "/main.qml";
        let component = Qt.createComponent("file://" + mainFile);
        if (component.status === Component.Ready) {
            let obj = component.createObject(pluginLoader);
            if (obj !== null) {
                pluginInstances[id] = obj;
            } else {
                console.log("Plugin createObject failed: " + mainFile);
            }
        } else if (component.status === Component.Error) {
            console.log("Plugin compile error: " + mainFile + "\n" + component.errorString());
        }
    }

    function unloadPlugin(id) {
        if (pluginInstances[id]) {
            pluginInstances[id].destroy();
            delete pluginInstances[id];
            pluginInstances = pluginInstances; // force notify
            console.log("Plugin unloaded: " + id);
        }
    }

    function setPluginEnabled(name, enable) {
        // Must slice() to create a new array instance, otherwise assigning it back
        // to pluginSettings.disabledPlugins won't trigger the QML change signal or save it.
        let disabled = (pluginSettings.disabledPlugins || []).slice();
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
            let item = av.get(i);
            let itemId = item.id || item.name;
            if (itemId === name || item.name === name) {
                av.setProperty(i, "enabled", enable);
                if (enable) {
                    loadPlugin(item);
                } else {
                    unloadPlugin(itemId);
                }
            }
        }
    }

    function checkAndFinalize() {
        if (pendingMeta > 0) return;
        if (finalized) return;

        finalized = true;
        CaelestiaApi.plugins.available.clear();

        // Destroy all currently running plugin instances
        for (let key in pluginInstances) {
            if (pluginInstances[key]) pluginInstances[key].destroy();
        }
        pluginInstances = {};

        for (let k = 0; k < discovered.length; k++) {
            let meta = discovered[k];
            CaelestiaApi.plugins.available.append(meta);

            if (meta.enabled) {
                loadPlugin(meta);
            }
        }
        pluginsReloaded();
    }


    function readMetadata(pluginInfo) {
        let metaPath = pluginInfo.path + "/metadata.json";
        pendingMeta++;
        console.log("readMetadata called for", pluginInfo.id, "at", metaPath);

        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["cat", "${metaPath}"]
                stdout: StdioCollector { id: out }
                stderr: StdioCollector { id: err }
                onExited: (code) => {
                    if (code === 0) {
                        try {
                            let meta = JSON.parse(out.text);
                            meta.path = "${pluginInfo.path}";
                            meta.source = "${pluginInfo.source}";

                            let disabled = pluginLoader.pluginSettings.disabledPlugins || [];
                            meta.enabled = (disabled.indexOf(meta.id) === -1 && disabled.indexOf(meta.name) === -1);
                            meta.settings = meta.settings || [];
                            meta.mediaurl = meta.mediaurl || "";
                            
                            // Extract author information
                            meta.authorName = meta.author ? (meta.author.name || "") : "";
                            let aUrl = meta.author ? (meta.author.url || "") : "";
                            meta.icon = meta.icon || "extension";

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
        let script = configHome + "/quickshell/caelestia/scripts/list-plugins.sh";

        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "${script}"]
                stdout: StdioCollector { id: out }
                stderr: StdioCollector { id: err }
                onExited: (code) => {
                    console.log("listPluginsProc exited with code:", code, "stdout:", out.text, "stderr:", err.text);
                    if (code === 0) {
                        try {
                            let list = JSON.parse(out.text);
                            console.log("Parsed plugin list, length:", list.length);
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

    function removePluginFromAvailable(id) {
        for (let i = 0; i < CaelestiaApi.plugins.available.count; i++) {
            if (CaelestiaApi.plugins.available.get(i).id === id) {
                CaelestiaApi.plugins.available.remove(i);
                pluginsReloaded();
                return;
            }
        }
    }

    function _internalAppendPlugin(meta) {
        let disabled = pluginLoader.pluginSettings.disabledPlugins || [];
        meta.enabled = (disabled.indexOf(meta.id) === -1 && disabled.indexOf(meta.name) === -1);
        meta.settings = meta.settings || [];
        meta.mediaurl = meta.mediaurl || "";

        // Extract author information
        meta.authorName = meta.author ? (meta.author.name || "") : "";
        let aUrl = meta.author ? (meta.author.url || "") : "";
        meta.icon = meta.icon || "extension";

        CaelestiaApi.plugins.available.append(meta);
        pluginLoader.pluginsReloaded();
    }

    function addPluginToAvailable(id, path, source) {
        let meta = { path: path, source: source };
        addMetaReader.pendingId = id;
        addMetaReader.pendingPath = path;
        addMetaReader.pendingSource = source;
        addMetaReader.command = ["cat", path + "/metadata.json"];
        addMetaReader.running = true;
    }

    Process {
        id: addMetaReader

        property string pendingId: ""
        property string pendingPath: ""
        property string pendingSource: ""

        stdout: StdioCollector {
            id: addMetaOut
        }

        onExited: (code) => {
            if (code === 0 && addMetaOut.text.length > 0) {
                try {
                    let meta = JSON.parse(addMetaOut.text);
                    meta.path = addMetaReader.pendingPath;
                    meta.source = addMetaReader.pendingSource;

                    let disabled = pluginLoader.pluginSettings.disabledPlugins || [];
                    meta.enabled = (disabled.indexOf(meta.id) === -1 && disabled.indexOf(meta.name) === -1);
                    meta.settings = meta.settings || [];
                    meta.mediaurl = meta.mediaurl || "";

                    // Extract author information
                    meta.authorName = meta.author ? (meta.author.name || "") : "";
                    let aUrl = meta.author ? (meta.author.url || "") : "";
                    meta.authorAvatar = "";
                    if (aUrl && aUrl.indexOf("github.com/") !== -1) {
                        let cleanUrl = aUrl.endsWith("/") ? aUrl.slice(0, -1) : aUrl;
                        meta.authorAvatar = cleanUrl + ".png";
                    }

                    console.log("addPluginToAvailable: adding", meta.id, "to available list. mediaurl:", meta.mediaurl);
                    CaelestiaApi.plugins.available.append(meta);
                    pluginsReloaded();
                } catch(e) {
                    console.log("addPluginToAvailable: error parsing metadata:", e);
                }
            } else {
                console.log("addPluginToAvailable: cat failed, code:", code, "text:", addMetaOut.text);
            }
        }
    }
}
