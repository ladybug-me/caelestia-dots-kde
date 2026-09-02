pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Active window")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: I18n.tr("Enable component")
            checked: {
                for (let i = 0; i < Config.bar.entries.length; i++) {
                    if (Config.bar.entries[i].id === "activeWindow")
                        return Config.bar.entries[i].enabled;
                }
                return false;
            }
            onToggled: {
                let newEntries = [...GlobalConfig.bar.entries];
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

                GlobalConfig.bar.entries = newEntries;
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: I18n.tr("Compact")
            checked: Config.bar.activeWindow.compact
            onToggled: GlobalConfig.bar.activeWindow.compact = checked
        }

        ToggleRow {
            text: I18n.tr("Inverted")
            checked: Config.bar.activeWindow.inverted
            onToggled: GlobalConfig.bar.activeWindow.inverted = checked
        }

        ToggleRow {
            text: I18n.tr("Show on hover")
            subtext: I18n.tr("Only show the active window title while hovering")
            checked: Config.bar.activeWindow.showOnHover
            onToggled: GlobalConfig.bar.activeWindow.showOnHover = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Popout on hover")
            subtext: I18n.tr("Show a window details popout when hovering")
            checked: Config.bar.popouts.activeWindow
            onToggled: GlobalConfig.bar.popouts.activeWindow = checked
        }
    }
}
