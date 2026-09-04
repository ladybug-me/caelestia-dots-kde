pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.utils
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
            checked: root.nState.targetConfig.dashboard.enabled
            onToggled: Globalroot.nState.targetConfig.dashboard.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            checked: root.nState.targetConfig.dashboard.showOnHover
            onToggled: Globalroot.nState.targetConfig.dashboard.showOnHover = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: qsTr("Dashboard profile picture shape")
            subtext: qsTr("Choose the shape of the profile picture on the dashboard")
            fallbackIcon: "person"
            fallbackText: qsTr("Pill")
            active: {
                for (let i = 0; i < dashboardShapeItems.length; i++) {
                    if (dashboardShapeItems[i].value === Globalroot.nState.targetConfig.dashboard.profilePicShape)
                        return dashboardShapeItems[i];
                }
                return dashboardShapeItems[0];
            }
            menuItems: dashboardShapeItems
            onSelected: item => {
                Globalroot.nState.targetConfig.dashboard.profilePicShape = item.value
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
                    if (lockShapeItems[i].value === Globalroot.nState.targetConfig.lock.profilePicShape)
                        return lockShapeItems[i];
                }
                return lockShapeItems[0];
            }
            menuItems: lockShapeItems
            onSelected: item => {
                Globalroot.nState.targetConfig.lock.profilePicShape = item.value
            }
        }

        // Tabs
        SectionHeader {
            text: qsTr("Tabs")
        }

        ToggleRow {
            first: true
            text: qsTr("Dashboard")
            checked: root.nState.targetConfig.dashboard.showDashboard
            onToggled: Globalroot.nState.targetConfig.dashboard.showDashboard = checked
        }

        ToggleRow {
            text: qsTr("Media")
            checked: root.nState.targetConfig.dashboard.showMedia
            onToggled: Globalroot.nState.targetConfig.dashboard.showMedia = checked
        }

        ToggleRow {
            text: qsTr("Performance")
            checked: root.nState.targetConfig.dashboard.showPerformance
            onToggled: Globalroot.nState.targetConfig.dashboard.showPerformance = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Weather")
            checked: root.nState.targetConfig.dashboard.showWeather
            onToggled: Globalroot.nState.targetConfig.dashboard.showWeather = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Terminal")
            checked: root.nState.targetConfig.dashboard.showTerminal
            onToggled: Globalroot.nState.targetConfig.dashboard.showTerminal = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Recolor media GIF")
            subtext: qsTr("Apply system theme colors to the media GIF")
            checked: root.nState.targetConfig.dashboard.colorizeMediaGif
            onToggled: Globalroot.nState.targetConfig.dashboard.colorizeMediaGif = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Use material shapes")
            subtext: qsTr("Replace the media GIF with audio-reactive material shapes")
            checked: root.nState.targetConfig.dashboard.useMediaShapes
            onToggled: Globalroot.nState.targetConfig.dashboard.useMediaShapes = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Randomize shape colors")
            subtext: qsTr("Randomly shift shape colors while morphing")
            checked: root.nState.targetConfig.dashboard.randomizeMediaShapeColors
            onToggled: Globalroot.nState.targetConfig.dashboard.randomizeMediaShapeColors = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: qsTr("Sync with music")
            subtext: qsTr("Randomly pick shapes to the beat instead of bass level")
            checked: root.nState.targetConfig.dashboard.syncMediaShapesToBeat
            onToggled: Globalroot.nState.targetConfig.dashboard.syncMediaShapesToBeat = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: qsTr("Welcome splash")
            visible: typeof KWinActiveWindowBridge === "undefined"
            subtext: qsTr("Show a welcome message on the dashboard")
            checked: root.nState.targetConfig.dashboard.showHyprlandSplash
            onToggled: Globalroot.nState.targetConfig.dashboard.showHyprlandSplash = checked
        }

        // Performance widgets
        SectionHeader {
            text: qsTr("Performance widgets")
        }

        ToggleRow {
            first: true
            text: qsTr("Battery")
            checked: root.nState.targetConfig.dashboard.performance.showBattery
            onToggled: Globalroot.nState.targetConfig.dashboard.performance.showBattery = checked
        }

        ToggleRow {
            text: qsTr("GPU")
            checked: root.nState.targetConfig.dashboard.performance.showGpu
            onToggled: Globalroot.nState.targetConfig.dashboard.performance.showGpu = checked
        }

        ToggleRow {
            text: qsTr("CPU")
            checked: root.nState.targetConfig.dashboard.performance.showCpu
            onToggled: Globalroot.nState.targetConfig.dashboard.performance.showCpu = checked
        }

        ToggleRow {
            text: qsTr("Memory")
            checked: root.nState.targetConfig.dashboard.performance.showMemory
            onToggled: Globalroot.nState.targetConfig.dashboard.performance.showMemory = checked
        }

        ToggleRow {
            text: qsTr("Storage")
            checked: root.nState.targetConfig.dashboard.performance.showStorage
            onToggled: Globalroot.nState.targetConfig.dashboard.performance.showStorage = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Network")
            checked: root.nState.targetConfig.dashboard.performance.showNetwork
            onToggled: Globalroot.nState.targetConfig.dashboard.performance.showNetwork = checked
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behavior")
        }

        StepperRow {
            first: true
            label: qsTr("Hover trigger depth")
            subtext: qsTr("Distance in from the screen edge that opens the dashboard")
            value: root.nState.targetConfig.dashboard.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.dashboard.hoverThickness = v
        }

        StepperRow {
            label: qsTr("Hover trigger width")
            subtext: qsTr("How much of the top edge opens the dashboard, as a percentage of its width")
            value: root.nState.targetConfig.dashboard.hoverWidth
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.dashboard.hoverWidth = v
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the dashboard opens")
            value: root.nState.targetConfig.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.dashboard.dragThreshold = v
        }
    }
}
