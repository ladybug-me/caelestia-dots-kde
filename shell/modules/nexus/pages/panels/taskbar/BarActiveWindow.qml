pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Active window")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Enable component")
            checked: {
                for (let i = 0; i < root.nState.targetConfig.bar.entries.length; i++) {
                    if (root.nState.targetConfig.bar.entries[i].id === "activeWindow")
                        return root.nState.targetConfig.bar.entries[i].enabled;
                }
                return false;
            }
            onToggled: {
                let newEntries = [...Globalroot.nState.targetConfig.bar.entries];
                let found = false;
                for (let i = 0; i < newEntries.length; i++) {
                    if (newEntries[i].id === "activeWindow") {
                        newEntries[i].enabled = checked;
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    newEntries.push({ id: "activeWindow", enabled: checked, zone: "left" });
                }

                Globalroot.nState.targetConfig.bar.entries = newEntries;
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Compact")
            checked: root.nState.targetConfig.bar.activeWindow.compact
            onToggled: Globalroot.nState.targetConfig.bar.activeWindow.compact = checked
        }

        ToggleRow {
            text: qsTr("Inverted")
            checked: root.nState.targetConfig.bar.activeWindow.inverted
            onToggled: Globalroot.nState.targetConfig.bar.activeWindow.inverted = checked
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Only show the active window title while hovering")
            checked: root.nState.targetConfig.bar.activeWindow.showOnHover
            onToggled: Globalroot.nState.targetConfig.bar.activeWindow.showOnHover = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a window details popout when hovering")
            checked: root.nState.targetConfig.bar.popouts.activeWindow
            onToggled: Globalroot.nState.targetConfig.bar.popouts.activeWindow = checked
        }
    }
}
