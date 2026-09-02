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
    title: I18n.tr("Slideshow & Order")

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
                text: I18n.tr("Wallpaper slideshow")
                subtext: I18n.tr("Automatically change wallpaper on a timer")
                checked: Config.background.slideshowEnabled
                onToggled: GlobalConfig.background.slideshowEnabled = checked
                enabled: Config.background.wallpaperEnabled
            }

            SliderRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                icon: ""
                label: I18n.tr("Slideshow interval")
                valueLabel: Math.max(1, Math.round(value * 60)) + " min"
                value: Config.background.slideshowInterval
                enabled: Config.background.slideshowEnabled && Config.background.wallpaperEnabled
                onMoved: v => GlobalConfig.background.slideshowInterval = v
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                last: true
                text: I18n.tr("Random order")
                subtext: I18n.tr("Affects slideshow and the 'Next Wallpaper' right-click menu option")
                checked: Config.background.slideshowRandom
                onToggled: GlobalConfig.background.slideshowRandom = checked
                enabled: Config.background.wallpaperEnabled
            }
        }
    }
}
