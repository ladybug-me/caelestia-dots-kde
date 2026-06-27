import "center"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var lock
    required property real lockHeight
    property bool isPortrait: false

    readonly property real centerScale: Math.min(1, root.lockHeight / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

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
            Layout.bottomMargin: Tokens.spacing.extraLarge * root.centerScale
            centerWidth: root.centerWidth
        }

        PasswordInput {
            Layout.alignment: Qt.AlignHCenter
            centerScale: Math.max(0.8, root.centerScale)
            centerWidth: root.centerWidth
            lock: root.lock
        }

        StateMessage {
            Layout.fillWidth: true
            pam: root.lock.pam
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

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: pPic.width
                implicitHeight: pInput.implicitHeight

                PasswordInput {
                    id: pInput
                    anchors.horizontalCenter: parent.horizontalCenter
                    centerScale: Math.max(0.8, root.centerScale)
                    centerWidth: root.centerWidth
                    lock: root.lock
                }
            }

            Item {
                Layout.fillWidth: true
            }

            StateMessage {
                Layout.columnSpan: 2
                Layout.fillWidth: true
                pam: root.lock.pam
            }
        }
    }
}
