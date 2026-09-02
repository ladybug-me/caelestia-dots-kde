pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    readonly property bool indicatorEnabled: {
        const entries = GlobalConfig.bar.entries || [];
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === "updateIndicator" && entries[i].enabled)
                return true;
        }
        return false;
    }

    title: I18n.tr("Updates")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: I18n.tr("Show update indicator")
            subtext: I18n.tr("Always-visible icon in the taskbar that changes when a Caelestia update is available")
            checked: root.indicatorEnabled
            onToggled: {
                const entries = GlobalConfig.bar.entries ? [...GlobalConfig.bar.entries] : [];
                const idx = entries.findIndex(e => e.id === "updateIndicator");
                if (idx >= 0)
                    entries[idx] = { id: "updateIndicator", enabled: checked, zone: entries[idx].zone || "right" };
                else
                    entries.push({ id: "updateIndicator", enabled: checked, zone: "right" });
                GlobalConfig.bar.entries = entries;
            }
        }

        ToggleRow {
            last: true
            text: I18n.tr("Enable update checking")
            subtext: I18n.tr("Enables the update indicator and periodic checks (every 30 minutes)")
            checked: GlobalConfig.general.checkUpdates
            onToggled: GlobalConfig.general.checkUpdates = checked
        }
    }
}
