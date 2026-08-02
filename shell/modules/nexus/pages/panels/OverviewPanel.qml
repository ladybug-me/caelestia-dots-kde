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
            checked: GlobalConfig.overview.enabled
            onToggled: GlobalConfig.overview.enabled = checked
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Open overview by hovering a corner instead of dragging")
            checked: GlobalConfig.overview.showOnHover
            onToggled: GlobalConfig.overview.showOnHover = checked
        }

        StepperRow {
            label: qsTr("Trigger area size")
            subtext: qsTr("Size of the corner activation areas in pixels")
            value: GlobalConfig.overview.hoverThickness
            from: 1
            to: 100
            stepSize: 1
            onMoved: v => GlobalConfig.overview.hoverThickness = v
        }

        StepperRow {
            label: qsTr("Drag threshold")
            subtext: qsTr("Distance to drag from corner to open overview")
            value: GlobalConfig.overview.dragThreshold
            from: 10
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.overview.dragThreshold = v
            visible: !GlobalConfig.overview.showOnHover
        }

        ToggleRow {
            text: qsTr("Top-Left corner")
            checked: GlobalConfig.overview.hoverTopLeft
            onToggled: GlobalConfig.overview.hoverTopLeft = checked
        }

        ToggleRow {
            text: qsTr("Top-Right corner")
            checked: GlobalConfig.overview.hoverTopRight
            onToggled: GlobalConfig.overview.hoverTopRight = checked
        }

        ToggleRow {
            text: qsTr("Bottom-Left corner")
            checked: GlobalConfig.overview.hoverBottomLeft
            onToggled: GlobalConfig.overview.hoverBottomLeft = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Bottom-Right corner")
            checked: GlobalConfig.overview.hoverBottomRight
            onToggled: GlobalConfig.overview.hoverBottomRight = checked
        }

        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Disable wallpaper blur")
            subtext: qsTr("Do not blur the background wallpaper when opening overview")
            checked: GlobalConfig.overview.disableWallpaperBlur
            onToggled: GlobalConfig.overview.disableWallpaperBlur = checked
        }

        SectionHeader {
            text: qsTr("Animations")
        }

        StepperRow {
            first: true
            label: qsTr("Base duration")
            subtext: qsTr("Base duration for overview opening/closing in milliseconds")
            value: GlobalConfig.overview.baseDuration
            from: 100
            to: 1000
            stepSize: 50
            onMoved: v => GlobalConfig.overview.baseDuration = v
        }

        StepperRow {
            label: qsTr("Blob scale speed")
            subtext: qsTr("Scaling speed modifier for background blobs")
            value: GlobalConfig.overview.blobScaleSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.overview.blobScaleSpeed = v
        }

        StepperRow {
            label: qsTr("Wallpaper fade speed")
            subtext: qsTr("Fade speed modifier for the wallpaper")
            value: GlobalConfig.overview.wallpaperFadeSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.overview.wallpaperFadeSpeed = v
        }

        StepperRow {
            last: true
            label: qsTr("Grid fade speed")
            subtext: qsTr("Fade speed modifier for the window grid")
            value: GlobalConfig.overview.gridFadeSpeed
            from: 0.1
            to: 5.0
            stepSize: 0.1
            onMoved: v => GlobalConfig.overview.gridFadeSpeed = v
        }
    }
}
