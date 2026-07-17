pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Quickshell
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Desktop")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Show KDE Desktop")
            subtext: qsTr("Disable Caelestia desktop and use native Plasma 6 desktop instead")
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
            text: qsTr("Show Desktop Icons")
            subtext: qsTr("Enable icons for Caelestia desktop")
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
            text: qsTr("Material You Icons")
            subtext: qsTr("Override the KDE icon theme for desktop icons only")
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
            text: qsTr("Vibrant Icons")
            subtext: qsTr("Boost saturation of Material You icons for extra vibrancy")
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
        

        NavRow {
            icon: "extension"
            label: qsTr("Desktop Addons")
            status: qsTr("Clock, Lyrics, Visualiser, Shimeji")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            last: true
            icon: "menu_open"
            label: qsTr("Right Click Menu")
            status: qsTr("Configure desktop right click menu")
            onClicked: root.nState.openSubPage(2)
        }
    }
}
