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
                for (let i = 0; i < Config.bar.entries.length; i++) {
                    if (Config.bar.entries[i].id === "activeWindow")
                        return Config.bar.entries[i].enabled;
                }
                return false;
            }
            onToggled: {
                let currentEntries = GlobalConfig.bar.entries;
                let newEntries = [
                    { "id": "logo", "enabled": true },
                    { "id": "workspaces", "enabled": true },
                    { "id": "spacer", "enabled": true },
                    { "id": "activeWindow", "enabled": true },
                    { "id": "dock", "enabled": false },
                    { "id": "spacer", "enabled": true },
                    { "id": "tray", "enabled": true },
                    { "id": "github", "enabled": true },
                    { "id": "clock", "enabled": true },
                    { "id": "statusIcons", "enabled": true },
                    { "id": "power", "enabled": true }
                ];
                for (let i = 0; i < newEntries.length; i++) {
                    if (newEntries[i].id === "activeWindow") {
                        newEntries[i].enabled = checked;
                    } else if (newEntries[i].id !== "spacer") {
                        let existing = currentEntries.find(e => e.id === newEntries[i].id);
                        if (existing !== undefined) newEntries[i].enabled = existing.enabled;
                    }
                }
                GlobalConfig.bar.entries = newEntries;
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Compact")
            checked: Config.bar.activeWindow.compact
            onToggled: GlobalConfig.bar.activeWindow.compact = checked
        }

        ToggleRow {
            text: qsTr("Inverted")
            checked: Config.bar.activeWindow.inverted
            onToggled: GlobalConfig.bar.activeWindow.inverted = checked
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Only show the active window title while hovering")
            checked: Config.bar.activeWindow.showOnHover
            onToggled: GlobalConfig.bar.activeWindow.showOnHover = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a window details popout when hovering")
            checked: Config.bar.popouts.activeWindow
            onToggled: GlobalConfig.bar.popouts.activeWindow = checked
        }
    }
}
