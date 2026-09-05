pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property bool indicatorEnabled: {
        const entries = Globalroot.nState.targetConfig.bar.entries || [];
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === "updateIndicator" && entries[i].enabled)
                return true;
        }
        return false;
    }

    title: qsTr("Updates")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Show update indicator")
            subtext: qsTr("Always-visible icon in the taskbar that changes when a Caelestia update is available")
            checked: root.indicatorEnabled
            onToggled: {
                const entries = Globalroot.nState.targetConfig.bar.entries ? [...Globalroot.nState.targetConfig.bar.entries] : [];
                const idx = entries.findIndex(e => e.id === "updateIndicator");
                if (idx >= 0)
                    entries[idx] = { id: "updateIndicator", enabled: checked, zone: entries[idx].zone || "right" };
                else
                    entries.push({ id: "updateIndicator", enabled: checked, zone: "right" });
                Globalroot.nState.targetConfig.bar.entries = entries;
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Enable update checking")
            subtext: qsTr("Enables the update indicator and periodic checks (every 30 minutes)")
            checked: Globalroot.nState.targetConfig.general.checkUpdates
            onToggled: Globalroot.nState.targetConfig.general.checkUpdates = checked
        }
    }
}
