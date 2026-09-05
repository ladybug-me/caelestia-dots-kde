pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Workspaces")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            target: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState : null

            function onWorkspacesChanged() {
                let len = KWinWorkspaceState.workspaces.length;
                if (len > 0 && Globalroot.nState.targetConfig.bar.workspaces.shown !== len) {
                    Globalroot.nState.targetConfig.bar.workspaces.shown = len;
                }
            }
        }

        Component.onCompleted: {
            if (typeof KWinWorkspaceState !== "undefined") {
                let len = KWinWorkspaceState.workspaces.length;
                if (len > 0 && Globalroot.nState.targetConfig.bar.workspaces.shown !== len) {
                    Globalroot.nState.targetConfig.bar.workspaces.shown = len;
                }
            }
        }

        StepperRow {
            first: true
            label: qsTr("Shown")
            subtext: qsTr("Number of workspaces displayed")
            value: root.nState.targetConfig.bar.workspaces.shown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => {
                Globalroot.nState.targetConfig.bar.workspaces.shown = v;
                if (typeof KWinWorkspaceState !== "undefined") {
                    let d = KWinWorkspaceState.workspaces;
                    let count = d.length;
                    while (count < v) {
                        KWinWorkspaceState.createWorkspace("Desktop " + (count + 1));
                        count++;
                    }
                    while (count > v) {
                        KWinWorkspaceState.removeWorkspace(d[count - 1].id);
                        count--;
                    }
                }
            }
        }

        ToggleRow {
            text: qsTr("Active indicator")
            checked: root.nState.targetConfig.bar.workspaces.activeIndicator
            onToggled: Globalroot.nState.targetConfig.bar.workspaces.activeIndicator = checked
        }

        ToggleRow {
            text: qsTr("Active trail")
            checked: root.nState.targetConfig.bar.workspaces.activeTrail
            onToggled: Globalroot.nState.targetConfig.bar.workspaces.activeTrail = checked
        }

        ToggleRow {
            text: qsTr("Occupied background")
            checked: root.nState.targetConfig.bar.workspaces.occupiedBg
            onToggled: Globalroot.nState.targetConfig.bar.workspaces.occupiedBg = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Use material icons for indicators")
            checked: root.nState.targetConfig.bar.workspaces.useIcon
            onToggled: Globalroot.nState.targetConfig.bar.workspaces.useIcon = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show windows")
            subtext: qsTr("Show icons of open windows on each workspace")
            checked: root.nState.targetConfig.bar.workspaces.showWindows
            onToggled: Globalroot.nState.targetConfig.bar.workspaces.showWindows = checked
        }

        ToggleRow {
            text: qsTr("Windows on special workspaces")
            checked: root.nState.targetConfig.bar.workspaces.showWindowsOnSpecialWorkspaces
            onToggled: Globalroot.nState.targetConfig.bar.workspaces.showWindowsOnSpecialWorkspaces = checked
        }

        StepperRow {
            label: qsTr("Max window icons")
            value: root.nState.targetConfig.bar.workspaces.maxWindowIcons
            from: 0
            to: 20
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.bar.workspaces.maxWindowIcons = v
        }



        ToggleRow {
            last: true
            text: qsTr("Per-monitor workspaces")
            subtext: qsTr("Show each monitor's workspaces independently")
            checked: Globalroot.nState.targetConfig.bar.workspaces.perMonitorWorkspaces
            onToggled: Globalroot.nState.targetConfig.bar.workspaces.perMonitorWorkspaces = checked
        }
    }
}
