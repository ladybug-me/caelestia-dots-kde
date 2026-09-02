pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    isSubPage: true
    title: I18n.tr("Wallpaper Settings")

    readonly property list<MenuItem> scalingItems: [
        MenuItem { text: I18n.tr("Crop") },
        MenuItem { text: I18n.tr("Fit") },
        MenuItem { text: I18n.tr("Stretch") }
    ]

    readonly property list<int> scalingValues: [Image.PreserveAspectCrop, Image.PreserveAspectFit, Image.Stretch]

    function scaleKeyToIndex(key: int): int {
        if (key === Image.PreserveAspectFit) return 1;
        if (key === Image.Stretch) return 2;
        return 0; // Default to Crop
    }

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

            SelectRow {
                first: true
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: I18n.tr("Wallpaper scaling")
                subtext: I18n.tr("How the wallpaper image fits the screen")
                menuItems: root.scalingItems
                active: root.scalingItems[root.scaleKeyToIndex(Config.background.wallpaperFillMode)]
                onSelected: item => {
                    let fillMode = root.scalingValues[root.scalingItems.indexOf(item)];
                    GlobalConfig.background.wallpaperFillMode = fillMode;
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        let sConf = GlobalConfig.forScreen(Quickshell.screens[i].name);
                        if (sConf) sConf.background.resetOption("wallpaperFillMode");
                    }
                    GlobalConfig.save();
                }
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: Strings.localizeEnglishSpelling(I18n.tr("Recolour wallpaper"))
                subtext: Strings.localizeEnglishSpelling(I18n.tr("Tint the wallpaper to match static colour schemes"))
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
                label: Strings.localizeEnglishSpelling(I18n.tr("Recolour strength"))
                valueLabel: Math.round(value * 100) + "%"
                value: Config.background.wallpaperRecolorStrength
                enabled: Config.background.wallpaperRecolor && Config.background.wallpaperEnabled
                onMoved: v => GlobalConfig.background.wallpaperRecolorStrength = v
            }
        }
    }
}
