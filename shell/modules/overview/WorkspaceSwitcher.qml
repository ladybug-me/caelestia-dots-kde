pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    readonly property int workspaceCount: {
        if (typeof KWinWorkspaceState !== "undefined" && KWinWorkspaceState.workspaces.length > 0) {
            return KWinWorkspaceState.workspaces.length;
        }
        return 1;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            
            StyledText {
                Layout.fillWidth: true
                text: "Overview"
                font: Tokens.font.title.large
                color: Colours.palette.m3onSurface
            }
            
            IconTextButton {
                text: "Add Workspace"
                icon: "add"
                type: TextButton.Filled
                onClicked: {
                    if (typeof KWinActiveWindowBridge !== "undefined") {
                        KWinActiveWindowBridge.runArbitraryScript(`
                            let d = workspace.desktops;
                            workspace.createDesktop(d.length, "Desktop " + (d.length + 1));
                        `);
                    }
                }
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.preferredHeight: 250
            orientation: ListView.Horizontal
            spacing: Tokens.spacing.large
            model: root.workspaceCount

            delegate: WorkspaceItem {
                required property int index
                wsId: index + 1
                list: listView
            }
        }

        ActiveWorkspaceWindows {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
