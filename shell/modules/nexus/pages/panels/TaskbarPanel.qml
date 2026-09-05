pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> positionItems: [
        MenuItem {
            property string value: "top"

            text: qsTr("Top")
        },
        MenuItem {
            property string value: "bottom"

            text: qsTr("Bottom")
        },
        MenuItem {
            property string value: "left"

            text: qsTr("Left")
        },
        MenuItem {
            property string value: "right"

            text: qsTr("Right")
        }
    ]

    title: qsTr("Taskbar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Behaviour
        SectionHeader {
            first: true
            text: qsTr("Behavior")
        }

        ToggleRow {
            first: true
            text: qsTr("Persistent")
            subtext: qsTr("Keep the bar visible at all times")
            checked: Globalroot.nState.targetConfig.bar.persistent
            onToggled: Globalroot.nState.targetConfig.bar.persistent = checked
        }

        ToggleRow {
            text: qsTr("Dodge windows")
            subtext: qsTr("Retract the bar while a window covers it, and let windows sit underneath")
            enabled: Globalroot.nState.targetConfig.bar.persistent
            checked: Globalroot.nState.targetConfig.bar.dodgeWindows
            onToggled: Globalroot.nState.targetConfig.bar.dodgeWindows = checked
        }

        ToggleRow {
            text: qsTr("Dodge focused window only")
            subtext: qsTr("Ignore background windows over the bar, and dodge only what you are using")
            enabled: Globalroot.nState.targetConfig.bar.persistent && Globalroot.nState.targetConfig.bar.dodgeWindows
            checked: Globalroot.nState.targetConfig.bar.dodgeFocusedOnly
            onToggled: Globalroot.nState.targetConfig.bar.dodgeFocusedOnly = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: qsTr("Position")
            subtext: qsTr("Screen edge to place the bar on")
            active: {
                for (let i = 0; i < positionItems.length; i++) {
                    if (positionItems[i].value === Globalroot.nState.targetConfig.bar.position)
                        return positionItems[i];
                }
                return positionItems[0];
            }
            menuItems: positionItems
            onSelected: item => Globalroot.nState.targetConfig.bar.position = item.value
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal the bar when the cursor reaches the screen edge")
            checked: Globalroot.nState.targetConfig.bar.showOnHover
            onToggled: Globalroot.nState.targetConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the bar reveals")
            value: Globalroot.nState.targetConfig.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => Globalroot.nState.targetConfig.bar.dragThreshold = v
        }

        SectionHeader {
            text: qsTr("Scaling")
        }

        StepperRow {
            first: true
            label: qsTr("Bar scale")
            subtext: qsTr("Scales taskbar thickness and component sizing")
            value: Globalroot.nState.targetConfig.bar.scale
            from: 0.6
            to: 1.6
            stepSize: 0.05
            onMoved: v => Globalroot.nState.targetConfig.bar.scale = v
        }

        StepperRow {
            label: qsTr("Preview scale")
            subtext: qsTr("Scales taskbar hover previews")
            value: Globalroot.nState.targetConfig.bar.previewScale
            from: 0.5
            to: 1.6
            stepSize: 0.05
            onMoved: v => Globalroot.nState.targetConfig.bar.previewScale = v
        }

        ToggleRow {
            text: qsTr("Live window previews")
            subtext: qsTr("Live thumbnails in hover/overview/alt-tab. Disable if screen sharing or camera in other apps (e.g. Vesktop) freezes")
            checked: Globalroot.nState.targetConfig.bar.livePreviews
            onToggled: Globalroot.nState.targetConfig.bar.livePreviews = checked
        }

        ToggleRow {
            text: qsTr("Scale with bar size")
            subtext: qsTr("Multiply the preview scale with the bar scale")
            checked: Globalroot.nState.targetConfig.bar.previewScaleWithBar
            onToggled: Globalroot.nState.targetConfig.bar.previewScaleWithBar = checked
        }

        StepperRow {
            label: qsTr("Font scaling offset")
            subtext: qsTr("Scales the text size across taskbar popouts")
            value: Globalroot.nState.targetConfig.bar.fontScaleOffset
            from: -1.0; to: 1.0; stepSize: 0.05
            onMoved: v => Globalroot.nState.targetConfig.bar.fontScaleOffset = v
        }

        NavRow {
            last: true
            icon: "aspect_ratio"
            label: qsTr("Per-element scaling offsets")
            status: qsTr("Customize scale and font for each popout type")
            onClicked: root.nState.openSubPage(14)
        }

        // Components
        SectionHeader {
            text: qsTr("Components")
        }

        NavRow {
            first: true
            icon: "view_agenda"
            label: qsTr("Toggle & Rearrange")
            status: qsTr("Add, remove or reorder components")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            last: true
            icon: "tune"
            label: qsTr("Elements & Modules")
            status: qsTr("Workspaces, tray, status icons, clock, dock and more")
            onClicked: root.nState.openSubPage(15)
        }

        // Scroll actions
        SectionHeader {
            text: qsTr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: qsTr("Workspaces")
            subtext: qsTr("Scroll over the workspace indicator to switch workspaces")
            checked: Globalroot.nState.targetConfig.bar.scrollActions.workspaces
            onToggled: Globalroot.nState.targetConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: qsTr("Volume")
            subtext: qsTr("Scroll on the top half of the bar to adjust volume")
            checked: Globalroot.nState.targetConfig.bar.scrollActions.volume
            onToggled: Globalroot.nState.targetConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Brightness")
            subtext: qsTr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Globalroot.nState.targetConfig.bar.scrollActions.brightness
            onToggled: Globalroot.nState.targetConfig.bar.scrollActions.brightness = checked
        }
    }
}
