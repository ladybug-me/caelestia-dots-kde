pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.utils
import Quickshell

PageBase {
    id: root

    isSubPage: true
    title: qsTr("Wallpaper Settings")

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
                text: qsTr("Show KDE Desktop")
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
                subtext: qsTr("Use Material You icon set instead of KDE theme")
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

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: Strings.localizeEnglishSpelling(qsTr("Recolour wallpaper"))
                subtext: Strings.localizeEnglishSpelling(qsTr("Tint the wallpaper to match static colour schemes"))
                checked: Config.background.wallpaperRecolor
                onToggled: { 
                    GlobalConfig.background.wallpaperRecolor = checked; 
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        let sConf = GlobalConfig.forScreen(Quickshell.screens[i].name);
                        if (sConf) sConf.background.resetOption("wallpaperRecolor");
                    }
                    GlobalConfig.save(); 
                }
                enabled: Config.background.wallpaperEnabled
            }

            SliderRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                last: true
                icon: ""
                label: Strings.localizeEnglishSpelling(qsTr("Recolour strength"))
                valueLabel: Math.round(value * 100) + "%"
                value: Config.background.wallpaperRecolorStrength
                enabled: Config.background.wallpaperRecolor && Config.background.wallpaperEnabled
                onMoved: v => GlobalConfig.background.wallpaperRecolorStrength = v
            }
        }
    }
}
