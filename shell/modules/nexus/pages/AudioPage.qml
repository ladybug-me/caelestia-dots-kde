pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: I18n.tr("Audio")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Output")
        }

        SliderRow {
            first: true
            icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
            label: I18n.tr("Output")
            valueLabel: Math.round(value * 100) + "%"
            value: Audio.volume
            enabled: !Audio.muted
            onMoved: v => Audio.setVolume(v)
            onReleased: v => Audio.playEffectTick()
        }

        ToggleRow {
            text: I18n.tr("Muted")
            checked: Audio.muted
            onToggled: Audio.setStreamMuted(Audio.sink, checked)
        }

        AudioDeviceList {
            nodes: Audio.sinks
            currentId: Audio.sink?.id ?? -1
            iconName: "speaker"
            placeholderIcon: "speaker"
            placeholderText: I18n.tr("No output devices")
            onSelected: node => Audio.setAudioSink(node)
        }

        SectionHeader {
            text: I18n.tr("Input")
        }

        SliderRow {
            first: true
            icon: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
            label: I18n.tr("Input")
            valueLabel: Math.round(value * 100) + "%"
            value: Audio.sourceVolume
            enabled: !Audio.sourceMuted
            onMoved: v => Audio.setSourceVolume(v)
            onReleased: v => Audio.playEffectTick()
        }

        ToggleRow {
            text: I18n.tr("Muted")
            checked: Audio.sourceMuted
            onToggled: Audio.setStreamMuted(Audio.source, checked)
        }

        AudioDeviceList {
            nodes: Audio.sources
            currentId: Audio.source?.id ?? -1
            iconName: "mic"
            placeholderIcon: "mic_off"
            placeholderText: I18n.tr("No input devices")
            onSelected: node => Audio.setAudioSource(node)
        }

        SectionHeader {
            text: I18n.tr("Apps")
        }

        NavRow {
            first: true
            last: true
            icon: "tune"
            label: I18n.tr("App volumes")
            status: Audio.streams.length === 0 ? I18n.tr("No apps playing audio") : Audio.streams.length === 1 ? I18n.tr("1 app playing audio") : I18n.tr("%1 apps playing audio").arg(Audio.streams.length)
            onClicked: root.nState.openSubPage(1)
        }

        SectionHeader {
            text: I18n.tr("Customization")
        }

        NavRow {
            first: true
            icon: "volume_up"
            label: I18n.tr("Sound effects")
            status: I18n.tr("Feedback sounds and volume")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            last: true
            icon: "notifications_off"
            label: I18n.tr("Muted notification apps")
            status: I18n.tr("Choose apps that do not play notification sounds")
            onClicked: root.nState.openSubPage(3)
        }
    }
}
