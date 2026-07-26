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
                text: qsTr("The AI Assistant supports several providers:\n\n• Claude Code (recommended) — uses your Claude subscription through the 'claude' CLI. No API key needed.\n• Ollama — fully local models for maximum privacy (install Ollama, then e.g. 'ollama run llama3').\n• Claude API, ChatGPT, Gemini, OpenRouter — pay-per-token; each needs its own API key (or the matching ANTHROPIC_API_KEY / OPENAI_API_KEY / GEMINI_API_KEY / OPENROUTER_API_KEY env var, which takes precedence).\n\nInstall Claude Code, log in, add accounts, toggle providers and enter keys in Settings → AI Assistant. Pick the active provider and model from the selectors at the top of the chat.\n\nThe assistant tab appears in the sidebar whenever at least one provider is enabled.")
            }
        }

        ToggleRow {
            text: qsTr("Enable AI Assistant")
            subtext: qsTr("Show the AI Assistant tab in the sidebar — manage providers in Settings → AI Assistant")
            checked: GlobalConfig.ai.enableAiAssistant
            onToggled: GlobalConfig.ai.enableAiAssistant = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Enable Tool Usage")
            subtext: qsTr("Lets Ollama / Claude API models use built-in tools (web search, screenshots…). Claude Code has its own agent tools and ignores this.")
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
            text: qsTr("Clipboard")
        }

        StepperRow {
            first: true
            last: true
            label: qsTr("Maximum entries")
            subtext: qsTr("Limits the number of clipboard entries loaded by the launcher")
            value: GlobalConfig.launcher.clipboardMaxEntries
            from: 1
            to: 2048
            stepSize: 10
            onMoved: v => GlobalConfig.launcher.clipboardMaxEntries = v
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
                { id: "restartShell",   label: qsTr("Restart Shell") },
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
