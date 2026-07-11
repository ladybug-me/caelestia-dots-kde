pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    function updateBranchItems() {
        let items = [];
        for (let i = 0; i < UpdateChecker.availableBranches.length; i++) {
            items.push(Qt.createQmlObject('import qs.components.controls; MenuItem { text: "' + UpdateChecker.availableBranches[i] + '"; icon: "call_split" }', root));
        }
        root.branchItems = items;
    }

    Item {
        visible: false
        Connections {
            target: UpdateChecker
            function onAvailableBranchesChanged() { root.updateBranchItems(); }
        }
    }
    
    Component.onCompleted: root.updateBranchItems();

    readonly property var activeBranchItem: branchItems.find(i => i.text === UpdateChecker.currentBranch) || branchItems[0]

    property string updateLogs: ""
    property bool updateRunning: false
    property real updateProgress: 0.0
    property string updateStatus: ""
    property bool logsExpanded: false

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
                        ? qsTr("%1 new commits on %2").arg(UpdateChecker.pendingCount).arg(UpdateChecker.currentBranch)
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
            last: true
            label: qsTr("Update branch")
            subtext: qsTr("Currently tracking branch: %1").arg(UpdateChecker.currentBranch)
            menuItems: root.branchItems
            active: root.activeBranchItem
            onSelected: item => {
                UpdateChecker.checkUpdates(item.text);
            }
        }

        SectionHeader {
            text: qsTr("Latest Changes")
            visible: UpdateChecker.commits.length > 0
        }

        Repeater {
            model: UpdateChecker.commits
            delegate: CommitRow {
                required property int index
                required property var modelData

                first: index === 0
                last: index === UpdateChecker.commits.length - 1
                hash: modelData.hash
                subject: modelData.subject
                author: modelData.author
                date: modelData.date
            }
        }

        SectionHeader {
            text: qsTr("Install Update")
            visible: UpdateChecker.hasUpdate || root.updateRunning || root.updateLogs !== ""
        }

        ConnectedRect {
            first: true
            last: true
            Layout.fillWidth: true
            visible: UpdateChecker.hasUpdate || root.updateRunning || root.updateLogs !== ""
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
                    text: root.updateRunning ? qsTr("Updating...") : (root.updateProgress === 1.0 ? qsTr("Log Out") : qsTr("Install Update"))
                    type: TextButton.Primary
                    icon: root.updateRunning ? "hourglass_empty" : (root.updateProgress === 1.0 ? "logout" : "system_update_alt")
                    enabled: (!root.updateRunning && UpdateChecker.hasUpdate) || root.updateProgress === 1.0
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
            command: ["bash", "-c", `${Paths.absolutePath("~/.local/bin/caelestia-update")} ${UpdateChecker.currentBranch}`]
            
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
    }
}
