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

    readonly property list<MenuItem> layoutTypeItems: [
        MenuItem {
            property int value: 0

            text: qsTr("KDE Grid")
        },
        MenuItem {
            property int value: 1

            text: qsTr("GNOME Grid")
        }
    ]

    readonly property list<MenuItem> easingTypeItems: [
        MenuItem {
            property int value: 0

            text: qsTr("Linear")
        },
        MenuItem {
            property int value: 2

            text: qsTr("Quadratic Out")
        },
        MenuItem {
            property int value: 3

            text: qsTr("Quadratic In-Out")
        },
        MenuItem {
            property int value: 6

            text: qsTr("Cubic Out")
        },
        MenuItem {
            property int value: 10

            text: qsTr("Quartic Out")
        },
        MenuItem {
            property int value: 14

            text: qsTr("Quintic Out")
        },
        MenuItem {
            property int value: 18

            text: qsTr("Sine Out")
        },
        MenuItem {
            property int value: 22

            text: qsTr("Exponential Out")
        },
        MenuItem {
            property int value: 26

            text: qsTr("Circular Out")
        },
        MenuItem {
            property int value: 30

            text: qsTr("Elastic Out")
        },
        MenuItem {
            property int value: 33

            text: qsTr("Back In")
        },
        MenuItem {
            property int value: 34

            text: qsTr("Back Out")
        },
        MenuItem {
            property int value: 38

            text: qsTr("Bounce Out")
        }
    ]

    title: qsTr("Overview")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Activation")
        }
        ToggleRow {
            first: true
            text: qsTr("Enable overview")
            checked: Globalroot.nState.targetConfig.overview.enabled
            onToggled: Globalroot.nState.targetConfig.overview.enabled = checked
        }
        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Open overview by hovering a corner instead of dragging")
            checked: Globalroot.nState.targetConfig.overview.showOnHover
            onToggled: Globalroot.nState.targetConfig.overview.showOnHover = checked
        }
        StepperRow {
            label: qsTr("Trigger area size")
            last: Globalroot.nState.targetConfig.overview.showOnHover
            subtext: qsTr("Size of the corner activation areas in pixels")
            value: Globalroot.nState.targetConfig.overview.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => Globalroot.nState.targetConfig.overview.hoverThickness = v
            visible: Globalroot.nState.targetConfig.overview.showOnHover
        }
        StepperRow {
            last: !Globalroot.nState.targetConfig.overview.showOnHover
            label: qsTr("Drag threshold")
            subtext: qsTr("Distance to drag from corner to open overview")
            value: Globalroot.nState.targetConfig.overview.dragThreshold
            from: 10
            to: 200
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.overview.dragThreshold = v
            visible: !Globalroot.nState.targetConfig.overview.showOnHover
        }
        SectionHeader {
            text: qsTr("Corners")
        }
        // Enabling a corner takes it off KWin for as long as it stays enabled;
        // whatever KDE had bound there comes back untouched when it's turned
        // off, on shell exit, or on the next start after a crash.
        ToggleRow {
            first: true
            text: qsTr("Top-Left corner")
            checked: Globalroot.nState.targetConfig.overview.hoverTopLeft
            onToggled: Globalroot.nState.targetConfig.overview.hoverTopLeft = checked
        }
        ToggleRow {
            text: qsTr("Top-Right corner")
            checked: Globalroot.nState.targetConfig.overview.hoverTopRight
            onToggled: Globalroot.nState.targetConfig.overview.hoverTopRight = checked
        }
        ToggleRow {
            text: qsTr("Bottom-Left corner")
            checked: Globalroot.nState.targetConfig.overview.hoverBottomLeft
            onToggled: Globalroot.nState.targetConfig.overview.hoverBottomLeft = checked
        }
        ToggleRow {
            last: true
            text: qsTr("Bottom-Right corner")
            checked: Globalroot.nState.targetConfig.overview.hoverBottomRight
            onToggled: Globalroot.nState.targetConfig.overview.hoverBottomRight = checked
        }
        SectionHeader {
            text: qsTr("Behavior")
        }
        SelectRow {
            first: true
            label: qsTr("Window layout style")
            subtext: qsTr("Choose the layout algorithm used in the overview")
            fallbackIcon: "grid_view"
            fallbackText: qsTr("GNOME Grid")
            active: {
                for (let i = 0; i < layoutTypeItems.length; i++) {
                    if (layoutTypeItems[i].value === Globalroot.nState.targetConfig.overview.layoutType)
                        return layoutTypeItems[i];
                }
                return layoutTypeItems[1];
            }
            menuItems: layoutTypeItems
            onSelected: item => {
                Globalroot.nState.targetConfig.overview.layoutType = item.value
            }
        }
        ToggleRow {
            text: qsTr("Disable wallpaper blur")
            subtext: qsTr("Do not blur the background wallpaper when opening overview")
            checked: Globalroot.nState.targetConfig.overview.disableWallpaperBlur
            onToggled: Globalroot.nState.targetConfig.overview.disableWallpaperBlur = checked
        }
        ToggleRow {
            last: true
            text: qsTr("Enable overview blur")
            subtext: qsTr("Enable QuickShell-based blur effect on overview wallpaper")
            checked: Globalroot.nState.targetConfig.overview.enableOverviewBlur
            onToggled: Globalroot.nState.targetConfig.overview.enableOverviewBlur = checked
        }
        SectionHeader {
            text: qsTr("Animations")
        }
        SelectRow {
            first: true
            label: qsTr("Animation easing type")
            subtext: qsTr("Choose the easing curve for overview animations")
            fallbackIcon: "animation"
            fallbackText: qsTr("Back In")
            active: {
                for (let i = 0; i < easingTypeItems.length; i++) {
                    if (easingTypeItems[i].value === Globalroot.nState.targetConfig.overview.easingType)
                        return easingTypeItems[i];
                }
                return easingTypeItems[10];
            }
            menuItems: easingTypeItems
            onSelected: item => {
                Globalroot.nState.targetConfig.overview.easingType = item.value
            }
        }
        StepperRow {
            label: qsTr("Base duration")
            subtext: qsTr("Base duration for overview opening/closing in milliseconds")
            value: Globalroot.nState.targetConfig.overview.baseDuration
            from: 100
            to: 1000
            stepSize: 50
            onMoved: v => Globalroot.nState.targetConfig.overview.baseDuration = v
        }
        StepperRow {
            label: qsTr("Blob scale speed")
            subtext: qsTr("Scaling speed modifier for background blobs")
            value: Globalroot.nState.targetConfig.overview.blobScaleSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => Globalroot.nState.targetConfig.overview.blobScaleSpeed = v
        }
        StepperRow {
            label: qsTr("Wallpaper fade speed")
            subtext: qsTr("Fade speed modifier for the wallpaper")
            value: Globalroot.nState.targetConfig.overview.wallpaperFadeSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => Globalroot.nState.targetConfig.overview.wallpaperFadeSpeed = v
        }
        StepperRow {
            last: true
            label: qsTr("Grid fade speed")
            subtext: qsTr("Fade speed modifier for the window grid")
            value: Globalroot.nState.targetConfig.overview.gridFadeSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => Globalroot.nState.targetConfig.overview.gridFadeSpeed = v
        }
    }
}
