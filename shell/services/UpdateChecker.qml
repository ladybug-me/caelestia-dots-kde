pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
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
    property var availableVersions: []
    property int pendingCount: 0
    property bool versionSummaryMode: false
    property string currentVersion: "unknown"
    property string previousVersion: "unknown"
    property string targetVersion: ""
    property string installedCommitHash: ""

    property string _localCommit: ""
    property bool loaded: false

    // ── Update process state ────────────────────────────────────────────
    // Lives on the singleton (rather than UpdatesPage) so it survives the
    // page being destroyed/recreated when the user navigates to a different
    // top-level Nexus page and back (see Pages.qml `loadPage`).
    property string updateLogs: ""
    property bool updateRunning: false
    property bool updateCancelled: false
    property real updateProgress: 0.0
    property string updateStatus: ""
    property bool logsExpanded: false
    property double lastUpdateOutputMs: 0
    property bool stallNoticeShown: false
    property string processLineBuffer: ""

    function clampBranch(branch: string): string {
        return (branch === "dev" || branch === "main") ? branch : "main";
    }

    function checkUpdates(branch) {
        if (branch === undefined) branch = "";
        if (!GlobalConfig.general.checkUpdates) return;
        if (branch !== "") currentBranch = clampBranch(branch);
        else currentBranch = clampBranch(currentBranch);
        
        let bashCmd = `
    CURRENT_BRANCH="$1"
    LOCAL_COMMIT="$(cat \"$HOME/.config/quickshell/caelestia/.current_commit\" 2>/dev/null || true)"

ALLOWED_BRANCHES="main dev"
LIVE_ALLOWED_BRANCHES=""
for b in $ALLOWED_BRANCHES; do
    if git ls-remote --exit-code --heads https://github.com/ladybug-me/caelestia-dots-kde.git "$b" >/dev/null 2>&1; then
        LIVE_ALLOWED_BRANCHES="$LIVE_ALLOWED_BRANCHES,$b"
    fi
done
LIVE_ALLOWED_BRANCHES="$(printf '%s' "$LIVE_ALLOWED_BRANCHES" | sed 's/^,//')"
if [ -z "$LIVE_ALLOWED_BRANCHES" ]; then
    LIVE_ALLOWED_BRANCHES="main"
fi
echo "BRANCHES|$LIVE_ALLOWED_BRANCHES"

if ! echo ",$LIVE_ALLOWED_BRANCHES," | grep -q ",$CURRENT_BRANCH,"; then
    CURRENT_BRANCH="main"
fi

if ! echo ",main,dev," | grep -q ",$CURRENT_BRANCH,"; then
    CURRENT_BRANCH="main"
fi

mkdir -p "$HOME/.config/quickshell/caelestia"
echo "$CURRENT_BRANCH" > "$HOME/.config/quickshell/caelestia/.update_branch"
REPO="$HOME/.cache/caelestia-update-repo"
if [ ! -d "$REPO" ]; then
    git clone --bare --filter=blob:none https://github.com/ladybug-me/caelestia-dots-kde.git "$REPO" >/dev/null 2>&1
else
    git -C "$REPO" fetch --force origin "$CURRENT_BRANCH:$CURRENT_BRANCH" >/dev/null 2>&1
fi

resolve_version() {
    local ref="$1"
    local ver
    ver="$(git -C "$REPO" show "$ref:.github/version.env" 2>/dev/null | sed -nE 's/^VERSION[[:space:]]*=[[:space:]]*([A-Za-z0-9._-]+).*/\\1/p' | head -n 1)"
    if [ -n "$ver" ]; then
        printf '%s' "$ver"
        return
    fi
    ver="$(git -C "$REPO" describe --tags --abbrev=0 "$ref" 2>/dev/null || true)"
    if [ -z "$ver" ]; then
        ver="$(git -C "$REPO" show "$ref:shell/CMakeLists.txt" 2>/dev/null | sed -nE 's/.*VERSION +"?([0-9]+\\.[0-9]+\\.[0-9]+).*/\\1/p' | head -n 1)"
    fi
    if [ -z "$ver" ]; then
        ver="unknown"
    fi
    printf '%s' "$ver"
}

if [ "$CURRENT_BRANCH" = "main" ]; then
    git -C "$REPO" fetch --tags origin >/dev/null 2>&1 || true

    CURRENT_VERSION_FILE="$HOME/.config/quickshell/caelestia/.current_version"
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        FROM_VERSION="$(sed -nE 's/^VERSION[[:space:]]*=[[:space:]]*([A-Za-z0-9._-]+).*/\\1/p' "$CURRENT_VERSION_FILE" | head -n 1)"
    elif [ -n "$LOCAL_COMMIT" ]; then
        FROM_VERSION="$(resolve_version "$LOCAL_COMMIT")"
    elif [ -f "$HOME/.config/quickshell/caelestia/.github/version.env" ]; then
        FROM_VERSION="$(sed -nE 's/^VERSION[[:space:]]*=[[:space:]]*([A-Za-z0-9._-]+).*/\\1/p' "$HOME/.config/quickshell/caelestia/.github/version.env" | head -n 1)"
    else
        FROM_VERSION="unknown"
    fi
    [ -n "$FROM_VERSION" ] || FROM_VERSION="unknown"

    TAG_LINES="$(git -C "$REPO" for-each-ref --sort=-creatordate --format='%(refname:short)|%(creatordate:iso8601-strict)' refs/tags 2>/dev/null || true)"
    LATEST_VERSION="$(printf '%s\n' "$TAG_LINES" | sed -n '1s/|.*//p')"
    PREVIOUS_VERSION="$(printf '%s\n' "$TAG_LINES" | sed -n '2s/|.*//p')"
    [ -n "$LATEST_VERSION" ] || LATEST_VERSION="$FROM_VERSION"
    [ -n "$PREVIOUS_VERSION" ] || PREVIOUS_VERSION="$LATEST_VERSION"
    echo "META|$FROM_VERSION|$LATEST_VERSION|$PREVIOUS_VERSION"

    if [ "$FROM_VERSION" != "$LATEST_VERSION" ] && [ -n "$LATEST_VERSION" ]; then
        DISTANCE="$(printf '%s\n' "$TAG_LINES" | cut -d'|' -f1 | nl -v0 | awk -v local="$FROM_VERSION" '
            $2 == local { print $1; found=1; exit }
            END { if (!found) print 1 }
        ')"
        if ! [[ "$DISTANCE" =~ ^[0-9]+$ ]] || [ "$DISTANCE" -lt 1 ]; then
            DISTANCE=1
        fi
        echo "VERSION|$FROM_VERSION|$LATEST_VERSION|$DISTANCE"
    fi

    printf '%s\n' "$TAG_LINES" | while IFS='|' read -r tag created; do
        [ -n "$tag" ] || continue
        echo "RELEASE_TAG|$tag|$created"
    done

    PYTHON_BIN="$(command -v python3 || command -v python || true)"
    [ -n "$PYTHON_BIN" ] || exit 0

    FROM_VERSION="$FROM_VERSION" REPO="$REPO" "$PYTHON_BIN" - <<'PY'
import json
import os
import re
import subprocess
import sys
import urllib.request

def parse_whats_changed(text: str) -> str:
    txt = (text or "").replace("\r", "")

    # Keep only the "What's Changed" section when present.
    m = re.search(r"^#{2,3}\s*What's Changed\s*$", txt, flags=re.IGNORECASE | re.MULTILINE)
    if m:
        rest = txt[m.end():]
        next_header = re.search(r"^#{2,3}\s+", rest, flags=re.MULTILINE)
        if next_header:
            txt = rest[:next_header.start()]
        else:
            txt = rest
    else:
        return ""

    # Normalize spacing and keep it compact for list rows.
    txt = txt.strip()
    txt = re.sub(r"\n{3,}", "\n\n", txt)
    txt = re.sub(r"[ \t]+\n", "\n", txt)
    return txt[:1600]

def run_git(*args: str) -> str:
    repo = os.getenv("REPO") or ""
    cmd = ["git", "-C", repo, *args]
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)

def fetch_releases() -> list:
    url = "https://api.github.com/repos/ladybug-me/caelestia-dots-kde/releases?per_page=100"
    req = urllib.request.Request(url, headers={"User-Agent": "caelestia-update-checker"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8") or "[]")
    except Exception:
        return []

try:
    raw_tags = run_git("for-each-ref", "--sort=-creatordate", "--format=%(refname:short)|%(creatordate:iso8601-strict)", "refs/tags")
except Exception:
    raise SystemExit(0)

tags = []
for line in (raw_tags or "").splitlines():
    if not line.strip() or "|" not in line:
        continue
    tag, created = line.split("|", 1)
    tag = tag.strip()
    if tag:
        tags.append({"tag": tag, "created": created.strip()})

if not tags:
    raise SystemExit(0)

release_map = {}
for rel in fetch_releases():
    if rel.get("draft") or rel.get("prerelease"):
        continue
    tag = (rel.get("tag_name") or "").strip()
    if not tag:
        continue
    release_map[tag] = {
        "published": (rel.get("published_at") or "").strip(),
        "body": parse_whats_changed(rel.get("body") or "")
    }

from_version = (os.getenv("FROM_VERSION") or "unknown").strip()
latest = tags[0]["tag"]
previous = tags[1]["tag"] if len(tags) > 1 else latest

print(f"META|{from_version}|{latest}|{previous}")

if from_version != latest:
    distance = 1
    tag_names = [t["tag"] for t in tags]
    if from_version in tag_names:
        distance = tag_names.index(from_version)
    print(f"VERSION|{from_version}|{latest}|{max(1, distance)}")

for t in tags:
    tag = t["tag"]
    rel = release_map.get(tag, {})
    out = {
        "tag": tag,
        "published": rel.get("published") or t.get("created") or "",
        "body": rel.get("body") or ""
    }
    print("RELEASE_JSON|" + json.dumps(out, separators=(",", ":"), ensure_ascii=False))
PY
else
    # Dev branch: emit the full recent commit history (not just commits ahead of
    # the installed one) so the UI can render a git-log-style timeline with
    # past/current/available state, same as the version list does for main.
    DEV_LOG_LIMIT=150
    git -C "$REPO" log --format="COMMIT%x1f%H%x1f%h%x1f%s%x1f%an%x1f%cI%x1f%P" -n "$DEV_LOG_LIMIT" "$CURRENT_BRANCH" 2>/dev/null
    if [ -n "$LOCAL_COMMIT" ]; then
        AHEAD_COUNT="$(git -C "$REPO" rev-list --count "$LOCAL_COMMIT..$CURRENT_BRANCH" 2>/dev/null || echo 0)"
    else
        AHEAD_COUNT=0
    fi
    [ -n "$AHEAD_COUNT" ] || AHEAD_COUNT=0
    echo "AHEAD|$AHEAD_COUNT"
    echo "LOCAL|$LOCAL_COMMIT"
fi
`
    gitProcess.command = ["bash", "-c", bashCmd, "update-check", currentBranch];
        gitProcess.running = true;
    }

    function reload() {
        loaded = false;
        localCommitProcess.running = true;
    }

    function handleProgressLine(rawLine: string): void {
        const line = rawLine.trim();
        if (line === "")
            return;

        const progressMatch = line.match(/PROGRESS:\s*(done.*|\d+\/\d+:\s*.+)$/);
        if (progressMatch) {
            const pText = progressMatch[1].trim();
            if (pText.startsWith("done")) {
                root.updateProgress = 1.0;
                root.updateStatus = qsTr("Done!");
                return;
            }

            const stageMatch = pText.match(/^(\d+)\/(\d+):\s*(.+)$/);
            if (stageMatch) {
                const current = parseInt(stageMatch[1]);
                const total = parseInt(stageMatch[2]);
                if (total > 0) {
                    root.updateProgress = current / total;
                    root.updateStatus = stageMatch[3];
                }
            }
            return;
        }

        // Fallback: mark deploy stage as finished when deploy script confirms completion.
        if (line.indexOf("Config deployment complete") !== -1 && root.updateProgress < 0.8) {
            root.updateProgress = 0.7;
            root.updateStatus = qsTr("Preparing shell build...");
        }
    }

    function ingestProcessText(rawText: string): void {
        root.lastUpdateOutputMs = Date.now();
        root.stallNoticeShown = false;

        const cleaned = rawText
            .replace(/\u001b\[[0-9;?]*[A-Za-z]/g, "")
            .replace(/\r/g, "\n");

        const chunk = cleaned.endsWith("\n") ? cleaned : (cleaned + "\n");
        root.updateLogs += chunk;

        const combined = root.processLineBuffer + chunk;
        const lines = combined.split("\n");
        root.processLineBuffer = lines.pop();

        for (let i = 0; i < lines.length; i++) {
            root.handleProgressLine(lines[i]);
        }
    }

    function startUpdate(targetVersion: string): void {
        if (root.updateRunning)
            return;
        root.targetVersion = targetVersion;
        root.updateCancelled = false;
        root.updateLogs = "";
        root.updateProgress = 0.0;
        root.updateStatus = qsTr("Starting…");
        root.updateRunning = true;
        root.lastUpdateOutputMs = Date.now();
        root.stallNoticeShown = false;
        root.processLineBuffer = "";
        root.logsExpanded = true;
        updateProcess.running = true;
    }

    function stopUpdate(): void {
        if (!root.updateRunning)
            return;
        root.updateCancelled = true;
        updateProcess.running = false;
        root.updateRunning = false;
        root.updateStatus = qsTr("Cancelled");
        root.updateLogs += "\n[Cancelled by user]";
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
                    const parsedVersions = [];
                    let parsedPendingCount = 0;
                    let parsedHasUpdate = false;
                    let parsedVersionSummaryMode = root.currentBranch === "main";
                    let parsedLocalCommitFull = "";
                    root.availableBranches = ["main", "dev"];
                    
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim();
                        if (line === "") continue;
                        if (line.startsWith("BRANCHES|")) {
                            root.availableBranches = line.substring(9).split(",").filter(b => b === "main" || b === "dev");
                            if (root.availableBranches.length === 0)
                                root.availableBranches = ["main"];
                            if (!root.availableBranches.includes(root.currentBranch)) {
                                root.currentBranch = "main";
                            }
                            continue;
                        }
                        if (line.startsWith("VERSION|")) {
                            const parts = line.split("|");
                            const count = parseInt(parts[3] || "0");
                            parsedVersionSummaryMode = true;
                            parsedPendingCount = isNaN(count) ? 1 : Math.max(1, count);
                            parsedHasUpdate = parsedPendingCount > 0;
                            // Show only version entries in main mode; no commit-level rows.
                            continue;
                        }
                        if (line.startsWith("META|")) {
                            const parts = line.split("|");
                            root.currentVersion = parts[1] || "unknown";
                            root.previousVersion = parts[3] || parts[2] || "unknown";
                            parsedVersionSummaryMode = true;
                            continue;
                        }
                        if (line.startsWith("RELEASE_JSON|")) {
                            const payload = line.slice("RELEASE_JSON|".length);
                            parsedVersionSummaryMode = true;
                            try {
                                const rel = JSON.parse(payload);
                                const tag = rel.tag || "";
                                const published = rel.published || "";
                                const body = rel.body || "";
                                if (tag === "")
                                    continue;

                                parsedCommits.push({
                                    hash: qsTr("Release"),
                                    subject: tag,
                                    author: qsTr("GitHub release"),
                                    date: published ? new Date(published).toLocaleString(Qt.locale(), Locale.ShortFormat) : "",
                                    details: body
                                });
                                parsedVersions.push(tag);
                            } catch (_ignored) {
                                // Ignore malformed release lines and keep parsing.
                            }
                            continue;
                        }
                        if (line.startsWith("RELEASE_TAG|")) {
                            const parts = line.split("|");
                            const tag = parts[1] || "";
                            const created = parts[2] || "";
                            parsedVersionSummaryMode = true;
                            if (tag === "")
                                continue;

                            // Fallback path when release JSON parsing is unavailable.
                            parsedCommits.push({
                                hash: qsTr("Release"),
                                subject: tag,
                                author: qsTr("Tag"),
                                date: created ? new Date(created).toLocaleString(Qt.locale(), Locale.ShortFormat) : "",
                                details: ""
                            });
                            parsedVersions.push(tag);
                            continue;
                        }
                        if (line.startsWith("COMMIT\u001f")) {
                            // COMMIT<US>fullHash<US>shortHash<US>subject<US>author<US>date<US>parents
                            const parts = line.split("\u001f");
                            parsedVersionSummaryMode = false;
                            const parentsField = (parts[6] || "").trim();
                            const parentCount = parentsField === "" ? 0 : parentsField.split(/\s+/).length;
                            parsedCommits.push({
                                hash: parts[2] || "",
                                fullHash: parts[1] || "",
                                subject: parts[3] || "",
                                author: parts[4] || "",
                                date: new Date(parts[5]).toLocaleString(Qt.locale(), Locale.ShortFormat),
                                isMerge: parentCount > 1
                            });
                            continue;
                        }
                        if (line.startsWith("LOCAL|")) {
                            parsedLocalCommitFull = line.substring(6).trim();
                            continue;
                        }
                        if (line.startsWith("AHEAD|")) {
                            const count = parseInt(line.substring(6).trim());
                            parsedVersionSummaryMode = false;
                            parsedPendingCount = isNaN(count) ? 0 : count;
                            parsedHasUpdate = parsedPendingCount > 0;
                            continue;
                        }
                        const parts = line.split("|");
                        if (parts.length >= 4) {
                            parsedVersionSummaryMode = false;
                            parsedCommits.push({
                                hash: parts[0],
                                subject: parts[1],
                                author: parts[2],
                                date: new Date(parts[3]).toLocaleString(Qt.locale(), Locale.ShortFormat)
                            });
                        }
                    }

                    if (!parsedVersionSummaryMode && parsedLocalCommitFull === "") {
                        // No installed commit on record yet: can't say what's pending.
                        parsedPendingCount = 0;
                        parsedHasUpdate = false;
                    }
                    root.installedCommitHash = parsedVersionSummaryMode ? "" : parsedLocalCommitFull;

                    const dedupedCommits = [];
                    const seenKeys = new Set();
                    for (let i = 0; i < parsedCommits.length; i++) {
                        const key = parsedCommits[i].fullHash || `${parsedCommits[i].hash}|${parsedCommits[i].subject}`;
                        if (seenKeys.has(key))
                            continue;
                        seenKeys.add(key);
                        dedupedCommits.push(parsedCommits[i]);
                    }

                    root.commits = dedupedCommits;
                    const uniqueVersions = [];
                    const seenVersions = new Set();
                    for (let i = 0; i < parsedVersions.length; i++) {
                        const v = parsedVersions[i];
                        if (seenVersions.has(v))
                            continue;
                        seenVersions.add(v);
                        uniqueVersions.push(v);
                    }
                    root.availableVersions = parsedVersionSummaryMode ? uniqueVersions : [];
                    if (parsedVersionSummaryMode) {
                        if (!root.availableVersions.includes(root.targetVersion)) {
                            root.targetVersion = root.availableVersions.length > 0 ? root.availableVersions[0] : "";
                        }
                        if (root.currentVersion === "unknown" && root.availableVersions.length > 0) {
                            root.currentVersion = root.availableVersions[0];
                        }
                        if (root.previousVersion === "unknown" && root.availableVersions.length > 1) {
                            root.previousVersion = root.availableVersions[1];
                        }
                    }
                    const prevCount = root.pendingCount;
                    root.pendingCount = parsedPendingCount;
                    root.hasUpdate = parsedHasUpdate;
                    root.versionSummaryMode = parsedVersionSummaryMode;
                    
                    if (root.hasUpdate && prevCount === 0 && root.loaded) {
                        const summaryText = root.currentBranch === "main"
                            ? qsTr("Main branch version update available")
                            : qsTr("%1 new commits on %2 branch").arg(root.pendingCount).arg(root.currentBranch);
                        Toaster.toast(qsTr("System Update Available"), summaryText, "update");
                    }
                } catch(e) {
                    console.log("UpdateChecker git parse error:", e);
                }
            }
        }
    }

    Settings {
        id: updaterSettings
        category: "Updater"
        property bool deployConfigs: true
        property bool buildShell: true
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.updateRunning
        onTriggered: {
            if (!root.updateRunning) return;
            if (root.lastUpdateOutputMs <= 0) return;
            const idleMs = Date.now() - root.lastUpdateOutputMs;
            if (idleMs >= 120000 && !root.stallNoticeShown) {
                root.stallNoticeShown = true;
                root.updateLogs += "[WARN] No updater output for 120s. If this persists, stop and retry.\n";
            }
        }
    }

    Process {
        id: updateProcess
        command: [Paths.absolutePath("~/.local/bin/caelestia-update"), root.currentBranch]
            .concat(root.targetVersion !== "" ? [root.targetVersion] : [])
        environment: ({
            CAELESTIA_SKIP_DEPLOY: updaterSettings.deployConfigs ? "0" : "1",
            CAELESTIA_SKIP_BUILD: updaterSettings.buildShell ? "0" : "1"
        })
        stdout: SplitParser {
            onRead: function(text) {
                root.ingestProcessText(text);
            }
        }
        stderr: SplitParser {
            onRead: function(text) {
                root.ingestProcessText(text);
            }
        }
        onExited: function(code) {
            if (root.processLineBuffer !== "") {
                root.handleProgressLine(root.processLineBuffer);
                root.processLineBuffer = "";
            }
            root.updateRunning = false;
            root.lastUpdateOutputMs = 0;
            if (root.updateCancelled) {
                root.updateCancelled = false;
                root.updateStatus = qsTr("Cancelled");
                return;
            }
            if (code === 0) {
                Toaster.toast(qsTr("Update Successful"), qsTr("The update is complete. Please log out to apply changes."), "done");
                root.reload();
            } else {
                root.updateStatus = qsTr("Update failed (exit code %1)").arg(code);
                Toaster.toast(qsTr("Update Failed"), qsTr("The update script returned error code %1").arg(code), "error");
            }
        }
    }
}
