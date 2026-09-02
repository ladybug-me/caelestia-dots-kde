import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> fullscreenItems: [
        MenuItem {
            text: I18n.tr("Off")
            icon: "notifications_off"
        },
        MenuItem {
            text: I18n.tr("Important")
            icon: "priority_high"
        },
        MenuItem {
            text: I18n.tr("On")
            icon: "notifications"
        }
    ]
    readonly property list<string> fullscreenValues: ["off", "important", "all"]

    title: I18n.tr("Toasts")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Appearance")
        }

        SelectRow {
            first: true
            label: I18n.tr("Show in fullscreen")
            subtext: I18n.tr("Allow toasts over fullscreen apps")
            menuItems: root.fullscreenItems
            active: root.fullscreenItems[Math.max(0, root.fullscreenValues.indexOf(GlobalConfig.utilities.toasts.fullscreen))]
            onSelected: item => GlobalConfig.utilities.toasts.fullscreen = root.fullscreenValues[root.fullscreenItems.indexOf(item)]
        }

        StepperRow {
            label: I18n.tr("Visible toasts")
            subtext: I18n.tr("Maximum number shown at once")
            value: GlobalConfig.utilities.maxToasts
            from: 1
            to: 10
            stepSize: 1
            onMoved: value => GlobalConfig.utilities.maxToasts = Math.round(value)
        }

        ToggleRow {
            text: I18n.tr("Transparency")
            subtext: I18n.tr("Apply transparency and blur")
            checked: GlobalConfig.utilities.toasts.transparency
            onToggled: GlobalConfig.utilities.toasts.transparency = checked
        }

        SliderRow {
            last: true
            label: I18n.tr("Base transparency")
            valueLabel: Math.round(value * 100) + "%"
            value: GlobalConfig.utilities.toasts.transparencyBase
            enabled: GlobalConfig.utilities.toasts.transparency
            onMoved: value => GlobalConfig.utilities.toasts.transparencyBase = value
        }

        SectionHeader {
            text: I18n.tr("Sound")
        }

        SliderRow {
            first: true
            last: true
            icon: "notifications"
            label: I18n.tr("Notification volume")
            valueLabel: Math.round(value * 100) + "%"
            value: GlobalConfig.audio.sounds.notificationVolume
            enabled: GlobalConfig.audio.sounds.enabled
            onMoved: value => GlobalConfig.audio.sounds.notificationVolume = value
            onReleased: value => Audio.playNotification()
        }
    }
}