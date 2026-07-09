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

    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.audio) ? GlobalConfig.bar.previewScales.audio : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.audio) ? GlobalConfig.bar.previewFontScales.audio : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)

    implicitWidth: Math.max(300 * scaleOffset, _isSidebarOpen ? (Tokens.sizes.sidebar.width * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium * scaleOffset

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    StyledText {
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: qsTr("Audio")
        font.weight: 500
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: outputLayout.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset
        implicitHeight: outputLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: outputLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.medium * root.scaleOffset

            StyledText {
                text: qsTr("Output device")
                font.weight: Font.Medium
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
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
                    font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                }
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: inputLayout.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset
        implicitHeight: inputLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: inputLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.medium * root.scaleOffset

            StyledText {
                text: qsTr("Input device")
                font.weight: Font.Medium
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
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
                    font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                }
            }
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium * root.scaleOffset
        text: qsTr("Volume (%1)").arg(Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`)
        font.weight: Font.Medium
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    CustomMouseArea {
        Layout.fillWidth: true
        implicitHeight: Tokens.padding.medium * 3 * root.scaleOffset

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
        verticalPadding: Tokens.padding.small * root.scaleOffset
        text: qsTr("Open settings")
        icon: "settings"

        onClicked: root.popouts.detachRequested("audio")
    }
}
