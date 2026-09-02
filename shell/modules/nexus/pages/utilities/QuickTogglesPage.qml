pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.utils
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    readonly property var connectivityToggles: [
        { id: "wifi", label: I18n.tr("Wi-Fi") },
        { id: "bluetooth", label: I18n.tr("Bluetooth") },
        { id: "vpn", label: I18n.tr("VPN") },
    ]
    readonly property var toolToggles: [
        { id: "settings", label: I18n.tr("Settings") },
        { id: "colorpicker", label: Strings.localizeEnglishSpelling(I18n.tr("Colour Picker")) },
        { id: "wallpaper", label: I18n.tr("Wallpaper") },
        { id: "badapple", label: I18n.tr("Bad Apple") },
    ]
    readonly property var systemToggles: [
        { id: "mic", label: I18n.tr("Microphone") },
        { id: "dnd", label: I18n.tr("Do Not Disturb") },
        { id: "pauseWallpaper", label: I18n.tr("Pause Wallpaper") },
        { id: "nightlight", label: I18n.tr("Night Light") },
        { id: "restartShell", label: I18n.tr("Restart Shell") },
    ]

    title: I18n.tr("Quick toggles")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Connectivity")
        }

        Repeater {
            id: connectivityRepeater

            model: root.connectivityToggles

            delegate: QuickToggleRow {
                first: index === 0
                last: index === connectivityRepeater.count - 1
            }
        }

        SectionHeader {
            text: I18n.tr("Tools")
        }

        Repeater {
            id: toolRepeater

            model: root.toolToggles

            delegate: QuickToggleRow {
                first: index === 0
                last: index === toolRepeater.count - 1
            }
        }

        SectionHeader {
            text: I18n.tr("System")
        }

        Repeater {
            id: systemRepeater

            model: root.systemToggles

            delegate: QuickToggleRow {
                first: index === 0
                last: index === systemRepeater.count - 1
            }
        }
    }

    component QuickToggleRow: ToggleRow {
        required property var modelData
        required property int index

        text: modelData.label
        checked: {
            const toggles = Config.utilities.quickToggles || [];
            const toggle = toggles.find(item => item.id === modelData.id);
            return toggle ? toggle.enabled !== false : true;
        }
        onToggled: {
            const toggles = JSON.parse(JSON.stringify(GlobalConfig.utilities.quickToggles || []));
            const toggleIndex = toggles.findIndex(item => item.id === modelData.id);
            if (toggleIndex >= 0) {
                toggles[toggleIndex].enabled = checked;
            } else {
                toggles.push({ id: modelData.id, enabled: checked });
            }
            GlobalConfig.utilities.quickToggles = toggles;
        }
    }
}