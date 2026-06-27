import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import "weather"

Item {
    id: root

    required property var lock
    required property bool isPortrait
    required property real lockHeight

    // Portrait layout
    ColumnLayout {
        anchors.fill: parent
        visible: root.isPortrait
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.largeIncreased

            WeatherInfo {
                Layout.fillWidth: true
                rootHeight: root.height / Tokens.sizes.lock.ratio
                isPortrait: root.isPortrait
            }
        }

        Center {
            Layout.alignment: Qt.AlignHCenter
            lock: root.lock
            lockHeight: root.lockHeight
            isPortrait: root.isPortrait
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.largeIncreased

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.largeIncreased

                Fetch {
                    id: fetchBox
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    rootHeight: root.height
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: fetchBox.height

                    bottomRightRadius: Tokens.rounding.extraLarge
                    radius: Tokens.rounding.medium
                    color: Colours.tPalette.m3surfaceContainer

                    NotifDock {
                        lock: root.lock
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.largeIncreased

                Media {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: resourcesBox.height
                    lock: root.lock
                }

                Resources {
                    id: resourcesBox
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                }
            }
        }
    }

    // Landscape layout
    RowLayout {
        anchors.fill: parent
        visible: !root.isPortrait
        spacing: Tokens.spacing.largeIncreased * 2

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            WeatherInfo {
                Layout.fillWidth: true
                rootHeight: root.height
            }

            Fetch {
                Layout.fillWidth: true
                rootHeight: root.height
            }

            Media {
                Layout.fillWidth: true
                Layout.fillHeight: true

                lock: root.lock
            }
        }

        Center {
            lock: root.lock
            lockHeight: root.lockHeight
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            Resources {
                Layout.fillWidth: true
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true

                bottomRightRadius: Tokens.rounding.extraLarge
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer

                NotifDock {
                    lock: root.lock
                }
            }
        }
    }
}
