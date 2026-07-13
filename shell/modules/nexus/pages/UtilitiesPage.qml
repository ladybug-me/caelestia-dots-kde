pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Utilities")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Game mode")
        }

        NavRow {
            first: true
            last: true
            icon: "sports_esports"
            label: qsTr("Game mode")
            status: qsTr("Auto-enable rules and performance overrides")
            onClicked: root.nState.openSubPage(1)
        }

        SectionHeader {
            text: qsTr("AI Assistant")
        }

        PopupRow {
            first: true
            icon: "info"
            label: qsTr("Instructions & Setup")

            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("Caelestia's AI assistant runs entirely locally using Ollama for maximum privacy. No API keys are required!\n\nTo enable it:\n1. Install Ollama (e.g. 'sudo pacman -S ollama')\n2. Start the Ollama daemon\n3. Download a model (e.g., 'ollama run llama3')\n\nOnce Ollama is running on port 11434, the assistant connects automatically.")
            }
        }

        ToggleRow {
            text: qsTr("Enable Assistant")
            subtext: qsTr("Show the AI Assistant in the sidebar")
            checked: GlobalConfig.ai.enableOllama
            onToggled: GlobalConfig.ai.enableOllama = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Enable Tool Usage")
            subtext: qsTr("Allow the assistant to search the web, take screenshots, etc.")
            checked: GlobalConfig.ai.enableCelestialMode
            onToggled: GlobalConfig.ai.enableCelestialMode = checked
        }

        SectionHeader {
            text: qsTr("OSD sliders")
        }

        ToggleRow {
            first: true
            text: qsTr("Volume slider")
            subtext: qsTr("Show the volume OSD slider")
            checked: Config.osd.enableVolume
            onToggled: GlobalConfig.osd.enableVolume = checked
        }

        ToggleRow {
            text: qsTr("Microphone slider")
            subtext: qsTr("Show the microphone OSD slider")
            checked: Config.osd.enableMicrophone
            onToggled: GlobalConfig.osd.enableMicrophone = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Brightness slider")
            subtext: qsTr("Show the brightness OSD slider")
            checked: Config.osd.enableBrightness
            onToggled: GlobalConfig.osd.enableBrightness = checked
        }

        SectionHeader {
            text: qsTr("Utilities panel")
        }

        ToggleRow {
            first: true
            text: qsTr("Show Keep Awake")
            subtext: qsTr("Show the Keep Awake card")
            checked: Config.utilities.showKeepAwake
            onToggled: GlobalConfig.utilities.showKeepAwake = checked
        }

        ToggleRow {
            text: qsTr("Show Screen Recorder")
            subtext: qsTr("Show the Screen Recorder card")
            checked: Config.utilities.showScreenRecorder
            onToggled: GlobalConfig.utilities.showScreenRecorder = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Show Quick Toggles")
            subtext: qsTr("Show the Quick Toggles card")
            checked: Config.utilities.showQuickToggles
            onToggled: GlobalConfig.utilities.showQuickToggles = checked
        }

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
                { id: "colorpicker",    label: Strings.localizeEnglishSpelling(qsTr("Colour Picker")) },
                { id: "dnd",            label: qsTr("Do Not Disturb") },
                { id: "vpn",            label: qsTr("VPN") },
                { id: "wallpaper",      label: qsTr("Wallpaper") },
                { id: "badapple",       label: qsTr("Bad Apple") },
                { id: "pauseWallpaper", label: qsTr("Pause Wallpaper") },
            ]

            delegate: ToggleRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === toggleRepeater.count - 1
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
