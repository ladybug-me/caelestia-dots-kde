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

    property list<MenuItem> branchItems
    property list<MenuItem> versionItems

    function updateBranchItems() {
        if (root.branchItems) {
            for (let i = 0; i < root.branchItems.length; i++) {
                root.branchItems[i].destroy();
            }
        }
        let items = [];
        for (let i = 0; i < UpdateChecker.availableBranches.length; i++) {
            items.push(Qt.createQmlObject('import qs.components.controls; MenuItem { text: "' + UpdateChecker.availableBranches[i] + '"; icon: "call_split" }', root));
        }
        root.branchItems = items;
    }

    function updateVersionItems() {
        if (root.versionItems) {
            for (let i = 0; i < root.versionItems.length; i++) {
                root.versionItems[i].destroy();
            }
        }
        let items = [];
        for (let i = 0; i < UpdateChecker.availableVersions.length; i++) {
            const item = Qt.createQmlObject(
                'import qs.components.controls; MenuItem { text: "' + UpdateChecker.availableVersions[i] + '"; icon: "history" }',
                root
            );
            items.push(item);
        }
        root.versionItems = items;
    }

    Item {
        visible: false
        Connections {
            target: UpdateChecker
            function onAvailableBranchesChanged() { root.updateBranchItems(); }
            function onAvailableVersionsChanged() { root.updateVersionItems(); }
            function onCommitsChanged() { root.showAllVersionChanges = false; }
            function onVersionSummaryModeChanged() { root.showAllVersionChanges = false; }
        }
    }
    
    Component.onCompleted: {
        root.updateBranchItems();
        root.updateVersionItems();
    }

    readonly property var activeBranchItem: branchItems.find(i => i.text === UpdateChecker.currentBranch) || branchItems[0]
    readonly property var activeVersionItem: versionItems.find(i => i.text === UpdateChecker.targetVersion) || versionItems[0]
    readonly property bool versionTargetDiffers: UpdateChecker.versionSummaryMode && UpdateChecker.targetVersion !== "" && UpdateChecker.targetVersion !== UpdateChecker.currentVersion
    readonly property bool canApplySelectedVersion: UpdateChecker.versionSummaryMode && UpdateChecker.targetVersion !== ""
    readonly property int compactVersionLimit: 3
    readonly property bool hasHiddenVersionChanges: UpdateChecker.versionSummaryMode && UpdateChecker.commits.length > compactVersionLimit
    readonly property int hiddenVersionCount: Math.max(0, UpdateChecker.commits.length - compactVersionLimit)
    readonly property var visibleCommits: {
        if (!UpdateChecker.versionSummaryMode || root.showAllVersionChanges) {
            return UpdateChecker.commits;
        }
        return UpdateChecker.commits.slice(0, compactVersionLimit);
    }

    property string updateLogs: ""
    property bool updateRunning: false
    property real updateProgress: 0.0
    property string updateStatus: ""
    property bool logsExpanded: false
    property bool showAllVersionChanges: false

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
        spacing: Tokens.spacing.extraSmall / 2

        // Status Banner
        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.extraLarge * 4

            ColumnLayout {
                anchors.centerIn: parent
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
                }
                
                IconTextButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !UpdateChecker.hasUpdate
                    text: qsTr("Check again")
                    type: TextButton.Tonal
                    icon: "refresh"
                    onClicked: UpdateChecker.checkUpdates()
                }
            }
        }

        SectionHeader {
            text: qsTr("Options")
        }

        SelectRow {
            first: true
            last: !UpdateChecker.versionSummaryMode
            label: qsTr("Update branch")
            subtext: qsTr("Currently tracking branch: %1").arg(UpdateChecker.currentBranch)
            menuItems: root.branchItems
            active: root.activeBranchItem
            onSelected: item => {
                UpdateChecker.checkUpdates(item.text);
            }
        }

        SelectRow {
            first: !UpdateChecker.versionSummaryMode
            last: true
            visible: UpdateChecker.versionSummaryMode
            label: qsTr("Target version")
            subtext: qsTr("Current: %1  |  Previous: %2").arg(UpdateChecker.currentVersion).arg(UpdateChecker.previousVersion)
            menuItems: root.versionItems
            active: root.activeVersionItem
            onSelected: item => {
                UpdateChecker.targetVersion = item.text;
            }
        }

        SectionHeader {
            text: UpdateChecker.versionSummaryMode ? qsTr("Version Changes") : qsTr("Latest Changes")
            visible: UpdateChecker.commits.length > 0
        }

        Repeater {
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
                details: modelData.details || ""
            }
        }

        IconTextButton {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hasHiddenVersionChanges || root.showAllVersionChanges
            text: root.showAllVersionChanges
                ? qsTr("Show latest 3")
                : qsTr("Show %1 older versions").arg(root.hiddenVersionCount)
            type: TextButton.Tonal
            icon: root.showAllVersionChanges ? "expand_less" : "expand_more"
            onClicked: root.showAllVersionChanges = !root.showAllVersionChanges
        }

        SectionHeader {
            text: qsTr("Customize Installation")
        }

        NavRow {
            first: true
            icon: "folder"
            label: qsTr("Open Backup Folder")
            status: qsTr("View your previously backed-up configuration files")
            onClicked: {
                backupFolderProcess.running = true;
            }
        }

        ToggleRow {
            text: qsTr("Deploy Configurations")
            subtext: qsTr("Update your custom dotfiles in ~/.config")
            checked: updaterSettings.deployConfigs
            onToggled: updaterSettings.deployConfigs = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Build Shell UI")
            subtext: qsTr("Compile and install Quickshell UI updates")
            checked: updaterSettings.buildShell
            onToggled: updaterSettings.buildShell = checked
        }

        SectionHeader {
            text: qsTr("Install Update")
            visible: UpdateChecker.hasUpdate || root.canApplySelectedVersion || root.updateRunning || root.updateLogs !== ""
        }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            visible: UpdateChecker.hasUpdate || root.canApplySelectedVersion || root.updateRunning || root.updateLogs !== ""
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
                    text: root.updateRunning ? qsTr("Updating...") : (root.updateProgress === 1.0 ? qsTr("Log Out") : (root.canApplySelectedVersion ? (root.versionTargetDiffers ? qsTr("Apply Version") : qsTr("Reinstall Current Version")) : qsTr("Install Update")))
                    type: TextButton.Primary
                    icon: root.updateRunning ? "hourglass_empty" : (root.updateProgress === 1.0 ? "logout" : "system_update_alt")
                    enabled: (!root.updateRunning && (UpdateChecker.hasUpdate || root.canApplySelectedVersion)) || root.updateProgress === 1.0
                    onClicked: {
                        if (root.updateProgress === 1.0) {
                            logoutProcess.running = true;
                        } else {
                            root.updateLogs = "";
                            root.updateProgress = 0.0;
                            root.updateStatus = "Starting update...";
                            root.updateRunning = true;
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
                        }
                        IconButton {
                            icon: root.logsExpanded ? "expand_less" : "expand_more"
                            onClicked: root.logsExpanded = !root.logsExpanded
                        }
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        value: root.updateProgress
                        visible: !root.indeterminate
                        indeterminate: root.updateProgress === 0.0 && root.updateRunning
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 250
                    visible: root.logsExpanded && (root.updateLogs !== "" || root.updateRunning)
                    color: Colours.tPalette.m3surfaceContainerLowest
                    radius: Tokens.rounding.small
                    clip: true

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        contentHeight: logText.implicitHeight
                        contentWidth: width

                        onContentHeightChanged: {
                            if (contentHeight > height) {
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
        Process {
            id: updateProcess
            command: [Paths.absolutePath("~/.local/bin/caelestia-update"), UpdateChecker.currentBranch]
                .concat(UpdateChecker.versionSummaryMode && UpdateChecker.targetVersion !== "" ? [UpdateChecker.targetVersion] : [])
            environment: ({
                    CAELESTIA_SKIP_DEPLOY: updaterSettings.deployConfigs ? "0" : "1",
                    CAELESTIA_SKIP_BUILD: updaterSettings.buildShell ? "0" : "1"
                })
            
            stdout: SplitParser {
                onRead: text => {
                    root.updateLogs += text + "\n";
                    if (text.startsWith("PROGRESS: ")) {
                        const pText = text.substring(10);
                        if (pText.startsWith("done")) {
                            root.updateProgress = 1.0;
                            root.updateStatus = "Done!";
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
                onRead: text => {
                    root.updateLogs += text + "\n";
                }
            }
            
            onExited: code => {
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
