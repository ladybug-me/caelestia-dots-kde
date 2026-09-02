pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Active window")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Enable component")
            checked: {
                for (let i = 0; i < Config.bar.entries.length; i++) {
                    if (Config.bar.entries[i].id === "activeWindow")
                        return Config.bar.entries[i].enabled;
                }
                return false;
            }
            onToggled: {
                let newEntries = [...GlobalConfig.bar.entries];
                let found = false;
                for (let i = 0; i < newEntries.length; i++) {
                    if (newEntries[i].id === "activeWindow") {
                        newEntries[i].enabled = checked;
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    newEntries.push({ id: "activeWindow", enabled: checked, zone: "left" });
                }

                GlobalConfig.bar.entries = newEntries;
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Compact")
            checked: Config.bar.activeWindow.compact
            onToggled: GlobalConfig.bar.activeWindow.compact = checked
        }

        ToggleRow {
            text: qsTr("Inverted")
            checked: Config.bar.activeWindow.inverted
            onToggled: GlobalConfig.bar.activeWindow.inverted = checked
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Only show the active window title while hovering")
            checked: Config.bar.activeWindow.showOnHover
            onToggled: GlobalConfig.bar.activeWindow.showOnHover = checked
        }

        ToggleRow {
            text: qsTr("Popout on hover")
            subtext: qsTr("Show a window details popout when hovering")
            checked: Config.bar.popouts.activeWindow
            onToggled: GlobalConfig.bar.popouts.activeWindow = checked
        }

        SectionHeader {
            text: qsTr("Greeting images")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            text: qsTr("Shown in the active-window popout when no window is focused. Tap a card to pick your own image for that time of day.")
            font: Tokens.font.label.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
        }

        // Live-preview cards, two per row. Tap a card to pick an image.
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.rightMargin: Tokens.padding.small
            columns: 2
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            Repeater {
                model: [
                    { key: "morningGif", label: qsTr("Morning"), hint: "05:00 – 12:00", fallback: "morning.gif" },
                    { key: "afternoonGif", label: qsTr("Afternoon"), hint: "12:00 – 17:00", fallback: "afternoon.gif" },
                    { key: "eveningGif", label: qsTr("Evening"), hint: "17:00 – 20:00", fallback: "evening.gif" },
                    { key: "nightGif", label: qsTr("Night"), hint: "20:00 – 05:00", fallback: "night.gif" }
                ]

                StyledClippingRect {
                    id: card

                    required property int index
                    required property var modelData
                    readonly property string currentValue: Config.bar.activeWindow[modelData.key] ?? ""
                    readonly property bool isCustom: currentValue !== ""
                    readonly property string previewSource: isCustom
                        ? (currentValue.startsWith("/") ? "file://" + currentValue : currentValue)
                        : `${Quickshell.shellDir}/assets/${modelData.fallback}`

                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 0.62
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3surfaceContainerHigh

                    AnimatedImage {
                        anchors.fill: parent
                        source: card.previewSource
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        asynchronous: true
                        playing: true
                    }

                    // Bottom gradient so the label stays readable over any image.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * 0.5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.alpha(Colours.palette.m3scrim, 0.75) }
                        }
                    }

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Tokens.padding.medium
                        spacing: 0

                        StyledText {
                            text: card.modelData.label
                            font: Tokens.font.body.small
                            color: "white"
                        }

                        StyledText {
                            text: card.isCustom ? qsTr("Custom image") : card.modelData.hint
                            font: Tokens.font.label.small
                            color: Qt.alpha("white", 0.7)
                        }
                    }

                    // Reset badge, top-right, only while a custom image is set.
                    StyledClippingRect {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Tokens.padding.small
                        visible: card.isCustom
                        implicitWidth: resetIcon.implicitWidth + Tokens.padding.small * 2
                        implicitHeight: resetIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: Qt.alpha(Colours.palette.m3scrim, 0.55)

                        MaterialIcon {
                            id: resetIcon
                            anchors.centerIn: parent
                            text: "restart_alt"
                            color: "white"
                            fontStyle: Tokens.font.icon.small
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: GlobalConfig.bar.activeWindow[card.modelData.key] = ""
                        }
                    }

                    // Whole-card tap opens the picker.
                    StateLayer {
                        radius: card.radius
                        onClicked: gifDialog.open()
                    }

                    FileDialog {
                        id: gifDialog

                        title: qsTr("Select a greeting image")
                        filterLabel: qsTr("Image files")
                        filters: Images.validImageExtensions
                        onAccepted: path => GlobalConfig.bar.activeWindow[card.modelData.key] = path
                    }
                }
            }
        }
    }
}
