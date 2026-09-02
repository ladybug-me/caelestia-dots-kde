pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Services
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Desktop & Tiling")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        
        property bool showTilingLogout: false

        property bool isTilingEnabled: Config.general.krohnkiteEnabled
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: I18n.tr("Show KDE Desktop")
            subtext: I18n.tr("Disable Caelestia desktop and use native Plasma 6 desktop instead")
            checked: !Config.background.wallpaperEnabled
            onToggled: { 
                GlobalConfig.background.wallpaperEnabled = !checked; 
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    let sConf = GlobalConfig.forScreen(Quickshell.screens[i].name);
                    if (sConf) sConf.background.resetOption("wallpaperEnabled");
                }
                GlobalConfig.save(); 
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: I18n.tr("Show Desktop Icons")
            subtext: I18n.tr("Enable icons for Caelestia desktop")
            checked: Config.background.desktopIconsEnabled
            onToggled: { 
                GlobalConfig.background.desktopIconsEnabled = checked; 
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    let sConf = GlobalConfig.forScreen(Quickshell.screens[i].name);
                    if (sConf) sConf.background.resetOption("desktopIconsEnabled");
                }
                GlobalConfig.save(); 
            }
            enabled: Config.background.wallpaperEnabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: I18n.tr("Material You Icons")
            subtext: I18n.tr("Override the KDE icon theme for desktop icons only")
            checked: Config.background.materialYouIconsEnabled
            onToggled: {
                GlobalConfig.background.materialYouIconsEnabled = checked;
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    let sConf = GlobalConfig.forScreen(Quickshell.screens[i].name);
                    if (sConf) sConf.background.resetOption("materialYouIconsEnabled");
                }
                GlobalConfig.save();
            }
            enabled: Config.background.wallpaperEnabled && Config.background.desktopIconsEnabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: I18n.tr("Vibrant Icons")
            subtext: I18n.tr("Boost saturation of Material You icons for extra vibrancy")
            checked: Config.background.materialYouIconsVibrant
            onToggled: {
                GlobalConfig.background.materialYouIconsVibrant = checked;
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    let sConf = GlobalConfig.forScreen(Quickshell.screens[i].name);
                    if (sConf) sConf.background.resetOption("materialYouIconsVibrant");
                }
                GlobalConfig.save();
            }
            enabled: Config.background.wallpaperEnabled && Config.background.desktopIconsEnabled && Config.background.materialYouIconsEnabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: I18n.tr("Magic Lamp Minimize")
            subtext: I18n.tr("Enable the magic lamp effect when minimizing windows")
            checked: Config.general.magicLampEnabled
            onToggled: {
                GlobalConfig.general.magicLampEnabled = checked;
                GlobalConfig.save();
                Quickshell.execDetached(["bash", "-c", `
                    kwriteconfig6 --file kwinrc --group "Plugins" --key "magiclampEnabled" "${checked ? 'true' : 'false'}" 2>/dev/null || true
                    if [[ "${checked ? 'true' : 'false'}" == "true" ]]; then
                        kwriteconfig6 --file kwinrc --group "Plugins" --key "squashEnabled" "false" 2>/dev/null || true
                        qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "squash" 2>/dev/null || true
                        qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect "magiclamp" 2>/dev/null || true
                    else
                        qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect "magiclamp" 2>/dev/null || true
                    fi
                    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
                `]);
            }
        }

        NavRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            icon: "view_quilt"
            label: I18n.tr("Window Tiling")
            status: Config.general.krohnkiteEnabled ? I18n.tr("Enabled (Krohnkite)") : I18n.tr("Disabled")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            icon: "extension"
            label: I18n.tr("Desktop Addons")
            status: I18n.tr("Clock, Lyrics, Visualiser, Shimeji")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            last: true
            icon: "menu_open"
            label: I18n.tr("Right Click Menu")
            status: I18n.tr("Configure desktop right click menu")
            onClicked: root.nState.openSubPage(2)
        }
    }
}
