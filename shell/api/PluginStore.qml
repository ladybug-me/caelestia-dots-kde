pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

QtObject {
    id: storeRoot

    property bool loading: false
    property bool error: false
    property string errorMessage: ""
    
    property bool installing: false
    property string installProgress: ""

    // Raw index from the server
    property var indexData: null
    property ListModel storePlugins: ListModel {}

    signal indexFetched()

    // 1. Fetch index.json from the github repo
    function fetchIndex() {
        loading = true;
        error = false;
        errorMessage = "";
        
        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["curl", "-sfL", "https://raw.githubusercontent.com/ladybug-me/caelestia-kde-plugins/main/index.json"]
                stdout: StdioCollector { id: out }
                stderr: StdioCollector { id: err }
                onExited: (code) => {
                    storeRoot.loading = false;
                    if (code !== 0) {
                        storeRoot.error = true;
                        storeRoot.errorMessage = "Failed to fetch plugins index (curl exit " + code + "): " + err.text;
                    } else {
                        try {
                            storeRoot.indexData = JSON.parse(out.text);
                            storeRoot.storePlugins.clear();
                            let plugins = storeRoot.indexData.plugins || [];
                            for (let i = 0; i < plugins.length; i++) {
                                let p = plugins[i];
                                storeRoot.storePlugins.append(p);
                            }
                            storeRoot.indexFetched();
                        } catch (e) {
                            storeRoot.error = true;
                            storeRoot.errorMessage = "Failed to parse index JSON: " + e;
                        }
                    }
                    destroy();
                }
            }
        `, storeRoot, "fetchIndexProcess");
        proc.running = true;
    }

    // 2. Install a plugin by cloning just that plugin's directory
    function installPlugin(id, repoPath) {
        if (!id || !repoPath) return;
        
        installing = true;
        installProgress = "Cloning plugin '" + id + "'...";
        
        let targetDir = (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/caelestia/plugins/" + id;
        
        let script = `
            TMP_DIR=$(mktemp -d)
            cd "$TMP_DIR"
            git init -q
            git remote add origin https://github.com/ladybug-me/caelestia-kde-plugins.git
            git config core.sparseCheckout true
            echo "${repoPath}/*" >> .git/info/sparse-checkout
            git fetch -q --depth 1 origin main
            git reset --hard -q origin/main
            mkdir -p $(dirname "${targetDir}")
            rm -rf "${targetDir}"
            mv "${repoPath}" "${targetDir}"
            rm -rf "$TMP_DIR"
            echo "DONE"
        `;
        
        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["bash", "-c", \`${script}\`]
                stdout: StdioCollector { id: out }
                stderr: StdioCollector { id: err }
                onExited: (code) => {
                    storeRoot.installing = false;
                    if (code !== 0) {
                        console.log("Install error:", err.text);
                    } else {
                        console.log("Install success:", out.text);
                        // Trigger a reload
                        PluginLoader.reloadPlugins();
                    }
                    destroy();
                }
            }
        `, storeRoot, "installPluginProcess_" + id);
        proc.running = true;
    }

    // 3. Remove a user plugin
    function removePlugin(id) {
        let targetDir = (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/caelestia/plugins/" + id;
        
        let proc = Qt.createQmlObject(`
            import Quickshell.Io
            Process {
                command: ["rm", "-rf", "${targetDir}"]
                onExited: (code) => {
                    PluginLoader.reloadPlugins();
                    destroy();
                }
            }
        `, storeRoot, "removePluginProcess_" + id);
        proc.running = true;
    }
}
