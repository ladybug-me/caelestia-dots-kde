pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.modules.nexus.common
import qs.utils

PageBase {
    id: root

    title: qsTr("Updates")

    // ── Branch menu items ──────────────────────────────────────────────────
    property list<MenuItem> branchItems

    function destroyBranchItems(items) {
        if (!items)
            return;

        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item && item.destroy)
                item.destroy();
        }
    }

    function updateBranchItems() {
        const previousItems = root.branchItems;
        let items = [];
        for (let i = 0; i < UpdateChecker.availableBranches.length; i++) {
            items.push(Qt.createQmlObject(
                'import qs.components.controls; MenuItem { text: "' + UpdateChecker.availableBranches[i] + '"; icon: "call_split" }',
                root
            ));
        }
        root.branchItems = items;
        root.destroyBranchItems(previousItems);
    }

    Item {
        visible: false
        Connections {
            target: UpdateChecker
            function onAvailableBranchesChanged() { root.updateBranchItems(); }
            function onCommitsChanged() { root.selectedVersionId = ""; }
            function onVersionSummaryModeChanged() { root.selectedVersionId = ""; }
            function onAvailableVersionsChanged() { root.selectedVersionId = ""; }
            function onCurrentBranchChanged() { root.selectedVersionId = ""; }
            function onCurrentVersionChanged() { root.selectedVersionId = ""; }
        }
    }

    Component.onCompleted: {
        root.updateBranchItems();
    }

    Component.onDestruction: {
        root.destroyBranchItems(root.branchItems);
    }

    readonly property var activeBranchItem: branchItems.find(i => i.text === UpdateChecker.currentBranch) || branchItems[0]

    // ── Update process state ───────────────────────────────────────────────
    property string updateLogs: ""
    property bool updateRunning: false
    property real updateProgress: 0.0
    property string updateStatus: ""
    property bool logsExpanded: false
    property double lastUpdateOutputMs: 0
    property bool stallNoticeShown: false
    property string processLineBuffer: ""

    function handleProgressLine(rawLine) {
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

function ingestProcessText(rawText) {
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

    // ── Timeline selection state ───────────────────────────────────────────
    property string selectedVersionId: ""

    readonly property var selectedEntry: {
        for (let i = 0; i < root.timelineEntries.length; i++) {
            if (root.timelineEntries[i].id === root.selectedVersionId)
                return root.timelineEntries[i];
        }
        return null;
    }
    readonly property bool timelineSelectionEnabled: UpdateChecker.versionSummaryMode
    readonly property string selectedVersionState: root.selectedEntry ? root.selectedEntry.state : ""
    readonly property bool selectionIsRevert: root.timelineSelectionEnabled && root.selectedVersionState === "past"
    readonly property bool selectionIsFuture: root.timelineSelectionEnabled && root.selectedVersionState === "available"

    // ── Timeline data ──────────────────────────────────────────────────────
    readonly property var timelineEntries: {
        if (UpdateChecker.versionSummaryMode && UpdateChecker.availableVersions.length > 0) {
            // Version mode: full timeline with available + current + past
            const versions = UpdateChecker.availableVersions;
            const current = UpdateChecker.currentVersion;
            const currentIdx = versions.indexOf(current);
            const result = [];
            for (let i = 0; i < versions.length; i++) {
                let state;
                if (currentIdx === -1) {
                    state = i === 0 ? "current" : "past";
                } else if (i < currentIdx) {
                    state = "available";
                } else if (i === currentIdx) {
                    state = "current";
                } else {
                    state = "past";
                }
                result.push({ id: versions[i], label: versions[i], state: state, subject: "" });
            }
            return result;
        } else {
            // Commit mode (dev branch): pending commits above current marker
            const pending = UpdateChecker.commits.map(c => ({
                id: c.hash,
                label: c.hash.substring(0, 7),
                subject: c.subject || "",
                state: "available"
            }));
            pending.push({
                id: "##current##",
                label: qsTr("installed"),
                subject: UpdateChecker.currentBranch,
                state: "current"
            });
            return pending;
        }
    }

    // ── Hidden settings (preserved for update process) ─────────────────────
    Item {
        Settings {
            id: updaterSettings
            category: "Updater"
            property bool deployConfigs: true
            property bool buildShell: true
        }
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // 1 ── STATUS BANNER ───────────────────────────────────────────────
        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: statusCol.implicitHeight + Tokens.padding.largeIncreased * 2

            ColumnLayout {
                id: statusCol
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Tokens.padding.largeIncreased
                }
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    fontStyle: Tokens.font.icon.extraLarge
                    text: {
                        if (root.updateProgress === 1.0) return "done_all";
                        if (root.updateRunning) return "sync";
                        if (root.selectionIsRevert) return "history";
                        return UpdateChecker.hasUpdate ? "update" : "check_circle";
                    }
                    color: (UpdateChecker.hasUpdate || root.updateRunning || root.updateProgress === 1.0)
                        ? Colours.palette.m3primary
                        : Colours.palette.m3outlineVariant
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    font: Tokens.font.title.medium
                    color: (UpdateChecker.hasUpdate || root.updateRunning || root.updateProgress === 1.0)
                        ? Colours.palette.m3onSurface
                        : Colours.palette.m3outlineVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: {
                        if (root.updateProgress === 1.0) return qsTr("Update complete — log out to apply");
                        if (root.updateRunning) return root.updateStatus || qsTr("Updating…");
                        if (root.selectionIsRevert) return qsTr("Restore to %1?").arg(root.selectedVersionId);
                        if (root.selectionIsFuture && root.selectedVersionId !== "")
                            return qsTr("Install %1?").arg(root.selectedVersionId);
                        if (UpdateChecker.hasUpdate) {
                            return UpdateChecker.versionSummaryMode
                                ? qsTr("New version available on %1").arg(UpdateChecker.currentBranch)
                                : qsTr("%1 new commits on %2").arg(UpdateChecker.pendingCount).arg(UpdateChecker.currentBranch);
                        }
                        return qsTr("You're up to date");
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: UpdateChecker.currentVersion !== "unknown" && !root.updateRunning && root.updateProgress !== 1.0 && root.selectedVersionId === ""
                    text: UpdateChecker.versionSummaryMode
                        ? qsTr("Installed: %1").arg(UpdateChecker.currentVersion)
                        : qsTr("Channel: %1").arg(UpdateChecker.currentBranch)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.medium
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    visible: root.updateRunning || (root.updateProgress > 0.0 && root.updateProgress < 1.0)
                    value: root.updateProgress
                    indeterminate: root.updateProgress === 0.0 && root.updateRunning
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small

                    // Primary action button
                    IconTextButton {
                        visible: {
                            if (root.updateRunning) return false;
                            if (root.updateProgress === 1.0) return true;
                            if (root.selectionIsRevert) return true;
                            if (root.selectionIsFuture && root.selectedVersionId !== "") return true;
                            return UpdateChecker.hasUpdate;
                        }
                        text: {
                            if (root.updateProgress === 1.0) return qsTr("Log Out");
                            if (root.selectionIsRevert) return qsTr("Restore");
                            if (root.selectionIsFuture && root.selectedVersionId !== "")
                                return qsTr("Install %1").arg(root.selectedVersionId);
                            return qsTr("Install Update");
                        }
                        type: TextButton.Primary
                        icon: {
                            if (root.updateProgress === 1.0) return "logout";
                            if (root.selectionIsRevert) return "history";
                            return "system_update_alt";
                        }
                        onClicked: {
                            if (root.updateProgress === 1.0) {
                                logoutProcess.running = true;
                            } else {
                                root.updateLogs = "";
                                root.updateProgress = 0.0;
                                root.updateStatus = qsTr("Starting…");
                                root.updateRunning = true;
                                root.lastUpdateOutputMs = Date.now();
                                root.stallNoticeShown = false;
                                root.processLineBuffer = "";
                                root.logsExpanded = true;
                                UpdateChecker.targetVersion = (root.timelineSelectionEnabled && root.selectedVersionId !== "" && root.selectedVersionId !== "##current##")
                                    ? root.selectedVersionId : "";
                                root.selectedVersionId = "";
                                updateProcess.running = true;
                            }
                        }
                    }

                    // Secondary: Stop / Check for updates / Cancel selection
                    IconTextButton {
                        visible: root.updateProgress !== 1.0
                        text: root.updateRunning ? qsTr("Stop") : (root.selectedVersionId !== "" ? qsTr("Cancel") : qsTr("Check"))
                        type: TextButton.Tonal
                        icon: root.updateRunning ? "stop" : (root.selectedVersionId !== "" ? "close" : "refresh")
                        onClicked: {
                            if (root.updateRunning) {
                                updateProcess.running = false;
                                root.updateRunning = false;
                                root.updateStatus = qsTr("Cancelled");
                                root.updateLogs += "\n[Cancelled by user]";
                            } else if (root.selectedVersionId !== "") {
                                root.selectedVersionId = "";
                            } else {
                                UpdateChecker.checkUpdates();
                            }
                        }
                    }
                }
            }
        }

        // 2 ── CHANNEL SELECTOR ────────────────────────────────────────────
        SectionHeader { text: qsTr("Channel") }

        SelectRow {
            first: true
            last: true
            label: qsTr("Update channel")
            subtext: UpdateChecker.currentBranch === "main"
                ? qsTr("Stable releases")
                : qsTr("Development builds — may be unstable")
            menuItems: root.branchItems
            active: root.activeBranchItem
            onSelected: item => {
                root.selectedVersionId = "";
                UpdateChecker.checkUpdates(item.text);
            }
        }

        // 3 ── VERSION TIMELINE ────────────────────────────────────────────
        SectionHeader { text: qsTr("Version History") }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: timeline.implicitHeight + Tokens.padding.medium * 2

            UpdateTimeline {
                id: timeline
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Tokens.padding.medium
                }
                entries: root.timelineEntries
                selectedId: root.timelineSelectionEnabled ? root.selectedVersionId : ""
                onEntryClicked: (entryId, entryState) => {
                    if (root.updateRunning || !root.timelineSelectionEnabled) return;
                    // Toggle: click same dot to deselect
                    root.selectedVersionId = (root.selectedVersionId === entryId) ? "" : entryId;
                    UpdateChecker.targetVersion = "";
                }
            }
        }

        // 4 ── UPDATE LOG (appears after update runs) ──────────────────────
        SectionHeader {
            visible: root.updateRunning || root.updateLogs !== ""
            text: qsTr("Update Log")
        }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            visible: root.updateRunning || root.updateLogs !== ""
            implicitHeight: logContent.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: logContent
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Tokens.padding.medium
                }
                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: root.updateStatus
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.medium
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    IconButton {
                        icon: root.logsExpanded ? "expand_less" : "expand_more"
                        onClicked: root.logsExpanded = !root.logsExpanded
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    value: root.updateProgress
                    indeterminate: root.updateProgress === 0.0 && root.updateRunning
                    visible: root.updateRunning || root.updateProgress > 0.0
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 240
                    visible: root.logsExpanded && (root.updateLogs !== "" || root.updateRunning)
                    color: Colours.tPalette.m3surfaceContainerLowest
                    radius: Tokens.rounding.small
                    clip: true

                    Flickable {
                        id: logFlickable
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        contentHeight: logText.implicitHeight
                        contentWidth: width
                        flickableDirection: Flickable.VerticalFlick
                        onContentHeightChanged: {
                            if (contentHeight > height) contentY = contentHeight - height;
                        }
                        StyledText {
                            id: logText
                            width: logFlickable.width
                            text: root.updateLogs
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        // ── PROCESSES ─────────────────────────────────────────────────────
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
            command: [Paths.absolutePath("~/.local/bin/caelestia-update"), UpdateChecker.currentBranch]
                .concat(UpdateChecker.targetVersion !== "" ? [UpdateChecker.targetVersion] : [])
            environment: ({
                CAELESTIA_SKIP_DEPLOY: updaterSettings.deployConfigs ? "0" : "1",
                CAELESTIA_SKIP_BUILD: updaterSettings.buildShell ? "0" : "1"
            })
            stdout: SplitParser {
                onRead: text => {
                    root.ingestProcessText(text);
                }
            }
            stderr: SplitParser {
                onRead: text => {
                    root.ingestProcessText(text);
                }
            }
            onExited: code => {
                if (root.processLineBuffer !== "") {
                    root.handleProgressLine(root.processLineBuffer);
                    root.processLineBuffer = "";
                }
                root.updateRunning = false;
                root.lastUpdateOutputMs = 0;
                if (code === 0) {
                    Toaster.toast(qsTr("Update Successful"), qsTr("The update is complete. Please log out to apply changes."), "done");
                    UpdateChecker.reload();
                } else {
                    root.updateStatus = qsTr("Update failed (exit code %1)").arg(code);
                    Toaster.toast(qsTr("Update Failed"), qsTr("The update script returned error code %1").arg(code), "error");
                }
            }
        }

        Process {
            id: logoutProcess
            command: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"]
        }
    }
}
