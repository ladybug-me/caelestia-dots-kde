pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import M3Shapes
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Dashboard")
    isSubPage: true

    readonly property list<MenuItem> dashboardShapeItems: [
        MenuItem {
            property int value: MaterialShape.Circle
            text: qsTr("Circle")
        },
        MenuItem {
            property int value: MaterialShape.Square
            text: qsTr("Square")
        },
        MenuItem {
            property int value: MaterialShape.Pill
            text: qsTr("Pill")
        },
        MenuItem {
            property int value: MaterialShape.Diamond
            text: qsTr("Diamond")
        },
        MenuItem {
            property int value: MaterialShape.ClamShell
            text: qsTr("Clam Shell")
        },
        MenuItem {
            property int value: MaterialShape.Pentagon
            text: qsTr("Pentagon")
        },
        MenuItem {
            property int value: MaterialShape.Gem
            text: qsTr("Gem")
        },
        MenuItem {
            property int value: MaterialShape.Cookie4Sided
            text: qsTr("Cookie 4-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie6Sided
            text: qsTr("Cookie 6-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie7Sided
            text: qsTr("Cookie 7-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie9Sided
            text: qsTr("Cookie 9-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie12Sided
            text: qsTr("Cookie 12-Sided")
        }
    ]

    readonly property list<MenuItem> lockShapeItems: [
        MenuItem {
            property int value: MaterialShape.Circle
            text: qsTr("Circle")
        },
        MenuItem {
            property int value: MaterialShape.Square
            text: qsTr("Square")
        },
        MenuItem {
            property int value: MaterialShape.Pill
            text: qsTr("Pill")
        },
        MenuItem {
            property int value: MaterialShape.Diamond
            text: qsTr("Diamond")
        },
        MenuItem {
            property int value: MaterialShape.ClamShell
            text: qsTr("Clam Shell")
        },
        MenuItem {
            property int value: MaterialShape.Pentagon
            text: qsTr("Pentagon")
        },
        MenuItem {
            property int value: MaterialShape.Gem
            text: qsTr("Gem")
        },
        MenuItem {
            property int value: MaterialShape.Cookie4Sided
            text: qsTr("Cookie 4-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie6Sided
            text: qsTr("Cookie 6-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie7Sided
            text: qsTr("Cookie 7-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie9Sided
            text: qsTr("Cookie 9-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie12Sided
            text: qsTr("Cookie 12-Sided")
        }
    ]

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
            checked: Config.dashboard.enabled
            onToggled: GlobalConfig.dashboard.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            checked: Config.dashboard.showOnHover
            onToggled: GlobalConfig.dashboard.showOnHover = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: qsTr("Dashboard profile picture shape")
            subtext: qsTr("Choose the shape of the profile picture on the dashboard")
            fallbackIcon: "person"
            fallbackText: qsTr("Pill")
            active: {
                for (let i = 0; i < dashboardShapeItems.length; i++) {
                    if (dashboardShapeItems[i].value === GlobalConfig.dashboard.profilePicShape)
                        return dashboardShapeItems[i];
                }
                return dashboardShapeItems[0];
            }
            menuItems: dashboardShapeItems
            onSelected: item => {
                GlobalConfig.dashboard.profilePicShape = item.value
            }
        }

        SelectRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("Lock screen profile picture shape")
            subtext: qsTr("Choose the shape of the profile picture on the lock screen")
            fallbackIcon: "lock"
            fallbackText: qsTr("Clam Shell")
            active: {
                for (let i = 0; i < lockShapeItems.length; i++) {
                    if (lockShapeItems[i].value === GlobalConfig.lock.profilePicShape)
                        return lockShapeItems[i];
                }
                return lockShapeItems[0];
            }
            menuItems: lockShapeItems
            onSelected: item => {
                GlobalConfig.lock.profilePicShape = item.value
            }
        }

        // Tabs
        SectionHeader {
            text: qsTr("Tabs")
        }

        ToggleRow {
            first: true
            text: qsTr("Dashboard")
            checked: Config.dashboard.showDashboard
            onToggled: GlobalConfig.dashboard.showDashboard = checked
        }

        ToggleRow {
            text: qsTr("Media")
            checked: Config.dashboard.showMedia
            onToggled: GlobalConfig.dashboard.showMedia = checked
        }

        ToggleRow {
            text: qsTr("Performance")
            checked: Config.dashboard.showPerformance
            onToggled: GlobalConfig.dashboard.showPerformance = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Weather")
            checked: Config.dashboard.showWeather
            onToggled: GlobalConfig.dashboard.showWeather = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Terminal")
            checked: Config.dashboard.showTerminal
            onToggled: GlobalConfig.dashboard.showTerminal = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Recolor media GIF")
            subtext: qsTr("Apply system theme colors to the media GIF")
            checked: Config.dashboard.colorizeMediaGif
            onToggled: GlobalConfig.dashboard.colorizeMediaGif = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Use material shapes")
            subtext: qsTr("Replace the media GIF with audio-reactive material shapes")
            checked: Config.dashboard.useMediaShapes
            onToggled: GlobalConfig.dashboard.useMediaShapes = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Randomize shape colors")
            subtext: qsTr("Randomly shift shape colors while morphing")
            checked: Config.dashboard.randomizeMediaShapeColors
            onToggled: GlobalConfig.dashboard.randomizeMediaShapeColors = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Sync with music")
            subtext: qsTr("Randomly pick shapes to the beat instead of bass level")
            checked: Config.dashboard.syncMediaShapesToBeat
            onToggled: GlobalConfig.dashboard.syncMediaShapesToBeat = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: qsTr("Hyprland splash")
            visible: Quickshell.env("XDG_CURRENT_DESKTOP").includes("Hyprland")
            subtext: qsTr("Show the current Hyprland splash text")
            checked: Config.dashboard.showHyprlandSplash
            onToggled: GlobalConfig.dashboard.showHyprlandSplash = checked
        }

        // Performance widgets
        SectionHeader {
            text: qsTr("Performance widgets")
        }

        ToggleRow {
            first: true
            text: qsTr("Battery")
            checked: Config.dashboard.performance.showBattery
            onToggled: GlobalConfig.dashboard.performance.showBattery = checked
        }

        ToggleRow {
            text: qsTr("GPU")
            checked: Config.dashboard.performance.showGpu
            onToggled: GlobalConfig.dashboard.performance.showGpu = checked
        }

        ToggleRow {
            text: qsTr("CPU")
            checked: Config.dashboard.performance.showCpu
            onToggled: GlobalConfig.dashboard.performance.showCpu = checked
        }

        ToggleRow {
            text: qsTr("Memory")
            checked: Config.dashboard.performance.showMemory
            onToggled: GlobalConfig.dashboard.performance.showMemory = checked
        }

        ToggleRow {
            text: qsTr("Storage")
            checked: Config.dashboard.performance.showStorage
            onToggled: GlobalConfig.dashboard.performance.showStorage = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Network")
            checked: Config.dashboard.performance.showNetwork
            onToggled: GlobalConfig.dashboard.performance.showNetwork = checked
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        StepperRow {
            first: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the dashboard opens")
            value: Config.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.dashboard.dragThreshold = v
        }
    }
}
