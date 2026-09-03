pragma ComponentBehavior: Bound

import "center"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property real lockHeight
    property bool isPortrait: false

    readonly property real centerScale: Math.min(1, root.lockHeight / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    readonly property var greetingInfo: {
        const hour = new Date().getHours();
        if (hour >= 5 && hour < 12) {
            return { greeting: qsTr("Good morning"), icon: "sunny", iconColor: Colours.palette.m3tertiary };
        } else if (hour >= 12 && hour < 17) {
            return { greeting: qsTr("Good afternoon"), icon: "light_mode", iconColor: Colours.palette.m3primary };
        } else if (hour >= 17 && hour < 22) {
            return { greeting: qsTr("Good evening"), icon: "routine", iconColor: Colours.palette.m3secondary };
        } else {
            return { greeting: qsTr("Good night"), icon: "bedtime", iconColor: Colours.palette.m3primary };
        }
    }

    Layout.preferredWidth: isPortrait ? portraitLayout.implicitWidth : centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    implicitWidth: isPortrait ? portraitLayout.implicitWidth : landscapeLayout.implicitWidth
    implicitHeight: isPortrait ? portraitLayout.implicitHeight : landscapeLayout.implicitHeight

    ColumnLayout {
        id: landscapeLayout

        anchors.fill: parent
        visible: !root.isPortrait
        spacing: Tokens.spacing.largeIncreased

        Clock {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.padding.large
            centerScale: root.centerScale
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd • d MMM").toUpperCase()
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
        }

        ProfilePic {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.extraExtraLarge * root.centerScale
            Layout.bottomMargin: Tokens.spacing.large * root.centerScale
            centerWidth: root.centerWidth
        }

        StyledRect {
            id: greetingPill

            Layout.alignment: Qt.AlignHCenter
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.full

            implicitWidth: Math.min(root.centerWidth * 0.95, greetingRow.implicitWidth + Tokens.padding.largeIncreased * 2)
            implicitHeight: greetingRow.implicitHeight + Tokens.padding.medium * 1.5

            RowLayout {
                id: greetingRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: root.greetingInfo.icon
                    color: root.greetingInfo.iconColor
                    fontStyle: Tokens.font.icon.builders.medium.scale(root.centerScale * 1.1).build()
                }

                RowLayout {
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: root.greetingInfo.greeting + ","
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.title.builders.small.scale(root.centerScale).weight(Font.Normal).build()
                    }

                    StyledText {
                        text: SysInfo.user
                        color: Colours.palette.m3primary
                        font: Tokens.font.title.builders.small.scale(root.centerScale).weight(Font.Bold).build()
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    Item {
        id: portraitLayout

        anchors.fill: parent
        visible: root.isPortrait
        implicitWidth: grid.implicitWidth
        implicitHeight: grid.implicitHeight

        GridLayout {
            id: grid

            anchors.centerIn: parent
            columns: 2
            columnSpacing: Tokens.spacing.largeIncreased * 3
            rowSpacing: Tokens.spacing.largeIncreased

            ProfilePic {
                id: pPic
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Tokens.spacing.extraLarge * root.centerScale

                centerWidth: root.centerWidth
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                spacing: Tokens.spacing.largeIncreased

                Clock {
                    Layout.alignment: Qt.AlignHCenter
                    centerScale: root.centerScale
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Time.format("dddd • d MMM").toUpperCase()
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                }
            }

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                Layout.columnSpan: 2
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.full

                implicitWidth: Math.min(root.centerWidth * 0.95, portraitGreetingRow.implicitWidth + Tokens.padding.largeIncreased * 2)
                implicitHeight: portraitGreetingRow.implicitHeight + Tokens.padding.medium * 1.5

                RowLayout {
                    id: portraitGreetingRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: root.greetingInfo.icon
                        color: root.greetingInfo.iconColor
                        fontStyle: Tokens.font.icon.builders.medium.scale(root.centerScale * 1.1).build()
                    }

                    RowLayout {
                        spacing: Tokens.spacing.small

                        StyledText {
                            text: root.greetingInfo.greeting + ","
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.title.builders.small.scale(root.centerScale).weight(Font.Normal).build()
                        }

                        StyledText {
                            text: SysInfo.user
                            color: Colours.palette.m3primary
                            font: Tokens.font.title.builders.small.scale(root.centerScale).weight(Font.Bold).build()
                        }
                    }
                }
            }
        }
    }
}
