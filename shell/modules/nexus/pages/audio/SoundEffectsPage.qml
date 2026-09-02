import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: I18n.tr("Sound effects")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("General")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Enable sound effects")
            checked: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.enabled = checked
        }

        SliderRow {
            last: true
            icon: "volume_up"
            label: I18n.tr("Sound effect volume")
            valueLabel: Math.round(value * 100) + "%"
            value: GlobalConfig.audio.sounds.sfxVolume
            enabled: GlobalConfig.audio.sounds.enabled
            onMoved: value => GlobalConfig.audio.sounds.sfxVolume = value
            onReleased: value => Audio.playEffectTick()
        }

        SectionHeader {
            text: I18n.tr("Feedback")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Camera click")
            checked: GlobalConfig.audio.sounds.cameraClick
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.cameraClick = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Volume tick")
            checked: GlobalConfig.audio.sounds.effectTick
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.effectTick = checked
        }

        SectionHeader {
            text: I18n.tr("System")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Charging started")
            checked: GlobalConfig.audio.sounds.chargingStarted
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.chargingStarted = checked
        }

        ToggleRow {
            text: I18n.tr("Screen lock")
            checked: GlobalConfig.audio.sounds.lock
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.lock = checked
        }

        ToggleRow {
            text: I18n.tr("Screen unlock")
            checked: GlobalConfig.audio.sounds.unlock
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.unlock = checked
        }

        ToggleRow {
            text: I18n.tr("Low battery")
            checked: GlobalConfig.audio.sounds.lowBattery
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.lowBattery = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Screen recording")
            checked: GlobalConfig.audio.sounds.screenRecord
            enabled: GlobalConfig.audio.sounds.enabled
            onToggled: GlobalConfig.audio.sounds.screenRecord = checked
        }
    }
}