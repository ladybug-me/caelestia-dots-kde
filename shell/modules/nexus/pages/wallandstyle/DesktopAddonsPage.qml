pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    isSubPage: true
    title: I18n.tr("Desktop Addons")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Tokens.padding.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            ToggleRow {
                Layout.fillWidth: true
                first: true
                text: I18n.tr("Desktop clock")
                checked: Config.background.desktopClock.enabled
                onToggled: GlobalConfig.background.desktopClock.enabled = checked
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: I18n.tr("Desktop lyrics")
                checked: Config.background.desktopLyrics.enabled
                onToggled: {
                    GlobalConfig.background.desktopLyrics.enabled = checked;
                    if (!checked)
                        GlobalConfig.background.desktopLyrics.autoHide = false;
                }
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: I18n.tr("Auto-hide lyrics")
                subtext: I18n.tr("Hide lyrics when a window is open")
                checked: Config.background.desktopLyrics.autoHide
                onToggled: GlobalConfig.background.desktopLyrics.autoHide = checked
                enabled: Config.background.desktopLyrics.enabled || Config.background.desktopLyrics.autoHide
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: I18n.tr("Background visualiser")
                subtext: I18n.tr("Show music visualiser on wallpaper (May consume more power)")
                checked: Config.background.visualiser.enabled
                onToggled: {
                    GlobalConfig.background.visualiser.enabled = checked;
                    if (!checked)
                        GlobalConfig.background.visualiser.autoHide = false;
                }
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: I18n.tr("Auto-hide visualiser")
                subtext: I18n.tr("Hide visualiser when a window is fullscreen")
                checked: Config.background.visualiser.autoHide
                onToggled: GlobalConfig.background.visualiser.autoHide = checked
                enabled: Config.background.visualiser.enabled || Config.background.visualiser.autoHide
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: I18n.tr("Hide on all monitors")
                subtext: I18n.tr("Also hide on all other monitors if disabled by a window")
                checked: Config.background.visualiser.hideOnAllMonitors
                onToggled: GlobalConfig.background.visualiser.hideOnAllMonitors = checked
                enabled: Config.background.visualiser.enabled && Config.background.visualiser.autoHide
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                last: true
                text: I18n.tr("Shimeji characters")
                checked: Config.shimeji.enabled
                onToggled: GlobalConfig.shimeji.enabled = checked
            }
        }
    }
}
