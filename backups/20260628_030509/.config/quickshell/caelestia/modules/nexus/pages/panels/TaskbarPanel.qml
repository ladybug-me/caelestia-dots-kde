pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
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
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Persistent")
            subtext: qsTr("Keep the bar visible at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: qsTr("Position")
            subtext: qsTr("Screen edge to place the bar on")
            active: {
                for (let i = 0; i < positionItems.length; i++) {
                    if (positionItems[i].value === Config.bar.position)
                        return positionItems[i];
                }
                return positionItems[0];
            }
            menuItems: positionItems
            onSelected: item => GlobalConfig.bar.position = item.value
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal the bar when the cursor reaches the screen edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the bar reveals")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // Components
        SectionHeader {
            text: qsTr("Components")
        }

        NavRow {
            first: true
            icon: "view_agenda"
            label: qsTr("Toggle & rearrange")
            status: qsTr("Add, remove or reorder components")
            onClicked: root.nState.openSubPage(5)
        }

        NavRow {
            icon: "workspaces"
            label: qsTr("Workspaces")
            status: qsTr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "web_asset"
            label: qsTr("Active window")
            status: qsTr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "dock"
            label: qsTr("Dock")
            status: qsTr("Positioning, recoloring")
            onClicked: root.nState.openSubPage(11)
        }

        NavRow {
            icon: "widgets"
            label: qsTr("Tray")
            status: qsTr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            label: qsTr("Status icons")
            status: qsTr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            icon: "schedule"
            label: qsTr("Clock")
            status: qsTr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        NavRow {
            last: true
            icon: "code"
            label: qsTr("GitHub")
            status: qsTr("Contributions, token setup")
            onClicked: root.nState.openSubPage(12)
        }

        // Scroll actions
        SectionHeader {
            text: qsTr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: qsTr("Workspaces")
            subtext: qsTr("Scroll over the workspace indicator to switch workspaces")
            checked: Config.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: qsTr("Volume")
            subtext: qsTr("Scroll on the top half of the bar to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Brightness")
            subtext: qsTr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }
    }
}
