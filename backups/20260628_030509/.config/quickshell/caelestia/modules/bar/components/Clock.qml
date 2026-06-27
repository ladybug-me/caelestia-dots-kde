pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property var font: Tokens.font.body.builders.small.scale(1.1)

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    implicitWidth: isHorizontal ? (horizontalLayout.implicitWidth + root.padding * 2) : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : (verticalLayout.implicitHeight + root.padding * 2)

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    RowLayout {
        id: horizontalLayout

        anchors.centerIn: parent
        visible: isHorizontal
        spacing: Tokens.spacing.extraSmall

        Loader {
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.format("ddd")
            font: Tokens.font.body.small
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.format("d")
            font: Tokens.font.body.small
            color: root.colour
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 1
            Layout.preferredHeight: 16
            visible: Config.bar.clock.showDate

            color: root.colour
            opacity: 0.2
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.hourStr
            font: root.font.build()
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: ":"
            font: root.font.build()
            color: root.colour
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Time.minuteStr
            font: root.font.build()
            color: root.colour
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            active: GlobalConfig.services.useTwelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }
    }

    ColumnLayout {
        id: verticalLayout

        anchors.centerIn: parent
        visible: !isHorizontal
        spacing: Tokens.spacing.extraSmall

        Loader {
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: Config.bar.clock.showDate

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format("ddd\nd")
            font: Tokens.font.body.small
            color: root.colour
        }

        Rectangle {
            Layout.fillWidth: true
            visible: Config.bar.clock.showDate
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            font: {
                const scale = text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / hourMetrics.width);
                return root.font.width(scale * 100).letterSpacing(scale).build();
            }
            color: root.colour

            TextMetrics {
                id: hourMetrics

                font: root.font.build()
                text: Time.hourStr
            }
        }

        StyledText {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            font: {
                const scale = text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / minMetrics.width);
                return root.font.width(scale * 100).letterSpacing(scale).build();
            }
            color: root.colour

            TextMetrics {
                id: minMetrics

                font: root.font.build()
                text: Time.minuteStr
            }
        }

        Loader {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: GlobalConfig.services.useTwelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }
    }
}
