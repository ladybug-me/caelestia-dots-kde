pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.utils
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    readonly property list<MenuItem> layoutTypeItems: [
        MenuItem {
            property int value: 0

            text: I18n.tr("KDE Grid")
        },
        MenuItem {
            property int value: 1

            text: I18n.tr("GNOME Grid")
        }
    ]

    readonly property list<MenuItem> easingTypeItems: [
        MenuItem {
            property int value: 0

            text: I18n.tr("Linear")
        },
        MenuItem {
            property int value: 2

            text: I18n.tr("Quadratic Out")
        },
        MenuItem {
            property int value: 3

            text: I18n.tr("Quadratic In-Out")
        },
        MenuItem {
            property int value: 6

            text: I18n.tr("Cubic Out")
        },
        MenuItem {
            property int value: 10

            text: I18n.tr("Quartic Out")
        },
        MenuItem {
            property int value: 14

            text: I18n.tr("Quintic Out")
        },
        MenuItem {
            property int value: 18

            text: I18n.tr("Sine Out")
        },
        MenuItem {
            property int value: 22

            text: I18n.tr("Exponential Out")
        },
        MenuItem {
            property int value: 26

            text: I18n.tr("Circular Out")
        },
        MenuItem {
            property int value: 30

            text: I18n.tr("Elastic Out")
        },
        MenuItem {
            property int value: 33

            text: I18n.tr("Back In")
        },
        MenuItem {
            property int value: 34

            text: I18n.tr("Back Out")
        },
        MenuItem {
            property int value: 38

            text: I18n.tr("Bounce Out")
        }
    ]

    title: I18n.tr("Overview")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Activation")
        }
        ToggleRow {
            first: true
            text: I18n.tr("Enable overview")
            checked: GlobalConfig.overview.enabled
            onToggled: GlobalConfig.overview.enabled = checked
        }
        ToggleRow {
            text: I18n.tr("Show on hover")
            subtext: I18n.tr("Open overview by hovering a corner instead of dragging")
            checked: GlobalConfig.overview.showOnHover
            onToggled: GlobalConfig.overview.showOnHover = checked
        }
        StepperRow {
            label: I18n.tr("Trigger area size")
            last: GlobalConfig.overview.showOnHover
            subtext: I18n.tr("Size of the corner activation areas in pixels")
            value: GlobalConfig.overview.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => GlobalConfig.overview.hoverThickness = v
            visible: GlobalConfig.overview.showOnHover
        }
        StepperRow {
            last: !GlobalConfig.overview.showOnHover
            label: I18n.tr("Drag threshold")
            subtext: I18n.tr("Distance to drag from corner to open overview")
            value: GlobalConfig.overview.dragThreshold
            from: 10
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.overview.dragThreshold = v
            visible: !GlobalConfig.overview.showOnHover
        }
        SectionHeader {
            text: I18n.tr("Corners")
        }
        // Enabling a corner takes it off KWin for as long as it stays enabled;
        // whatever KDE had bound there comes back untouched when it's turned
        // off, on shell exit, or on the next start after a crash.
        ToggleRow {
            first: true
            text: I18n.tr("Top-Left corner")
            checked: GlobalConfig.overview.hoverTopLeft
            onToggled: GlobalConfig.overview.hoverTopLeft = checked
        }
        ToggleRow {
            text: I18n.tr("Top-Right corner")
            checked: GlobalConfig.overview.hoverTopRight
            onToggled: GlobalConfig.overview.hoverTopRight = checked
        }
        ToggleRow {
            text: I18n.tr("Bottom-Left corner")
            checked: GlobalConfig.overview.hoverBottomLeft
            onToggled: GlobalConfig.overview.hoverBottomLeft = checked
        }
        ToggleRow {
            last: true
            text: I18n.tr("Bottom-Right corner")
            checked: GlobalConfig.overview.hoverBottomRight
            onToggled: GlobalConfig.overview.hoverBottomRight = checked
        }
        SectionHeader {
            text: I18n.tr("Behaviour")
        }
        SelectRow {
            first: true
            label: I18n.tr("Window layout style")
            subtext: I18n.tr("Choose the layout algorithm used in the overview")
            fallbackIcon: "grid_view"
            fallbackText: I18n.tr("GNOME Grid")
            active: {
                for (let i = 0; i < layoutTypeItems.length; i++) {
                    if (layoutTypeItems[i].value === GlobalConfig.overview.layoutType)
                        return layoutTypeItems[i];
                }
                return layoutTypeItems[1];
            }
            menuItems: layoutTypeItems
            onSelected: item => {
                GlobalConfig.overview.layoutType = item.value
            }
        }
        ToggleRow {
            text: I18n.tr("Disable wallpaper blur")
            subtext: I18n.tr("Do not blur the background wallpaper when opening overview")
            checked: GlobalConfig.overview.disableWallpaperBlur
            onToggled: GlobalConfig.overview.disableWallpaperBlur = checked
        }
        ToggleRow {
            last: true
            text: I18n.tr("Enable overview blur")
            subtext: I18n.tr("Enable QuickShell-based blur effect on overview wallpaper")
            checked: GlobalConfig.overview.enableOverviewBlur
            onToggled: GlobalConfig.overview.enableOverviewBlur = checked
        }
        SectionHeader {
            text: I18n.tr("Animations")
        }
        SelectRow {
            first: true
            label: I18n.tr("Animation easing type")
            subtext: I18n.tr("Choose the easing curve for overview animations")
            fallbackIcon: "animation"
            fallbackText: I18n.tr("Back In")
            active: {
                for (let i = 0; i < easingTypeItems.length; i++) {
                    if (easingTypeItems[i].value === GlobalConfig.overview.easingType)
                        return easingTypeItems[i];
                }
                return easingTypeItems[10];
            }
            menuItems: easingTypeItems
            onSelected: item => {
                GlobalConfig.overview.easingType = item.value
            }
        }
        StepperRow {
            label: I18n.tr("Base duration")
            subtext: I18n.tr("Base duration for overview opening/closing in milliseconds")
            value: GlobalConfig.overview.baseDuration
            from: 100
            to: 1000
            stepSize: 50
            onMoved: v => GlobalConfig.overview.baseDuration = v
        }
        StepperRow {
            label: I18n.tr("Blob scale speed")
            subtext: I18n.tr("Scaling speed modifier for background blobs")
            value: GlobalConfig.overview.blobScaleSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.overview.blobScaleSpeed = v
        }
        StepperRow {
            label: I18n.tr("Wallpaper fade speed")
            subtext: I18n.tr("Fade speed modifier for the wallpaper")
            value: GlobalConfig.overview.wallpaperFadeSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.overview.wallpaperFadeSpeed = v
        }
        StepperRow {
            last: true
            label: I18n.tr("Grid fade speed")
            subtext: I18n.tr("Fade speed modifier for the window grid")
            value: GlobalConfig.overview.gridFadeSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.overview.gridFadeSpeed = v
        }
    }
}
