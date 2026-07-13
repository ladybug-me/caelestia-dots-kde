pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
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

    property list<MenuItem> branchItems
    property list<MenuItem> versionItems
    property int versionChangesVisibleCount: 0
    property bool logsExpanded: false
    property bool advancedExpanded: false
    property bool updateRunning: false
    property real updateProgress: 0.0
    property string updateStatus: ""
    property string updateLogs: ""

    readonly property var activeBranchItem: branchItems.find(function(i) { return i.text === UpdateChecker.currentBranch; }) || branchItems[0]
    readonly property var activeVersionItem: versionItems.find(function(i) { return i.text === UpdateChecker.targetVersion; }) || versionItems[0]
    readonly property bool versionTargetDiffers: UpdateChecker.versionSummaryMode && UpdateChecker.targetVersion !== "" && UpdateChecker.targetVersion !== UpdateChecker.currentVersion
    readonly property bool canApplySelectedVersion: UpdateChecker.versionSummaryMode && UpdateChecker.targetVersion !== ""
    readonly property bool canInstallOrApply: UpdateChecker.hasUpdate || root.canApplySelectedVersion
    readonly property bool showInstallSection: root.canInstallOrApply || root.updateRunning || root.updateLogs !== "" || root.updateProgress === 1.0
    readonly property bool showVersionSummary: UpdateChecker.versionSummaryMode && UpdateChecker.currentVersion !== "unknown"
    readonly property int compactVersionLimit: 3
    readonly property bool hasVisibleVersionChanges: root.versionChangesVisibleCount > 0
    readonly property var visibleCommits: {
        if (!UpdateChecker.versionSummaryMode || root.versionChangesVisibleCount <= 0) {
            return [];
        }
        const count = Math.min(root.versionChangesVisibleCount, UpdateChecker.commits.length);
        if (count <= 0) {
            return [];
        }
        return UpdateChecker.commits.slice(0, count);
    }
    readonly property string versionChangesButtonText: {
        if (root.versionChangesVisibleCount <= 0)
            return qsTr("Show 3 version changes");
        if (root.versionChangesVisibleCount >= UpdateChecker.commits.length)
            return qsTr("Hide version changes");
        return qsTr("Show %1 more").arg(Math.min(compactVersionLimit, UpdateChecker.commits.length - root.versionChangesVisibleCount));
    }
    readonly property string versionChangesButtonIcon: {
        if (root.versionChangesVisibleCount <= 0)
            return "expand_more";
        if (root.versionChangesVisibleCount >= UpdateChecker.commits.length)
            return "expand_less";
        return "expand_more";
    }
    readonly property string versionChangesButtonStatus: {
        if (root.versionChangesVisibleCount <= 0)
            return qsTr("Collapsed");
        if (root.versionChangesVisibleCount >= UpdateChecker.commits.length)
            return qsTr("All visible");
        return qsTr("%1 of %2 visible").arg(root.versionChangesVisibleCount).arg(UpdateChecker.commits.length);
    }
    readonly property string updateActionText: {
        if (root.updateRunning)
            return qsTr("Updating...");
        if (root.updateProgress === 1.0)
            return qsTr("Log Out");
        if (root.canApplySelectedVersion)
            return root.versionTargetDiffers ? qsTr("Apply Version") : qsTr("Reinstall Current Version");
        return qsTr("Install Update");
    }
    readonly property string updateActionIcon: {
        if (root.updateRunning)
            return "hourglass_empty";
        if (root.updateProgress === 1.0)
            return "logout";
        return "system_update_alt";
    }

    property Component branchItemComp: Component {
        MenuItem {
            icon: "call_split"
        }
    }

    property Component versionItemComp: Component {
        MenuItem {
            icon: "history"
        }
    }

    function destroyMenuItems(items): void {
        if (!items)
            return;
        for (let i = 0; i < items.length; i++) {
            if (items[i])
                items[i].destroy();
        }
    }

    function updateBranchItems() {
        destroyMenuItems(root.branchItems);

        let items = [];
        for (let i = 0; i < UpdateChecker.availableBranches.length; i++) {
            const item = branchItemComp.createObject(root, {
                text: UpdateChecker.availableBranches[i]
            });
            items.push(item);
        }
        root.branchItems = items;
    }

    function updateVersionItems() {
        destroyMenuItems(root.versionItems);

        let items = [];
        for (let i = 0; i < UpdateChecker.availableVersions.length; i++) {
            const item = versionItemComp.createObject(root, {
                text: UpdateChecker.availableVersions[i]
            });
            items.push(item);
        }
        root.versionItems = items;
    }

    function revealVersionChanges(): void {
        if (UpdateChecker.commits.length <= 0)
            return;
        if (root.versionChangesVisibleCount <= 0) {
            root.versionChangesVisibleCount = Math.min(compactVersionLimit, UpdateChecker.commits.length);
        } else if (root.versionChangesVisibleCount < UpdateChecker.commits.length) {
            root.versionChangesVisibleCount = Math.min(root.versionChangesVisibleCount + compactVersionLimit, UpdateChecker.commits.length);
        } else {
            root.versionChangesVisibleCount = 0;
        }
    }

    Item {
        visible: false
        Connections {
            target: UpdateChecker
            function onAvailableBranchesChanged() { root.updateBranchItems(); }
            function onAvailableVersionsChanged() { root.updateVersionItems(); }
            function onCommitsChanged() {
                root.versionChangesVisibleCount = 0;
                if (UpdateChecker.commits.length === 0)
                    root.logsExpanded = false;
            }
            function onVersionSummaryModeChanged() { root.versionChangesVisibleCount = 0; }
        }
    }
    
    Component.onCompleted: {
        root.updateBranchItems();
        root.updateVersionItems();
    }

    Item {
        Settings {
            id: updaterSettings
            category: "Updater"
            property bool deployConfigs: true
            property bool buildShell: true
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.medium

        // Status hero
        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: heroLayout.implicitHeight + Tokens.padding.largeIncreased * 2

            ColumnLayout {
                id: heroLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: UpdateChecker.hasUpdate ? "update" : "check_circle"
                    color: UpdateChecker.hasUpdate ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: UpdateChecker.hasUpdate 
                        ? (UpdateChecker.versionSummaryMode
                            ? qsTr("Version update available on %1").arg(UpdateChecker.currentBranch)
                            : qsTr("%1 new commits on %2").arg(UpdateChecker.pendingCount).arg(UpdateChecker.currentBranch))
                        : qsTr("You're all caught up!")
                    color: UpdateChecker.hasUpdate ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                    font: Tokens.font.title.medium
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.showVersionSummary
                    text: qsTr("Current: %1 • Latest: %2").arg(UpdateChecker.currentVersion).arg(UpdateChecker.latestVersion)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        IconTextButton {
            Layout.alignment: Qt.AlignHCenter
            visible: !UpdateChecker.hasUpdate && !root.updateRunning
            text: qsTr("Check again")
            type: TextButton.Tonal
            icon: "refresh"
            onClicked: function() { UpdateChecker.checkUpdates(); }
        }

        SectionHeader {
            text: qsTr("Update source")
        }

        SelectRow {
            first: true
            last: !UpdateChecker.versionSummaryMode
            label: qsTr("Update branch")
            subtext: qsTr("Currently tracking branch: %1").arg(UpdateChecker.currentBranch)
            menuItems: root.branchItems
            active: root.activeBranchItem
            onSelected: function(item) {
                UpdateChecker.checkUpdates(item.text);
            }
        }

        SelectRow {
            first: !UpdateChecker.versionSummaryMode
            last: true
            visible: UpdateChecker.versionSummaryMode
            label: qsTr("Target version")
            subtext: qsTr("Current: %1  |  Latest: %2").arg(UpdateChecker.currentVersion).arg(UpdateChecker.latestVersion)
            menuItems: root.versionItems
            active: root.activeVersionItem
            onSelected: function(item) {
                UpdateChecker.targetVersion = item.text;
            }
        }

        SectionHeader {
            text: UpdateChecker.versionSummaryMode ? qsTr("Version Changes") : qsTr("Latest Changes")
            visible: UpdateChecker.commits.length > 0
        }

        IconTextButton {
            Layout.alignment: Qt.AlignHCenter
            visible: UpdateChecker.commits.length > 0
            text: root.versionChangesButtonText
            type: TextButton.Tonal
            icon: root.versionChangesButtonIcon
            onClicked: function() { root.revealVersionChanges(); }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: UpdateChecker.commits.length > 0
            text: root.versionChangesButtonStatus
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            visible: root.hasVisibleVersionChanges
            model: root.visibleCommits
            delegate: CommitRow {
                required property int index
                required property var modelData

                first: index === 0
                last: index === root.visibleCommits.length - 1
                hash: modelData.hash
                subject: modelData.subject
                author: modelData.author
                date: modelData.date
                details: root.versionChangesVisibleCount >= UpdateChecker.commits.length ? (modelData.details || "") : ""
                detailsMaxLines: root.versionChangesVisibleCount >= UpdateChecker.commits.length ? 8 : 2
            }
        }

        SectionHeader {
            text: qsTr("Install Update")
            visible: root.showInstallSection
        }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            visible: root.showInstallSection
            implicitHeight: logsContainer.implicitHeight + Tokens.padding.largeIncreased * 2

            ColumnLayout {
                id: logsContainer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                IconTextButton {
                    Layout.fillWidth: true
                    text: root.updateActionText
                    type: TextButton.Primary
                    icon: root.updateActionIcon
                    enabled: (!root.updateRunning && root.canInstallOrApply) || root.updateProgress === 1.0
                    onClicked: function() {
                        if (root.updateProgress === 1.0) {
                            logoutProcess.running = true;
                        } else {
                            root.updateLogs = "";
                            root.updateProgress = 0.0;
                            root.updateStatus = qsTr("Starting update...");
                            root.updateRunning = true;
                            root.logsExpanded = false;
                            updateProcess.running = true;
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.updateRunning || root.updateLogs !== ""
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: root.updateStatus
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }
                        IconButton {
                            icon: root.logsExpanded ? "expand_less" : "expand_more"
                            onClicked: function() { root.logsExpanded = !root.logsExpanded; }
                        }
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        value: root.updateProgress
                        visible: root.updateRunning || root.updateProgress > 0
                        indeterminate: root.updateProgress === 0.0 && root.updateRunning
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 280
                    visible: root.logsExpanded && (root.updateLogs !== "" || root.updateRunning)
                    color: Colours.tPalette.m3surfaceContainerLowest
                    radius: Tokens.rounding.small
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        contentHeight: logText.implicitHeight
                        contentWidth: width

                        onContentHeightChanged: function() {
                            if (contentHeight > height && (contentY + height >= contentHeight - Tokens.padding.large)) {
                                contentY = contentHeight - height;
                            }
                        }

                        StyledText {
                            id: logText
                            width: parent.width
                            text: root.updateLogs
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        SectionHeader {
            text: qsTr("More options")
        }

        IconTextButton {
            Layout.alignment: Qt.AlignHCenter
            text: root.advancedExpanded ? qsTr("Hide advanced options") : qsTr("Show advanced options")
            icon: root.advancedExpanded ? "expand_less" : "expand_more"
            type: TextButton.Tonal
            onClicked: function() { root.advancedExpanded = !root.advancedExpanded; }
        }

        NavRow {
            first: true
            visible: root.advancedExpanded
            icon: "folder"
            label: qsTr("Open Backup Folder")
            status: qsTr("View your previously backed-up configuration files")
            onClicked: function() {
                backupFolderProcess.running = true;
            }
        }

        ToggleRow {
            visible: root.advancedExpanded
            text: qsTr("Deploy Configurations")
            subtext: qsTr("Update your custom dotfiles in ~/.config")
            checked: updaterSettings.deployConfigs
            onToggled: function(checked) {
                if (checked && !updaterSettings.deployConfigs) {
                    deployConfigsConfirm.open();
                    return;
                }
                updaterSettings.deployConfigs = checked;
            }
        }

        ToggleRow {
            last: true
            visible: root.advancedExpanded
            text: qsTr("Build Shell UI")
            subtext: qsTr("Compile and install Quickshell UI updates")
            checked: updaterSettings.buildShell
            onToggled: function(checked) { updaterSettings.buildShell = checked; }
        }

        QQC2.Popup {
            id: deployConfigsConfirm

            parent: root
            modal: true
            focus: true
            closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
            width: Math.min(root.width - Tokens.padding.largeIncreased * 2, 420)
            height: confirmContent.implicitHeight + padding * 2
            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            padding: Tokens.padding.largeIncreased

            background: StyledRect {
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh
            }

            contentItem: ColumnLayout {
                id: confirmContent

                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Enable config deployment?")
                    font: Tokens.font.title.small
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("This can overwrite files in ~/.config. Continue only if you want the updater to deploy configuration files.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: qsTr("Cancel")
                        type: TextButton.Tonal
                        onClicked: function() { deployConfigsConfirm.close(); }
                    }

                    TextButton {
                        text: qsTr("Enable")
                        type: TextButton.Primary
                        onClicked: function() {
                            updaterSettings.deployConfigs = true;
                            deployConfigsConfirm.close();
                        }
                    }
                }
            }
        }

        Process {
            id: updateProcess
            command: [Paths.absolutePath("~/.local/bin/caelestia-update"), UpdateChecker.currentBranch]
                .concat(UpdateChecker.versionSummaryMode && UpdateChecker.targetVersion !== "" ? [UpdateChecker.targetVersion] : [])
            environment: ({
                    CAELESTIA_SKIP_DEPLOY: updaterSettings.deployConfigs ? "0" : "1",
                    CAELESTIA_SKIP_BUILD: updaterSettings.buildShell ? "0" : "1"
                })
            
            stdout: SplitParser {
                onRead: function(text) {
                    root.updateLogs += text + "\n";
                    if (text.startsWith("PROGRESS: ")) {
                        const pText = text.substring(10);
                        if (pText.startsWith("done")) {
                            root.updateProgress = 1.0;
                            root.updateStatus = qsTr("Done!");
                        } else {
                            const match = pText.match(/^(\d+)\/(\d+): (.+)$/);
                            if (match) {
                                root.updateProgress = parseInt(match[1]) / parseInt(match[2]);
                                root.updateStatus = match[3];
                            }
                        }
                    }
                }
            }
            stderr: SplitParser {
                onRead: function(text) {
                    root.updateLogs += text + "\n";
                }
            }
            
            onExited: function(code) {
                root.updateRunning = false;
                if (code === 0) {
                    Toaster.toast(qsTr("Update Successful"), qsTr("The update is complete. Please log out to apply changes."), "done");
                    UpdateChecker.reload();
                } else {
                    Toaster.toast(qsTr("Update Failed"), qsTr("The update script returned error code %1").arg(code), "error");
                }
            }
        }

        Process {
            id: logoutProcess
            command: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"]
        }
        
        Process {
            id: backupFolderProcess
            command: GlobalConfig.general.apps.explorer.concat([Paths.absolutePath("~/.config/caelestia-update/backups")])
        }
    }
}
