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
                text: qsTr("Caelestia’s AI assistant runs entirely locally using Ollama for maximum privacy. No API keys are required!\n\nTo enable it:\n1. Install Ollama (e.g. 'sudo pacman -S ollama')\n2. Start the Ollama daemon\n3. Download a model (e.g., 'ollama run llama3')\n\nOnce Ollama is running on port 11434, the assistant connects automatically.")
            }
        }

        ToggleRow {
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
    }
}
