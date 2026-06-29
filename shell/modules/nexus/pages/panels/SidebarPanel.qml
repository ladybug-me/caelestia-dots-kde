pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Sidebar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            checked: Config.sidebar.enabled
            onToggled: GlobalConfig.sidebar.enabled = checked
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the sidebar opens")
            value: Config.sidebar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.sidebar.dragThreshold = v
        }

        // AI Assistant
        SectionHeader {
            text: qsTr("AI Assistant")
        }

        PopupRow {
            Layout.fillWidth: true
            first: true
            icon: "info"
            label: qsTr("Instructions & Setup")

            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("Caelestia\'s AI assistant runs entirely locally using Ollama for maximum privacy. No API keys are required!\n\nTo enable it:\n1. Install Ollama (e.g. \'sudo pacman -S ollama\')\n2. Start the Ollama daemon\n3. Download a model (e.g., \'ollama run llama3\')\n\nOnce Ollama is running on port 11434, the assistant connects automatically.")
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Enable Assistant")
            subtext: qsTr("Show the AI Assistant in the sidebar")
            checked: GlobalConfig.ai.enableOllama
            onToggled: GlobalConfig.ai.enableOllama = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            text: qsTr("Enable Tool Usage")
            subtext: qsTr("Allow the assistant to search the web, take screenshots, etc.")
            checked: GlobalConfig.ai.enableCelestialMode
            onToggled: GlobalConfig.ai.enableCelestialMode = checked
        }

        // OSD Sliders
        SectionHeader {
            text: qsTr("OSD Sliders")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Volume slider")
            subtext: qsTr("Show the volume OSD slider")
            checked: Config.osd.enableVolume
            onToggled: GlobalConfig.osd.enableVolume = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Microphone slider")
            subtext: qsTr("Show the microphone OSD slider")
            checked: Config.osd.enableMicrophone
            onToggled: GlobalConfig.osd.enableMicrophone = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            text: qsTr("Brightness slider")
            subtext: qsTr("Show the brightness OSD slider")
            checked: Config.osd.enableBrightness
            onToggled: GlobalConfig.osd.enableBrightness = checked
        }

        // Sidebar Tabs
        SectionHeader {
            text: qsTr("Sidebar Tabs")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Show News tab")
            subtext: qsTr("Show the News tab in the sidebar")
            checked: GlobalConfig.ai.showNews
            onToggled: GlobalConfig.ai.showNews = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            text: qsTr("Show Caelestia Mode")
            subtext: qsTr("Show the Caelestia Mode toggle at the bottom of notifications")
            checked: GlobalConfig.ai.showCaelestiaMode
            onToggled: GlobalConfig.ai.showCaelestiaMode = checked
        }

        // Utilities Panel
        SectionHeader {
            text: qsTr("Utilities Panel")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: qsTr("Show Keep Awake")
            subtext: qsTr("Show the Keep Awake card")
            checked: Config.utilities.showKeepAwake
            onToggled: GlobalConfig.utilities.showKeepAwake = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Show Screen Recorder")
            subtext: qsTr("Show the Screen Recorder card")
            checked: Config.utilities.showScreenRecorder
            onToggled: GlobalConfig.utilities.showScreenRecorder = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            text: qsTr("Show Quick Toggles")
            subtext: qsTr("Show the Quick Toggles card")
            checked: Config.utilities.showQuickToggles
            onToggled: GlobalConfig.utilities.showQuickToggles = checked
        }

        // Quick Toggles
        SectionHeader {
            text: qsTr("Quick Toggles")
        }

        Repeater {
            id: toggleRepeater
            model: [
                { id: "wifi",           label: qsTr("Wi-Fi") },
                { id: "bluetooth",      label: qsTr("Bluetooth") },
                { id: "mic",            label: qsTr("Microphone") },
                { id: "settings",       label: qsTr("Settings") },
                { id: "colorpicker",    label: qsTr("Color Picker") },
                { id: "dnd",            label: qsTr("Do Not Disturb") },
                { id: "vpn",            label: qsTr("VPN") },
                { id: "wallpaper",      label: qsTr("Wallpaper") },
                { id: "badapple",       label: qsTr("Bad Apple") },
                { id: "pauseWallpaper", label: qsTr("Pause Wallpaper") },
            ]

            delegate: ToggleRow {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: index === toggleRepeater.count - 1
                Layout.topMargin: index === 0 ? 0 : Tokens.spacing.extraSmall / 2 - parent.spacing
                text: modelData.label
                checked: {
                    const arr = Config.utilities.quickToggles || [];
                    const item = arr.find(t => t.id === modelData.id);
                    return item ? item.enabled !== false : true;
                }
                onToggled: {
                    const arr = JSON.parse(JSON.stringify(GlobalConfig.utilities.quickToggles || []));
                    const idx = arr.findIndex(t => t.id === modelData.id);
                    if (idx >= 0) {
                        arr[idx].enabled = checked;
                    } else {
                        arr.push({ id: modelData.id, enabled: checked });
                    }
                    GlobalConfig.utilities.quickToggles = arr;
                }
            }
        }
    }
}
