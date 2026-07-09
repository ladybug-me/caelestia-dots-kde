pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Dock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Enable component")
            checked: {
                for (let i = 0; i < Config.bar.entries.length; i++) {
                    if (Config.bar.entries[i].id === "dock")
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
                    if (newEntries[i].id === "dock") {
                        newEntries[i].enabled = checked;
                    } else if (newEntries[i].id !== "spacer") {
                        let existing = currentEntries.find(e => e.id === newEntries[i].id);
                        if (existing !== undefined) newEntries[i].enabled = existing.enabled;
                    }
                }
                GlobalConfig.bar.entries = newEntries;
            }
        }



        StepperRow {
            Layout.fillWidth: true
            label: qsTr("Icon size")
            subtext: qsTr("Size of app icons in the dock")
            value: Config.bar.dock.iconSize
            from: 20
            to: Math.max(20, Tokens.sizes.bar.innerWidth)
            stepSize: 2
            onMoved: v => GlobalConfig.bar.dock.iconSize = v
        }



        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: Strings.localizeEnglishSpelling(qsTr("Recolour icons"))
            subtext: Strings.localizeEnglishSpelling(qsTr("Recolour application icons using the system theme"))
            checked: Config.bar.dock.recolourIcons
            onToggled: GlobalConfig.bar.dock.recolourIcons = checked
        }
    }
}
