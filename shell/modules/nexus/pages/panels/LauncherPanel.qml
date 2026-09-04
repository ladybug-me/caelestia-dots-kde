pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Launcher")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            checked: root.nState.targetConfig.launcher.enabled
            onToggled: Globalroot.nState.targetConfig.launcher.enabled = checked
        }

        ToggleRow {
            text: qsTr("Use alternative logo")
            subtext: qsTr("Use the Caelestia logo or a custom image instead of your distribution's logo")
            checked: Globalroot.nState.targetConfig.general.logo !== ""
            onToggled: {
                if (checked) {
                    if (Globalroot.nState.targetConfig.general.logo === "") {
                        Globalroot.nState.targetConfig.general.logo = "caelestia";
                    }
                } else {
                    Globalroot.nState.targetConfig.general.logo = "";
                }
            }
        }

        NavRow {
            visible: Globalroot.nState.targetConfig.general.logo !== ""
            icon: "image"
            label: qsTr("Pick custom logo")
            status: Globalroot.nState.targetConfig.general.logo.includes("/") ? Globalroot.nState.targetConfig.general.logo : qsTr("Select an image from your local files")
            onClicked: customLogoDialog.open()

            FileDialog {
                id: customLogoDialog

                title: qsTr("Select a custom logo")
                filterLabel: qsTr("Image files")
                filters: Images.validImageExtensions
                onAccepted: path => {
                    Globalroot.nState.targetConfig.general.logo = path;
                }
            }
        }

        NavRow {
            visible: Globalroot.nState.targetConfig.general.logo !== ""
            icon: "palette"
            label: qsTr("Select KDE icon")
            status: Globalroot.nState.targetConfig.general.logo && Globalroot.nState.targetConfig.general.logo !== "caelestia" && !Globalroot.nState.targetConfig.general.logo.includes("/") ? Globalroot.nState.targetConfig.general.logo : qsTr("Pick an icon from your system theme")
            onClicked: kdeIconProcess.running = true

            Process {
                id: kdeIconProcess

                command: ["kdialog", "--geticon", "Select Icon"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let res = text.trim();
                        if (res) {
                            Globalroot.nState.targetConfig.general.logo = res;
                        }
                    }
                }
            }
        }

        ToggleRow {
            visible: Globalroot.nState.targetConfig.general.logo !== "" && Globalroot.nState.targetConfig.general.logo !== "caelestia"
            text: qsTr("Tint custom logo")
            subtext: qsTr("Apply the Material You accent color to your custom logo")
            checked: SysInfo.recolourCustomLogo
            onToggled: SysInfo.recolourCustomLogo = checked
        }

        StepperRow {
            visible: Globalroot.nState.targetConfig.general.logo !== "" && Globalroot.nState.targetConfig.general.logo !== "caelestia"
            label: qsTr("Logo size (%)")
            value: SysInfo.customLogoSize
            from: 50
            to: 200
            stepSize: 10
            onMoved: v => SysInfo.customLogoSize = v
        }

        ToggleRow {
            last: true
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            checked: root.nState.targetConfig.launcher.showOnHover
            onToggled: Globalroot.nState.targetConfig.launcher.showOnHover = checked
        }

        // Display
        SectionHeader {
            text: qsTr("Display")
        }

        ToggleRow {
            first: true
            text: qsTr("Browse apps when search is empty")
            subtext: qsTr("Show the categorized app grid in the launcher when the search field is empty")
            checked: root.nState.targetConfig.launcher.showBrowseOnEmpty
            onToggled: Globalroot.nState.targetConfig.launcher.showBrowseOnEmpty = checked
        }

        ToggleRow {
            text: qsTr("Show power menu")
            subtext: qsTr("Show the quick session controls (shutdown, sleep, logout) at the bottom")
            checked: root.nState.targetConfig.launcher.showPowerMenu
            onToggled: Globalroot.nState.targetConfig.launcher.showPowerMenu = checked
        }

        StepperRow {
            label: qsTr("Max items shown")
            value: root.nState.targetConfig.launcher.maxShown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.launcher.maxShown = v
        }

        StepperRow {
            label: qsTr("Max wallpapers")
            value: root.nState.targetConfig.launcher.maxWallpapers
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.launcher.maxWallpapers = v
        }

        StepperRow {
            label: qsTr("Hover trigger depth")
            subtext: qsTr("Distance in from the screen edge that opens the launcher")
            value: root.nState.targetConfig.launcher.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.launcher.hoverThickness = v
        }

        StepperRow {
            label: qsTr("Hover trigger width")
            subtext: qsTr("How much of the bottom edge opens the launcher, as a percentage of its width")
            value: root.nState.targetConfig.launcher.hoverWidth
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.launcher.hoverWidth = v
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the launcher opens")
            value: root.nState.targetConfig.launcher.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.launcher.dragThreshold = v
        }

        // Clipboard
        SectionHeader {
            text: qsTr("Clipboard")
        }

        StepperRow {
            first: true
            label: qsTr("Max clipboard entries")
            subtext: qsTr("Number of copied items kept in history")
            value: root.nState.targetConfig.launcher.clipboardMaxEntries
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.launcher.clipboardMaxEntries = v
        }

        ToggleRow {
            last: true
            text: qsTr("Confirm clear")
            subtext: qsTr("Ask before clearing the clipboard history")
            checked: Globalroot.nState.targetConfig.launcher.confirmClearClipboard
            onToggled: Globalroot.nState.targetConfig.launcher.confirmClearClipboard = checked
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behavior")
        }

        ToggleRow {
            first: true
            text: qsTr("Vim keybinds")
            subtext: qsTr("Navigate results with Ctrl+hjkl")
            checked: Globalroot.nState.targetConfig.launcher.vimKeybinds
            onToggled: Globalroot.nState.targetConfig.launcher.vimKeybinds = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Enable dangerous actions")
            subtext: qsTr("Allow actions that shut down or log out")
            checked: Globalroot.nState.targetConfig.launcher.enableDangerousActions
            onToggled: Globalroot.nState.targetConfig.launcher.enableDangerousActions = checked
        }

        // Fuzzy search
        SectionHeader {
            text: qsTr("Fuzzy search")
        }

        ToggleRow {
            first: true
            text: qsTr("Apps")
            checked: Globalroot.nState.targetConfig.launcher.useFuzzy.apps
            onToggled: Globalroot.nState.targetConfig.launcher.useFuzzy.apps = checked
        }

        ToggleRow {
            text: qsTr("Actions")
            checked: Globalroot.nState.targetConfig.launcher.useFuzzy.actions
            onToggled: Globalroot.nState.targetConfig.launcher.useFuzzy.actions = checked
        }

        ToggleRow {
            text: qsTr("Schemes")
            checked: Globalroot.nState.targetConfig.launcher.useFuzzy.schemes
            onToggled: Globalroot.nState.targetConfig.launcher.useFuzzy.schemes = checked
        }

        ToggleRow {
            text: qsTr("Variants")
            checked: Globalroot.nState.targetConfig.launcher.useFuzzy.variants
            onToggled: Globalroot.nState.targetConfig.launcher.useFuzzy.variants = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Wallpapers")
            checked: Globalroot.nState.targetConfig.launcher.useFuzzy.wallpapers
            onToggled: Globalroot.nState.targetConfig.launcher.useFuzzy.wallpapers = checked
        }
    }
}
