pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
            Layout.bottomMargin: Tokens.spacing.extraSmall
            text: qsTr("Shown in the active-window popout when no window is focused. A different image is used for each time of day; leave empty to use the bundled default.")
            font: Tokens.font.label.small
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.WordWrap
        }

        // One picker row per time-of-day slot.
        Repeater {
            model: [
                { key: "morningGif", label: qsTr("Morning image"), hint: qsTr("Shown 05:00–12:00") },
                { key: "afternoonGif", label: qsTr("Afternoon image"), hint: qsTr("Shown 12:00–17:00") },
                { key: "eveningGif", label: qsTr("Evening image"), hint: qsTr("Shown 17:00–20:00") },
                { key: "nightGif", label: qsTr("Night image"), hint: qsTr("Shown 20:00–05:00") }
            ]

            ColumnLayout {
                id: slot

                required property int index
                required property var modelData
                readonly property string currentValue: Config.bar.activeWindow[modelData.key] ?? ""

                Layout.fillWidth: true
                spacing: 0

                NavRow {
                    first: slot.index === 0
                    last: slot.currentValue === ""
                    icon: "image"
                    label: slot.modelData.label
                    status: slot.currentValue !== "" ? slot.currentValue : slot.modelData.hint
                    onClicked: gifDialog.open()

                    FileDialog {
                        id: gifDialog

                        title: qsTr("Select a greeting image")
                        filterLabel: qsTr("Image files")
                        filters: Images.validImageExtensions
                        onAccepted: path => GlobalConfig.bar.activeWindow[slot.modelData.key] = path
                    }
                }

                // Reset-to-default row, only while a custom image is set.
                NavRow {
                    visible: slot.currentValue !== ""
                    last: true
                    icon: "restart_alt"
                    label: qsTr("Reset to default")
                    onClicked: GlobalConfig.bar.activeWindow[slot.modelData.key] = ""
                }
            }
        }
    }
}
