pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.utils
import qs.services

Singleton {
    id: root

    property bool hasUpdate: false
    property string currentBranch: "main"
    property var commits: []
    property var availableBranches: ["main", "dev"]
    property int pendingCount: 0

    property string _localCommit: ""
    property bool loaded: false

    function checkUpdates(branch) {
        if (branch === undefined) branch = "";
        if (!GlobalConfig.general.checkUpdates) return;
        if (branch !== "") currentBranch = branch;
        
        let bashCmd = `
LIVE_BRANCHES=$(git ls-remote --heads https://github.com/ladybug-me/caelestia-dots-kde.git | awk '{print $2}' | sed 's|^refs/heads/||' | tr '\n' ',' | sed 's/,$//')
if [ -z "$LIVE_BRANCHES" ]; then
    LIVE_BRANCHES="main"
fi
echo "BRANCHES|$LIVE_BRANCHES"

if ! echo ",$LIVE_BRANCHES," | grep -q ",${currentBranch},"; then
    currentBranch="main"
fi

mkdir -p "$HOME/.config/quickshell/caelestia"
echo "${currentBranch}" > "$HOME/.config/quickshell/caelestia/.update_branch"
REPO="$HOME/.cache/caelestia-update-repo"
if [ ! -d "$REPO" ]; then
    git clone --bare --filter=blob:none https://github.com/ladybug-me/caelestia-dots-kde.git "$REPO" >/dev/null 2>&1
else
    git -C "$REPO" fetch origin ${currentBranch}:${currentBranch} >/dev/null 2>&1
fi
if [ -n "${root._localCommit}" ]; then
    LOCAL_DATE=$(git -C "$REPO" show -s --format=%cI ${root._localCommit} 2>/dev/null)
    if [ -n "$LOCAL_DATE" ]; then
        git -C "$REPO" log --format="%h|%s|%an|%cI" --since="$LOCAL_DATE" ${root._localCommit}..${currentBranch} 2>/dev/null || echo ""
    else
        git -C "$REPO" log --format="%h|%s|%an|%cI" ${root._localCommit}..${currentBranch} 2>/dev/null || echo ""
    fi
else
    echo ""
fi
`
        gitProcess.command = ["bash", "-c", bashCmd];
        gitProcess.running = true;
    }

    function reload() {
        loaded = false;
        localCommitProcess.running = true;
    }

    // Process to read local commit and saved branch
    Process {
        id: localCommitProcess
        running: GlobalConfig.general.checkUpdates
        command: ["bash", "-c", "echo \"$(cat ~/.config/quickshell/caelestia/.current_commit 2>/dev/null)|$(cat ~/.config/quickshell/caelestia/.update_branch 2>/dev/null)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                root._localCommit = parts[0];
                if (parts.length > 1 && parts[1] !== "") {
                    root.currentBranch = parts[1];
                }
                root.loaded = true;
                root.checkUpdates();
            }
        }
    }

    Process {
        id: gitProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const lines = text.trim().split("\n");
                    const parsedCommits = [];
                    
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim();
                        if (line === "") continue;
                        if (line.startsWith("BRANCHES|")) {
                            root.availableBranches = line.substring(9).split(",");
                            if (!root.availableBranches.includes(root.currentBranch)) {
                                root.currentBranch = "main";
                            }
                            continue;
                        }
                        const parts = line.split("|");
                        if (parts.length >= 4) {
                            parsedCommits.push({
                                hash: parts[0],
                                subject: parts[1],
                                author: parts[2],
                                date: new Date(parts[3]).toLocaleString(Qt.locale(), Locale.ShortFormat)
                            });
                        }
                    }
                    
                    root.commits = parsedCommits;
                    const prevCount = root.pendingCount;
                    root.pendingCount = parsedCommits.length;
                    root.hasUpdate = root.pendingCount > 0;
                    
                    if (root.hasUpdate && prevCount === 0 && root.loaded) {
                        Toaster.toast(qsTr("System Update Available"), qsTr("%1 new commits on %2 branch").arg(root.pendingCount).arg(root.currentBranch), "update");
                    }
                } catch(e) {
                    console.log("UpdateChecker git parse error:", e);
                }
            }
        }
    }

}
