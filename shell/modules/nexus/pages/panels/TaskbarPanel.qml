pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.utils
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    readonly property list<MenuItem> positionItems: [
        MenuItem {
            property string value: "top"

            text: I18n.tr("Top")
        },
        MenuItem {
            property string value: "bottom"

            text: I18n.tr("Bottom")
        },
        MenuItem {
            property string value: "left"

            text: I18n.tr("Left")
        },
        MenuItem {
            property string value: "right"

            text: I18n.tr("Right")
        }
    ]

    title: I18n.tr("Taskbar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Behaviour
        SectionHeader {
            first: true
            text: Strings.localizeEnglishSpelling(I18n.tr("Behaviour"))
        }

        ToggleRow {
            first: true
            text: I18n.tr("Persistent")
            subtext: I18n.tr("Keep the bar visible at all times")
            checked: GlobalConfig.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: I18n.tr("Dodge windows")
            subtext: I18n.tr("Retract the bar while a window covers it, and let windows sit underneath")
            enabled: GlobalConfig.bar.persistent
            checked: GlobalConfig.bar.dodgeWindows
            onToggled: GlobalConfig.bar.dodgeWindows = checked
        }

        ToggleRow {
            text: I18n.tr("Dodge focused window only")
            subtext: I18n.tr("Ignore background windows over the bar, and dodge only what you are using")
            enabled: GlobalConfig.bar.persistent && GlobalConfig.bar.dodgeWindows
            checked: GlobalConfig.bar.dodgeFocusedOnly
            onToggled: GlobalConfig.bar.dodgeFocusedOnly = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: I18n.tr("Position")
            subtext: I18n.tr("Screen edge to place the bar on")
            active: {
                for (let i = 0; i < positionItems.length; i++) {
                    if (positionItems[i].value === GlobalConfig.bar.position)
                        return positionItems[i];
                }
                return positionItems[0];
            }
            menuItems: positionItems
            onSelected: item => GlobalConfig.bar.position = item.value
        }

        ToggleRow {
            text: I18n.tr("Show on hover")
            subtext: I18n.tr("Reveal the bar when the cursor reaches the screen edge")
            checked: GlobalConfig.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: I18n.tr("Drag threshold")
            subtext: I18n.tr("Pixels dragged before the bar reveals")
            value: GlobalConfig.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        SectionHeader {
            text: Strings.localizeEnglishSpelling(I18n.tr("Scaling"))
        }

        StepperRow {
            first: true
            label: I18n.tr("Bar scale")
            subtext: I18n.tr("Scales taskbar thickness and component sizing")
            value: GlobalConfig.bar.scale
            from: 0.6
            to: 1.6
            stepSize: 0.05
            onMoved: v => GlobalConfig.bar.scale = v
        }

        StepperRow {
            label: I18n.tr("Preview scale")
            subtext: I18n.tr("Scales taskbar hover previews")
            value: GlobalConfig.bar.previewScale
            from: 0.5
            to: 1.6
            stepSize: 0.05
            onMoved: v => GlobalConfig.bar.previewScale = v
        }

        ToggleRow {
            text: I18n.tr("Live window previews")
            subtext: I18n.tr("Live thumbnails in hover/overview/alt-tab. Disable if screen sharing or camera in other apps (e.g. Vesktop) freezes")
            checked: GlobalConfig.bar.livePreviews
            onToggled: GlobalConfig.bar.livePreviews = checked
        }

        ToggleRow {
            text: I18n.tr("Scale with bar size")
            subtext: I18n.tr("Multiply the preview scale with the bar scale")
            checked: GlobalConfig.bar.previewScaleWithBar
            onToggled: GlobalConfig.bar.previewScaleWithBar = checked
        }

        StepperRow {
            label: I18n.tr("Font scaling offset")
            subtext: I18n.tr("Scales the text size across taskbar popouts")
            value: GlobalConfig.bar.fontScaleOffset
            from: -1.0; to: 1.0; stepSize: 0.05
            onMoved: v => GlobalConfig.bar.fontScaleOffset = v
        }

        NavRow {
            last: true
            icon: "aspect_ratio"
            label: I18n.tr("Per-element scaling offsets")
            status: I18n.tr("Customize scale and font for each popout type")
            onClicked: root.nState.openSubPage(14)
        }

        // Components
        SectionHeader {
            text: I18n.tr("Components")
        }

        NavRow {
            first: true
            icon: "view_agenda"
            label: I18n.tr("Toggle & Rearrange")
            status: I18n.tr("Add, remove or reorder components")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            last: true
            icon: "tune"
            label: I18n.tr("Elements & Modules")
            status: I18n.tr("Workspaces, tray, status icons, clock, dock and more")
            onClicked: root.nState.openSubPage(15)
        }

        // Scroll actions
        SectionHeader {
            text: I18n.tr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: I18n.tr("Workspaces")
            subtext: I18n.tr("Scroll over the workspace indicator to switch workspaces")
            checked: GlobalConfig.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: I18n.tr("Volume")
            subtext: I18n.tr("Scroll on the top half of the bar to adjust volume")
            checked: GlobalConfig.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: I18n.tr("Brightness")
            subtext: I18n.tr("Scroll on the bottom half of the bar to adjust brightness")
            checked: GlobalConfig.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }
    }
}
