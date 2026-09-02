pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.utils
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Status icons")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Visible icons
        SectionHeader {
            first: true
            text: I18n.tr("Visible icons")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Speakers")
            checked: Config.bar.status.showAudio
            onToggled: GlobalConfig.bar.status.showAudio = checked
        }

        ToggleRow {
            text: I18n.tr("Microphone")
            checked: Config.bar.status.showMicrophone
            onToggled: GlobalConfig.bar.status.showMicrophone = checked
        }

        ToggleRow {
            text: I18n.tr("Keyboard layout")
            checked: Config.bar.status.showKbLayout
            onToggled: GlobalConfig.bar.status.showKbLayout = checked
        }

        ToggleRow {
            text: I18n.tr("Network")
            checked: Config.bar.status.showNetwork
            onToggled: GlobalConfig.bar.status.showNetwork = checked
        }

        ToggleRow {
            text: I18n.tr("Wi-Fi")
            checked: Config.bar.status.showWifi
            onToggled: GlobalConfig.bar.status.showWifi = checked
        }

        ToggleRow {
            text: I18n.tr("Bluetooth")
            checked: Config.bar.status.showBluetooth
            onToggled: GlobalConfig.bar.status.showBluetooth = checked
        }

        ToggleRow {
            text: I18n.tr("Night Light")
            checked: Config.bar.status.showNightLight
            onToggled: GlobalConfig.bar.status.showNightLight = checked
        }

        ToggleRow {
            text: I18n.tr("Battery")
            checked: Config.bar.status.showBattery
            onToggled: GlobalConfig.bar.status.showBattery = checked
        }

        ToggleRow {
            text: I18n.tr("Peripheral Battery")
            checked: Config.bar.status.showPeripheralBattery
            onToggled: GlobalConfig.bar.status.showPeripheralBattery = checked
        }

        ToggleRow {
            text: I18n.tr("Notifications")
            checked: Config.bar.status.showNotifications
            onToggled: GlobalConfig.bar.status.showNotifications = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: I18n.tr("Caps lock")
            checked: Config.bar.status.showLockStatus
            onToggled: GlobalConfig.bar.status.showLockStatus = checked
        }

        // Behaviour
        SectionHeader {
            text: Strings.localizeEnglishSpelling(I18n.tr("Behaviour"))
        }

        ToggleRow {
            first: true
            last: true
            text: I18n.tr("Popout on hover")
            subtext: I18n.tr("Show a details popout when hovering the status icons")
            checked: Config.bar.popouts.statusIcons
            onToggled: GlobalConfig.bar.popouts.statusIcons = checked
        }
    }
}
