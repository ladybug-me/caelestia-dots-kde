import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    spacing: Tokens.spacing.medium

    StyledText {
        Layout.leftMargin: Tokens.padding.medium
        visible: forecastRepeater.count > 0
        text: qsTr("7-Day Forecast")
        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
        color: Colours.palette.m3onSurface
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        Repeater {
            id: forecastRepeater

            model: CUtils.clamp(Math.floor((root.width + parent.spacing) / (Tokens.sizes.lock.forecastItemWidth + parent.spacing)), 0, Weather.forecast.length)

            StyledRect {
                id: forecastItem

                required property int index
                readonly property var modelData: Weather.forecast[index]

                Layout.fillWidth: true
                implicitHeight: forecastItemColumn.implicitHeight + Tokens.padding.medium * 2

                radius: Tokens.rounding.large
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                ColumnLayout {
                    id: forecastItemColumn

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: forecastItem.index === 0 ? qsTr("Today") : new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "ddd")
                        font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.topMargin: -Tokens.spacing.extraSmall
                        Layout.alignment: Qt.AlignHCenter
                        text: new Date(forecastItem.modelData.date).toLocaleDateString(Qt.locale(), "MMM d")
                        font: Tokens.font.body.small
                        opacity: 0.7
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: forecastItem.modelData.icon
                        fontStyle: Tokens.font.icon.extraLarge
                        color: Colours.palette.m3secondary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const min = Weather.formatTemp(forecastItem.modelData.minTempC).slice(0, -1);
                            const max = Weather.formatTemp(forecastItem.modelData.maxTempC).slice(0, -1);
                            return `${min} / ${max}`;
                        }
                        font: Tokens.font.body.builders.small.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
                    }
                }
            }
        }
    }
}
