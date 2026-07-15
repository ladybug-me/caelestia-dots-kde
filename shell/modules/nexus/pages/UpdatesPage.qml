pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
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
    readonly property list<MenuItem> branchItems: branchVariants.instances

    Item {
        visible: false

        Variants {
            id: branchVariants

            model: UpdateChecker.availableBranches

            MenuItem {
                required property string modelData

                text: modelData
                icon: "call_split"
            }
        }

        Connections {
            target: UpdateChecker
            function onCommitsChanged() { root.selectedVersionId = ""; }
            function onVersionSummaryModeChanged() { root.selectedVersionId = ""; }
            function onAvailableVersionsChanged() { root.selectedVersionId = ""; }
            function onCurrentBranchChanged() { root.selectedVersionId = ""; }
            function onCurrentVersionChanged() { root.selectedVersionId = ""; }
            function onInstalledCommitHashChanged() { root.selectedVersionId = ""; }
        }
    }

    readonly property var activeBranchItem: {
        const found = branchItems.find(function(i) { return i.text === UpdateChecker.currentBranch; });
        return found || (branchItems.length > 0 ? branchItems[0] : null);
    }

    // ── Update process state ───────────────────────────────────────────────
    // Backed by the UpdateChecker singleton (not local properties) so the
    // running update, its progress and logs survive navigating away from
    // this page and back — see Pages.qml, which destroys/recreates the page
    // Item on every top-level page switch.
    readonly property bool updateRunning: UpdateChecker.updateRunning
    readonly property real updateProgress: UpdateChecker.updateProgress
    readonly property string updateStatus: UpdateChecker.updateStatus
    readonly property string updateLogs: UpdateChecker.updateLogs

    // ── Timeline selection state ───────────────────────────────────────────
    property string selectedVersionId: ""

    readonly property var selectedEntry: {
        for (let i = 0; i < root.timelineEntries.length; i++) {
            if (root.timelineEntries[i].id === root.selectedVersionId)
                return root.timelineEntries[i];
        }
        return null;
    }
    readonly property bool timelineSelectionEnabled: true
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
            // Commit mode (dev branch): full git-log-style history (newest first).
            // Commits ahead of the installed one are "available", the installed
            // commit itself is "current", and older commits are "past" — mirroring
            // how the version timeline treats releases.
            const commits = UpdateChecker.commits;
            const localHash = UpdateChecker.installedCommitHash;
            const localIdx = localHash !== "" ? commits.findIndex(c => c.fullHash === localHash) : -1;
            const result = [];
            for (let i = 0; i < commits.length; i++) {
                const c = commits[i];
                let state;
                if (localHash === "") {
                    // No installed commit on record: only mark the newest as current.
                    state = i === 0 ? "current" : "past";
                } else if (localIdx === -1) {
                    // Installed commit is older than the displayed window — every
                    // commit shown is ahead of it.
                    state = "available";
                } else if (i < localIdx) {
                    state = "available";
                } else if (i === localIdx) {
                    state = "current";
                } else {
                    state = "past";
                }
                result.push({
                    id: c.hash,
                    label: c.hash,
                    subject: c.subject || "",
                    state: state,
                    isMerge: !!c.isMerge,
                    author: c.author || "",
                    date: c.date || ""
                });
            }
            return result;
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
                                const target = root.selectedVersionId;
                                root.selectedVersionId = "";
                                UpdateChecker.startUpdate(target);
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
                                UpdateChecker.stopUpdate();
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
            fallbackText: UpdateChecker.currentBranch
            fallbackIcon: "call_split"
            onSelected: function(item) {
                root.selectedVersionId = "";
                UpdateChecker.checkUpdates(item.text);
            }
        }

        // 3 ── VERSION TIMELINE ────────────────────────────────────────────
        SectionHeader { text: qsTr("Version History") }

        ConnectedRect {
            id: timelineCard
            first: true
            last: true
            Layout.fillWidth: true
            // Dev branch can list up to ~150 commits — cap the card height and
            // let it scroll internally instead of pushing the log/actions
            // below it far down the page.
            readonly property real maxListHeight: 6 * 48
            implicitHeight: Math.min(timeline.implicitHeight, maxListHeight) + Tokens.padding.medium * 2

            Flickable {
                id: timelineFlickable
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Tokens.padding.medium
                }
                height: Math.min(timeline.implicitHeight, timelineCard.maxListHeight)
                contentWidth: width
                contentHeight: timeline.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                ScrollBar.vertical: StyledScrollBar {
                    flickable: timelineFlickable
                }

                UpdateTimeline {
                    id: timeline
                    width: parent.width
                    entries: root.timelineEntries
                    selectedId: root.timelineSelectionEnabled ? root.selectedVersionId : ""
                    onEntryClicked: function(entryId, entryState) {
                        if (root.updateRunning || !root.timelineSelectionEnabled) return;
                        // Toggle: click same dot to deselect
                        root.selectedVersionId = (root.selectedVersionId === entryId) ? "" : entryId;
                        UpdateChecker.targetVersion = "";
                    }
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
                        icon: UpdateChecker.logsExpanded ? "expand_less" : "expand_more"
                        onClicked: UpdateChecker.logsExpanded = !UpdateChecker.logsExpanded
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
                    visible: UpdateChecker.logsExpanded && (root.updateLogs !== "" || root.updateRunning)
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
        // Note: the actual update Process now lives on the UpdateChecker
        // singleton so it (and its progress/logs) survives this page being
        // destroyed/recreated on navigation. Only the one-off logout process
        // stays local since it doesn't need to persist.
        Process {
            id: logoutProcess
            command: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"]
        }
    }
}
