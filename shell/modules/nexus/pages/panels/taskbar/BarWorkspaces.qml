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
                if (len > 0 && GlobalConfig.bar.workspaces.shown !== len) {
                    GlobalConfig.bar.workspaces.shown = len;
                }
            }
        }

        Component.onCompleted: {
            if (typeof KWinWorkspaceState !== "undefined") {
                let len = KWinWorkspaceState.workspaces.length;
                if (len > 0 && GlobalConfig.bar.workspaces.shown !== len) {
                    GlobalConfig.bar.workspaces.shown = len;
                }
            }
        }

        StepperRow {
            first: true
            label: qsTr("Shown")
            subtext: qsTr("Number of workspaces displayed")
            value: Config.bar.workspaces.shown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => {
                GlobalConfig.bar.workspaces.shown = v;
                if (typeof KWinActiveWindowBridge !== "undefined") {
                    KWinActiveWindowBridge.runArbitraryScript(`
                        let target = ${v};
                        let d = workspace.desktops;
                        let count = d.length;
                        while (count < target) {
                            workspace.createDesktop(count, "Desktop " + (count + 1));
                            count++;
                        }
                        while (count > target) {
                            workspace.removeDesktop(d[count - 1]);
                            count--;
                        }
                    `);
                }
            }
        }

        ToggleRow {
            text: qsTr("Active indicator")
            checked: Config.bar.workspaces.activeIndicator
            onToggled: GlobalConfig.bar.workspaces.activeIndicator = checked
        }

        ToggleRow {
            text: qsTr("Active trail")
            checked: Config.bar.workspaces.activeTrail
            onToggled: GlobalConfig.bar.workspaces.activeTrail = checked
        }

        ToggleRow {
            text: qsTr("Occupied background")
            checked: Config.bar.workspaces.occupiedBg
            onToggled: GlobalConfig.bar.workspaces.occupiedBg = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Use material icons for indicators")
            checked: Config.bar.workspaces.useIcon
            onToggled: GlobalConfig.bar.workspaces.useIcon = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show windows")
            subtext: qsTr("Show icons of open windows on each workspace")
            checked: Config.bar.workspaces.showWindows
            onToggled: GlobalConfig.bar.workspaces.showWindows = checked
        }

        ToggleRow {
            text: qsTr("Windows on special workspaces")
            checked: Config.bar.workspaces.showWindowsOnSpecialWorkspaces
            onToggled: GlobalConfig.bar.workspaces.showWindowsOnSpecialWorkspaces = checked
        }

        StepperRow {
            label: qsTr("Max window icons")
            value: Config.bar.workspaces.maxWindowIcons
            from: 0
            to: 20
            stepSize: 1
            onMoved: v => GlobalConfig.bar.workspaces.maxWindowIcons = v
        }



        ToggleRow {
            last: true
            text: qsTr("Per-monitor workspaces")
            subtext: qsTr("Show each monitor's workspaces independently")
            checked: GlobalConfig.bar.workspaces.perMonitorWorkspaces
            onToggled: GlobalConfig.bar.workspaces.perMonitorWorkspaces = checked
        }
    }
}
