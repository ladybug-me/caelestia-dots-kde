pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal

    implicitWidth: Math.max(300, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.leftMargin: Tokens.padding.small
        text: qsTr("Audio")
        font.weight: 500
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: outputLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: outputLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: outputLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            StyledText {
                text: qsTr("Output device")
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            }

            Repeater {
                model: Audio.sinks

                StyledRadioButton {
                    id: outputControl

                    required property PwNode modelData

                    ButtonGroup.group: sinks
                    checked: Audio.sink?.id === modelData.id
                    onClicked: Audio.setAudioSink(modelData)
                    text: modelData.description
                }
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: inputLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: inputLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: inputLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            StyledText {
                text: qsTr("Input device")
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
            }

            Repeater {
                model: Audio.sources

                StyledRadioButton {
                    id: inputControl

                    required property PwNode modelData

                    ButtonGroup.group: sources
                    checked: Audio.source?.id === modelData.id
                    onClicked: Audio.setAudioSource(modelData)
                    text: modelData.description
                }
            }
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium
        text: qsTr("Volume (%1)").arg(Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`)
        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
    }

    CustomMouseArea {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3

        onWheel: event => {
            if (event.angleDelta.y > 0)
                Audio.incrementVolume();
            else if (event.angleDelta.y < 0)
                Audio.decrementVolume();
        }

        StyledSlider {
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: parent.implicitHeight

            value: Audio.volume
            onInteraction: v => Audio.setVolume(v)
            onReleased: v => Audio.playEffectTick()
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small
        text: qsTr("Open settings")
        icon: "settings"

        onClicked: root.popouts.detachRequested("audio")
    }
}
