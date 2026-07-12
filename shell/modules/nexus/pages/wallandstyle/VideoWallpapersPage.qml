pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    isSubPage: true
    title: qsTr("Video Wallpapers")

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
                text: qsTr("Pause video wallpapers")
                checked: Config.background.videoWallpaperPaused
                onToggled: GlobalConfig.background.videoWallpaperPaused = checked
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: qsTr("Enable video audio")
                checked: Config.background.videoWallpaperSoundEnabled
                onToggled: GlobalConfig.background.videoWallpaperSoundEnabled = checked
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: qsTr("Pause video on fullscreen")
                visible: Quickshell.env("XDG_CURRENT_DESKTOP").includes("Hyprland")
                checked: Config.background.videoWallpaperPauseOnFullscreen
                onToggled: GlobalConfig.background.videoWallpaperPauseOnFullscreen = checked
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                last: true
                text: qsTr("Mute video when media plays")
                checked: Config.background.videoWallpaperMuteOnMedia
                onToggled: GlobalConfig.background.videoWallpaperMuteOnMedia = checked
            }
        }
    }
}
