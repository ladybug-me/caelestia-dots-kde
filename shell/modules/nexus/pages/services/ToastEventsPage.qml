import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Toast events")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("System")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Charging changes")
            checked: GlobalConfig.utilities.toasts.chargingChanged
            onToggled: GlobalConfig.utilities.toasts.chargingChanged = checked
        }

        ToggleRow {
            text: I18n.tr("Game mode changes")
            checked: GlobalConfig.utilities.toasts.gameModeChanged
            onToggled: GlobalConfig.utilities.toasts.gameModeChanged = checked
        }

        ToggleRow {
            text: I18n.tr("Night light changes")
            checked: GlobalConfig.utilities.toasts.nightLightChanged
            onToggled: GlobalConfig.utilities.toasts.nightLightChanged = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Configuration loaded")
            checked: GlobalConfig.utilities.toasts.configLoaded
            onToggled: GlobalConfig.utilities.toasts.configLoaded = checked
        }

        SectionHeader {
            text: I18n.tr("Audio")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Audio output changes")
            checked: GlobalConfig.utilities.toasts.audioOutputChanged
            onToggled: GlobalConfig.utilities.toasts.audioOutputChanged = checked
        }

        ToggleRow {
            text: I18n.tr("Audio input changes")
            checked: GlobalConfig.utilities.toasts.audioInputChanged
            onToggled: GlobalConfig.utilities.toasts.audioInputChanged = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Now playing")
            checked: GlobalConfig.utilities.toasts.nowPlaying
            onToggled: GlobalConfig.utilities.toasts.nowPlaying = checked
        }

        SectionHeader {
            text: I18n.tr("Input")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Caps lock changes")
            checked: GlobalConfig.utilities.toasts.capsLockChanged
            onToggled: GlobalConfig.utilities.toasts.capsLockChanged = checked
        }

        ToggleRow {
            text: I18n.tr("Num lock changes")
            checked: GlobalConfig.utilities.toasts.numLockChanged
            onToggled: GlobalConfig.utilities.toasts.numLockChanged = checked
        }

        ToggleRow {
            text: I18n.tr("Keyboard layout changes")
            checked: GlobalConfig.utilities.toasts.kbLayoutChanged
            onToggled: GlobalConfig.utilities.toasts.kbLayoutChanged = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Keyboard layout limit")
            checked: GlobalConfig.utilities.toasts.kbLimit
            onToggled: GlobalConfig.utilities.toasts.kbLimit = checked
        }

        SectionHeader {
            text: I18n.tr("Other")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Do not disturb changes")
            checked: GlobalConfig.utilities.toasts.dndChanged
            onToggled: GlobalConfig.utilities.toasts.dndChanged = checked
        }

        ToggleRow {
            text: I18n.tr("VPN changes")
            checked: GlobalConfig.utilities.toasts.vpnChanged
            onToggled: GlobalConfig.utilities.toasts.vpnChanged = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Clipboard changes")
            checked: GlobalConfig.utilities.toasts.clipboardChanged
            onToggled: GlobalConfig.utilities.toasts.clipboardChanged = checked
        }
    }
}