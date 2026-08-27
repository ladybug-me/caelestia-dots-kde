pragma Singleton

import QtQuick
import QtCore
import Quickshell
import api 1.0

Item {
    id: pluginLoader

    property var loadedPlugins: []
    property var discovered: []
    
    property bool loadRequested: false
    property bool finalized: false

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
            if (av.get(i).name === name) {
                av.setProperty(i, "enabled", enable);
            }
        }
    }

    function checkAndFinalize() {
        if (finalized) return;
        finalized = true;
        CaelestiaApi.plugins.available.clear();
        for (let k = 0; k < discovered.length; k++) {
            CaelestiaApi.plugins.available.append(discovered[k]);
        }
        console.log("Plugins finalized! Discovered count: ", discovered.length);
    }

    function processFoundPlugin(basePath, pluginName) {
        if (!pluginName) return;
        
        let pluginDir = basePath + "/" + pluginName;
        let mainFile = pluginDir + "/main.qml";
        
        let disabled = pluginSettings.disabledPlugins || [];
        let isEnabled = disabled.indexOf(pluginName) === -1;

        discovered.push({ "name": pluginName, "path": pluginDir, "enabled": isEnabled });

        if (!isEnabled) {
            console.log("Skipping disabled plugin: " + pluginName);
            return;
        }
        
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

    function loadPlugins(): void {
        loadRequested = true;
        discovered = [];
        finalized = false;
        
        let home = Quickshell.env("HOME");
        
        // Since Quickshell Singletons fail to instantiate FolderListModel or Process correctly 
        // to dynamically list directories without C++, we load known plugins explicitly.
        pluginLoader.processFoundPlugin(home + "/.config/caelestia/plugins", "bar-autohide");
        
        pluginLoader.checkAndFinalize();
    }
}
