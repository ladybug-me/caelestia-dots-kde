pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Show desktop")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            Layout.fillWidth: true
            first: true
            last: true
            text: qsTr("Enable component")
            subtext: qsTr("Add a button that minimizes all windows to reveal the desktop")
            checked: {
                for (let i = 0; i < Config.bar.entries.length; i++) {
                    if (Config.bar.entries[i].id === "showDesktop")
                        return Config.bar.entries[i].enabled;
                }
                return false;
            }
            onToggled: {
                let newEntries = [...GlobalConfig.bar.entries];
                let found = false;
                for (let i = 0; i < newEntries.length; i++) {
                    if (newEntries[i].id === "showDesktop") {
                        newEntries[i].enabled = checked;
                        if (!newEntries[i].zone)
                            newEntries[i].zone = "right";
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    newEntries.push({ id: "showDesktop", enabled: checked, zone: "right" });
                }

                GlobalConfig.bar.entries = newEntries;
            }
        }
    }
}