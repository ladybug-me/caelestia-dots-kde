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
                first: true
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
