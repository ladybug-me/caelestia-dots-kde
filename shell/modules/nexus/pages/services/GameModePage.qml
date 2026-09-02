import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.images
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: I18n.tr("Game mode")
    isSubPage: true

    ColumnLayout {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Auto-enable rules")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Enable automatically")
            subtext: I18n.tr("Turn on game mode when a target window is focused or running")
            checked: GlobalConfig.utilities.gameMode.autoEnable
            onToggled: GlobalConfig.utilities.gameMode.autoEnable = checked
        }

        NavRow {
            last: true
            icon: "ads_click"
            label: I18n.tr("Target windows")
            status: I18n.tr("Add or remove auto-enable targets")
            onClicked: root.nState.openSubPage(2)
        }

        Column {
            Layout.fillWidth: true
            spacing: root.spacing
            visible: Quickshell.env("XDG_CURRENT_DESKTOP").includes("Hyprland")

            SectionHeader {
                text: I18n.tr("Hyprland overrides")
            }

            ToggleRow {
                Layout.fillWidth: true
                first: true
                text: I18n.tr("Disable animations")
                checked: GlobalConfig.utilities.gameMode.disableHyprlandAnimations
                onToggled: GlobalConfig.utilities.gameMode.disableHyprlandAnimations = checked
            }
            ToggleRow {
                Layout.fillWidth: true
                text: I18n.tr("Disable blur")
                checked: GlobalConfig.utilities.gameMode.disableHyprlandBlur
                onToggled: GlobalConfig.utilities.gameMode.disableHyprlandBlur = checked
            }
            ToggleRow {
                Layout.fillWidth: true
                text: I18n.tr("Disable gaps and rounding")
                checked: GlobalConfig.utilities.gameMode.disableHyprlandGaps
                onToggled: GlobalConfig.utilities.gameMode.disableHyprlandGaps = checked
            }
            ToggleRow {
                Layout.fillWidth: true
                text: I18n.tr("Disable shadows")
                checked: GlobalConfig.utilities.gameMode.disableHyprlandShadows
                onToggled: GlobalConfig.utilities.gameMode.disableHyprlandShadows = checked
            }
            ToggleRow {
                Layout.fillWidth: true
                text: I18n.tr("Disable window transparency")
                last: true
                checked: GlobalConfig.utilities.gameMode.disableWindowTransparency
                onToggled: GlobalConfig.utilities.gameMode.disableWindowTransparency = checked
            }
        }

        SectionHeader {
            text: I18n.tr("Caelestia feature overrides")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Disable shell transparency")
            checked: GlobalConfig.utilities.gameMode.disableShellTransparency
            onToggled: GlobalConfig.utilities.gameMode.disableShellTransparency = checked
        }
        ToggleRow {
            text: I18n.tr("Disable toast notifications transparency")
            checked: GlobalConfig.utilities.gameMode.disableToastTransparency
            onToggled: GlobalConfig.utilities.gameMode.disableToastTransparency = checked
        }
        ToggleRow {
            text: I18n.tr("Disable desktop lyrics")
            checked: GlobalConfig.utilities.gameMode.disableDesktopLyrics
            onToggled: GlobalConfig.utilities.gameMode.disableDesktopLyrics = checked
        }
        ToggleRow {
            text: I18n.tr("Disable visualizer")
            checked: GlobalConfig.utilities.gameMode.disableVisualizer
            onToggled: GlobalConfig.utilities.gameMode.disableVisualizer = checked
        }
        ToggleRow {
            text: I18n.tr("Disable shimeji pets")
            last: true
            checked: GlobalConfig.utilities.gameMode.disableShimeji
            onToggled: GlobalConfig.utilities.gameMode.disableShimeji = checked
        }
    }
}
