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
import qs.services

PageBase {
    id: root

    title: I18n.tr("Dashboard")
    isSubPage: true

    readonly property list<MenuItem> dashboardShapeItems: [
        MenuItem {
            property int value: MaterialShape.Circle

            text: I18n.tr("Circle")
        },
        MenuItem {
            property int value: MaterialShape.Square

            text: I18n.tr("Square")
        },
        MenuItem {
            property int value: MaterialShape.Pill

            text: I18n.tr("Pill")
        },
        MenuItem {
            property int value: MaterialShape.Diamond

            text: I18n.tr("Diamond")
        },
        MenuItem {
            property int value: MaterialShape.ClamShell

            text: I18n.tr("Clam Shell")
        },
        MenuItem {
            property int value: MaterialShape.Pentagon

            text: I18n.tr("Pentagon")
        },
        MenuItem {
            property int value: MaterialShape.Gem

            text: I18n.tr("Gem")
        },
        MenuItem {
            property int value: MaterialShape.Cookie4Sided

            text: I18n.tr("Cookie 4-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie6Sided

            text: I18n.tr("Cookie 6-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie7Sided

            text: I18n.tr("Cookie 7-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie9Sided

            text: I18n.tr("Cookie 9-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie12Sided

            text: I18n.tr("Cookie 12-Sided")
        }
    ]

    readonly property list<MenuItem> lockShapeItems: [
        MenuItem {
            property int value: MaterialShape.Circle

            text: I18n.tr("Circle")
        },
        MenuItem {
            property int value: MaterialShape.Square

            text: I18n.tr("Square")
        },
        MenuItem {
            property int value: MaterialShape.Pill

            text: I18n.tr("Pill")
        },
        MenuItem {
            property int value: MaterialShape.Diamond

            text: I18n.tr("Diamond")
        },
        MenuItem {
            property int value: MaterialShape.ClamShell

            text: I18n.tr("Clam Shell")
        },
        MenuItem {
            property int value: MaterialShape.Pentagon

            text: I18n.tr("Pentagon")
        },
        MenuItem {
            property int value: MaterialShape.Gem

            text: I18n.tr("Gem")
        },
        MenuItem {
            property int value: MaterialShape.Cookie4Sided

            text: I18n.tr("Cookie 4-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie6Sided

            text: I18n.tr("Cookie 6-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie7Sided

            text: I18n.tr("Cookie 7-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie9Sided

            text: I18n.tr("Cookie 9-Sided")
        },
        MenuItem {
            property int value: MaterialShape.Cookie12Sided

            text: I18n.tr("Cookie 12-Sided")
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
            text: I18n.tr("General")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Enabled")
            checked: Config.dashboard.enabled
            onToggled: GlobalConfig.dashboard.enabled = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: I18n.tr("Show on hover")
            subtext: I18n.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.dashboard.showOnHover
            onToggled: GlobalConfig.dashboard.showOnHover = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: I18n.tr("Dashboard profile picture shape")
            subtext: I18n.tr("Choose the shape of the profile picture on the dashboard")
            fallbackIcon: "person"
            fallbackText: I18n.tr("Pill")
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
            label: I18n.tr("Lock screen profile picture shape")
            subtext: I18n.tr("Choose the shape of the profile picture on the lock screen")
            fallbackIcon: "lock"
            fallbackText: I18n.tr("Clam Shell")
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
            text: I18n.tr("Tabs")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Dashboard")
            checked: Config.dashboard.showDashboard
            onToggled: GlobalConfig.dashboard.showDashboard = checked
        }

        ToggleRow {
            text: I18n.tr("Media")
            checked: Config.dashboard.showMedia
            onToggled: GlobalConfig.dashboard.showMedia = checked
        }

        ToggleRow {
            text: I18n.tr("Performance")
            checked: Config.dashboard.showPerformance
            onToggled: GlobalConfig.dashboard.showPerformance = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: I18n.tr("Weather")
            checked: Config.dashboard.showWeather
            onToggled: GlobalConfig.dashboard.showWeather = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: I18n.tr("Terminal")
            checked: Config.dashboard.showTerminal
            onToggled: GlobalConfig.dashboard.showTerminal = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: Strings.localizeEnglishSpelling(I18n.tr("Recolour media GIF"))
            subtext: Strings.localizeEnglishSpelling(I18n.tr("Apply system theme colours to the media GIF"))
            checked: Config.dashboard.colorizeMediaGif
            onToggled: GlobalConfig.dashboard.colorizeMediaGif = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: I18n.tr("Use material shapes")
            subtext: I18n.tr("Replace the media GIF with audio-reactive material shapes")
            checked: Config.dashboard.useMediaShapes
            onToggled: GlobalConfig.dashboard.useMediaShapes = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: Strings.localizeEnglishSpelling(I18n.tr("Randomize shape colours"))
            subtext: Strings.localizeEnglishSpelling(I18n.tr("Randomly shift shape colours while morphing"))
            checked: Config.dashboard.randomizeMediaShapeColors
            onToggled: GlobalConfig.dashboard.randomizeMediaShapeColors = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            text: I18n.tr("Sync with music")
            subtext: I18n.tr("Randomly pick shapes to the beat instead of bass level")
            checked: Config.dashboard.syncMediaShapesToBeat
            onToggled: GlobalConfig.dashboard.syncMediaShapesToBeat = checked
        }

        ToggleRow {
            Layout.fillWidth: true
            last: true
            text: I18n.tr("Welcome splash")
            visible: typeof KWinActiveWindowBridge === "undefined"
            subtext: I18n.tr("Show a welcome message on the dashboard")
            checked: Config.dashboard.showHyprlandSplash
            onToggled: GlobalConfig.dashboard.showHyprlandSplash = checked
        }

        // Performance widgets
        SectionHeader {
            text: I18n.tr("Performance widgets")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Battery")
            checked: Config.dashboard.performance.showBattery
            onToggled: GlobalConfig.dashboard.performance.showBattery = checked
        }

        ToggleRow {
            text: I18n.tr("GPU")
            checked: Config.dashboard.performance.showGpu
            onToggled: GlobalConfig.dashboard.performance.showGpu = checked
        }

        ToggleRow {
            text: I18n.tr("CPU")
            checked: Config.dashboard.performance.showCpu
            onToggled: GlobalConfig.dashboard.performance.showCpu = checked
        }

        ToggleRow {
            text: I18n.tr("Memory")
            checked: Config.dashboard.performance.showMemory
            onToggled: GlobalConfig.dashboard.performance.showMemory = checked
        }

        ToggleRow {
            text: I18n.tr("Storage")
            checked: Config.dashboard.performance.showStorage
            onToggled: GlobalConfig.dashboard.performance.showStorage = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Network")
            checked: Config.dashboard.performance.showNetwork
            onToggled: GlobalConfig.dashboard.performance.showNetwork = checked
        }

        // Behaviour
        SectionHeader {
            text: Strings.localizeEnglishSpelling(I18n.tr("Behaviour"))
        }

        StepperRow {
            first: true
            label: I18n.tr("Hover trigger depth")
            subtext: I18n.tr("Distance in from the screen edge that opens the dashboard")
            value: Config.dashboard.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => GlobalConfig.dashboard.hoverThickness = v
        }

        StepperRow {
            label: I18n.tr("Hover trigger width")
            subtext: I18n.tr("How much of the top edge opens the dashboard, as a percentage of its width")
            value: Config.dashboard.hoverWidth
            from: 10
            to: 100
            stepSize: 5
            onMoved: v => GlobalConfig.dashboard.hoverWidth = v
        }

        StepperRow {
            last: true
            label: I18n.tr("Drag threshold")
            subtext: I18n.tr("Pixels dragged before the dashboard opens")
            value: Config.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.dashboard.dragThreshold = v
        }
    }
}
