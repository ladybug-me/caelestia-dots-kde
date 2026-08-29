pragma Singleton

import qs.services.api
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Item {
    id: storeRoot

    property bool loading: false
    property bool error: false
    property string errorMessage: ""

    property bool installing: false
    property string installProgress: ""

    property bool restartRequired: false

    // Predicted installed state — seeded once from disk scan on startup,
    // then mutated purely by user actions (no re-scanning at runtime).
    property var installedPluginIds: []
    property bool baselineLoaded: false

    // Raw index from the server
    property var indexData: null
    property ListModel storePlugins: ListModel {}

    signal indexFetched()
    signal installedStateChanged()

    function fetchIndex(branch) {
        let fetchBranch = branch || "main";
        loading = true;
        error = false;
        errorMessage = "";

        // Seed installed IDs from disk baseline if not done yet
        // (handles the race condition where fetchIndex resolves before PluginLoader's pluginsReloaded)
        if (!baselineLoaded && CaelestiaApi.plugins.available.count > 0) {
            baselineLoaded = true;
            let ids = [];
            let av = CaelestiaApi.plugins.available;
            for (let i = 0; i < av.count; i++)
                ids.push(av.get(i).id);
            installedPluginIds = ids;
            console.log("PluginStore: baseline seeded in fetchIndex:", JSON.stringify(ids));
        }

        fetchProc.command = ["curl", "-sfL", "https://raw.githubusercontent.com/ladybug-me/caelestia-kde-plugins/" + fetchBranch + "/index.json"];
        fetchProc.running = true;
    }

    function installPlugin(id, repoPath, branch) {
        if (!id) return;

        let installBranch = branch || "main";

        let actualRepoPath = repoPath || ("plugins/" + id);

        installing = true;
        installProgress = "Cloning plugin '" + id + "'...";

        let targetDir = (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/caelestia/plugins/" + id;

        let script = `set -e
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
git init -q
git remote add origin https://github.com/ladybug-me/caelestia-kde-plugins.git
git config core.sparseCheckout true
echo "${actualRepoPath}/*" >> .git/info/sparse-checkout
git fetch -q --depth 1 --filter=blob:none origin "${installBranch}"
git reset --hard -q "origin/${installBranch}"
mkdir -p "$(dirname "${targetDir}")"
rm -rf "${targetDir}"
mv "${actualRepoPath}" "${targetDir}"
rm -rf "$TMP_DIR"
echo "DONE"`;

        installProc.pendingId = id;
        installProc.pendingTargetDir = targetDir;
        installProc.command = ["bash", "-c", script];
        installProc.running = true;
    }

    function removePlugin(id) {
        let targetDir = (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/caelestia/plugins/" + id;
        removeProc.pendingId = id;
        removeProc.command = ["rm", "-rf", targetDir];
        removeProc.running = true;
    }

    Connections {
        target: PluginLoader

        function onPluginsReloaded() {
            // Only seed once from the startup scan
            if (storeRoot.baselineLoaded)
                return;
            storeRoot.baselineLoaded = true;
            let ids = [];
            let av = CaelestiaApi.plugins.available;
            for (let i = 0; i < av.count; i++)
                ids.push(av.get(i).id);
            storeRoot.installedPluginIds = ids;
            console.log("PluginStore: baseline loaded, installed:", JSON.stringify(ids));
        }
    }

    // ── 1. Fetch store index ──────────────────────────────────────────────────

    Process {
        id: fetchProc

        stdout: StdioCollector { id: fetchOut }
        stderr: StdioCollector { id: fetchErr }

        onExited: (code) => {
            storeRoot.loading = false;
            if (code !== 0) {
                storeRoot.error = true;
                storeRoot.errorMessage = "Failed to fetch plugins index (curl exit " + code + "): " + fetchErr.text;
            } else {
                try {
                    storeRoot.indexData = JSON.parse(fetchOut.text);
                    storeRoot.storePlugins.clear();
                    let plugins = storeRoot.indexData.plugins || [];
                    for (let i = 0; i < plugins.length; i++) {
                        let p = plugins[i];
                        // Rename 'id' to 'pluginId' to avoid clash with QML's reserved 'id' keyword
                        // in ComponentBehavior:Bound delegates
                        p.pluginId = p.id;
                        p.mediaurl = p.mediaurl || "";
                        p.authorName = p.author ? (p.author.name || "") : "";
                        let aUrl = p.author ? (p.author.url || "") : "";
                        p.icon = p.icon || "extension";
                        storeRoot.storePlugins.append(p);
                    }
                    storeRoot.indexFetched();
                } catch (e) {
                    storeRoot.error = true;
                    storeRoot.errorMessage = "Failed to parse index JSON: " + e;
                }
            }
        }
    }

    // ── 2. Install a plugin ───────────────────────────────────────────────────

    Process {
        id: installProc

        property string pendingId: ""
        property string pendingTargetDir: ""

        stdout: StdioCollector { id: installOut }
        stderr: StdioCollector { id: installErr }

        onExited: (code) => {
            storeRoot.installing = false;
            if (code !== 0) {
                console.log("PluginStore: install error for", installProc.pendingId, ":", installErr.text, installOut.text);
            } else {
                console.log("PluginStore: install success for", installProc.pendingId);
                storeRoot.restartRequired = true;
                // Track as installed for UI prediction (predicted post-restart state)
                let ids = storeRoot.installedPluginIds.slice();
                if (ids.indexOf(installProc.pendingId) === -1)
                    ids.push(installProc.pendingId);
                storeRoot.installedPluginIds = ids;
                console.log("PluginStore: installedPluginIds now:", JSON.stringify(ids));
                // Also add to installed tab list
                PluginLoader.addPluginToAvailable(installProc.pendingId, installProc.pendingTargetDir, "user");
            }
        }
    }

    // ── 3. Remove a user plugin ───────────────────────────────────────────────

    Process {
        id: removeProc

        property string pendingId: ""

        onExited: (code) => {
            storeRoot.restartRequired = true;
            // Remove from predicted installed set
            let ids = storeRoot.installedPluginIds.slice();
            let idx = ids.indexOf(removeProc.pendingId);
            if (idx !== -1) ids.splice(idx, 1);
            storeRoot.installedPluginIds = ids;
            console.log("PluginStore: removed", removeProc.pendingId, "installedPluginIds now:", JSON.stringify(ids));
            // Also drop from the installed tab list model
            PluginLoader.removePluginFromAvailable(removeProc.pendingId);
        }
    }
}
