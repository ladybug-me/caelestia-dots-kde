import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("On-screen sliders")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Sliders")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Volume")
            subtext: I18n.tr("Show the volume slider")
            checked: Config.osd.enableVolume
            onToggled: GlobalConfig.osd.enableVolume = checked
        }

        ToggleRow {
            text: I18n.tr("Microphone")
            subtext: I18n.tr("Show the microphone slider")
            checked: Config.osd.enableMicrophone
            onToggled: GlobalConfig.osd.enableMicrophone = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Brightness")
            subtext: I18n.tr("Show the brightness slider")
            checked: Config.osd.enableBrightness
            onToggled: GlobalConfig.osd.enableBrightness = checked
        }

        SectionHeader {
            text: I18n.tr("Edge trigger")
        }

        StepperRow {
            first: true
            label: I18n.tr("Depth")
            subtext: I18n.tr("Distance from the screen edge")
            value: Config.osd.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: value => GlobalConfig.osd.hoverThickness = value
        }

        StepperRow {
            last: true
            label: I18n.tr("Height")
            subtext: I18n.tr("Portion of the edge that responds")
            value: Config.osd.hoverWidth
            from: 10
            to: 100
            stepSize: 5
            onMoved: value => GlobalConfig.osd.hoverWidth = value
        }
    }
}