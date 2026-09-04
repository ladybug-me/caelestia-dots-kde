pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Status icons")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Visible icons
        SectionHeader {
            first: true
            text: qsTr("Visible icons")
        }

        ToggleRow {
            first: true
            text: qsTr("Speakers")
            checked: root.nState.targetConfig.bar.status.showAudio
            onToggled: Globalroot.nState.targetConfig.bar.status.showAudio = checked
        }

        ToggleRow {
            text: qsTr("Microphone")
            checked: root.nState.targetConfig.bar.status.showMicrophone
            onToggled: Globalroot.nState.targetConfig.bar.status.showMicrophone = checked
        }

        ToggleRow {
            text: qsTr("Keyboard layout")
            checked: root.nState.targetConfig.bar.status.showKbLayout
            onToggled: Globalroot.nState.targetConfig.bar.status.showKbLayout = checked
        }

        ToggleRow {
            text: qsTr("Network")
            checked: root.nState.targetConfig.bar.status.showNetwork
            onToggled: Globalroot.nState.targetConfig.bar.status.showNetwork = checked
        }

        ToggleRow {
            text: qsTr("Wi-Fi")
            checked: root.nState.targetConfig.bar.status.showWifi
            onToggled: Globalroot.nState.targetConfig.bar.status.showWifi = checked
        }

        ToggleRow {
            text: qsTr("Bluetooth")
            checked: root.nState.targetConfig.bar.status.showBluetooth
            onToggled: Globalroot.nState.targetConfig.bar.status.showBluetooth = checked
        }

        ToggleRow {
            text: qsTr("Night Light")
            checked: root.nState.targetConfig.bar.status.showNightLight
            onToggled: Globalroot.nState.targetConfig.bar.status.showNightLight = checked
        }

        ToggleRow {
            text: qsTr("Battery")
            checked: root.nState.targetConfig.bar.status.showBattery
            onToggled: Globalroot.nState.targetConfig.bar.status.showBattery = checked
        }

        ToggleRow {
            text: qsTr("Peripheral Battery")
            checked: root.nState.targetConfig.bar.status.showPeripheralBattery
            onToggled: Globalroot.nState.targetConfig.bar.status.showPeripheralBattery = checked
        }

        ToggleRow {
            text: qsTr("Notifications")
            checked: root.nState.targetConfig.bar.status.showNotifications
            onToggled: Globalroot.nState.targetConfig.bar.status.showNotifications = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: qsTr("Caps Lock")
            checked: root.nState.targetConfig.bar.status.showLockStatus
            onToggled: Globalroot.nState.targetConfig.bar.status.showLockStatus = checked
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behavior")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a details popout when hovering the status icons")
            checked: root.nState.targetConfig.bar.popouts.statusIcons
            onToggled: Globalroot.nState.targetConfig.bar.popouts.statusIcons = checked
        }
    }
}
