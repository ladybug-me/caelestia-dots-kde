import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    readonly property list<MenuItem> fullscreenItems: [
        MenuItem {
            text: I18n.tr("Off")
            icon: "notifications_off"
        },
        MenuItem {
            text: I18n.tr("On")
            icon: "notifications"
        }
    ]
    readonly property list<string> fullscreenValues: ["off", "on"]
    readonly property list<MenuItem> positionItems: [
        MenuItem {
            text: I18n.tr("Auto")
            icon: "auto_awesome"
        },
        MenuItem {
            text: I18n.tr("Top Left")
            icon: "north_west"
        },
        MenuItem {
            text: I18n.tr("Top Center")
            icon: "north"
        },
        MenuItem {
            text: I18n.tr("Top Right")
            icon: "north_east"
        },
        MenuItem {
            text: I18n.tr("Bottom Left")
            icon: "south_west"
        },
        MenuItem {
            text: I18n.tr("Bottom Center")
            icon: "south"
        },
        MenuItem {
            text: I18n.tr("Bottom Right")
            icon: "south_east"
        }
    ]
    readonly property list<string> positionValues: ["auto", "top-left", "top-center", "top-right", "bottom-left", "bottom-center", "bottom-right"]

    title: I18n.tr("Notifications")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: I18n.tr("Display")
        }

        SelectRow {
            first: true
            label: I18n.tr("Show in fullscreen")
            subtext: I18n.tr("Allow notifications over fullscreen apps")
            menuItems: root.fullscreenItems
            active: root.fullscreenItems[Math.max(0, root.fullscreenValues.indexOf(GlobalConfig.notifs.fullscreen))]
            onSelected: item => GlobalConfig.notifs.fullscreen = root.fullscreenValues[root.fullscreenItems.indexOf(item)]
        }

        SelectRow {
            label: I18n.tr("Position")
            subtext: I18n.tr("Where notification popups appear")
            menuItems: root.positionItems
            active: root.positionItems[Math.max(0, root.positionValues.indexOf(GlobalConfig.notifs.position))]
            onSelected: item => GlobalConfig.notifs.position = root.positionValues[root.positionItems.indexOf(item)]
        }

        ToggleRow {
            text: I18n.tr("Expire automatically")
            subtext: I18n.tr("Dismiss notifications after their timeout")
            checked: GlobalConfig.notifs.expire
            onToggled: GlobalConfig.notifs.expire = checked
        }

        ToggleRow {
            text: I18n.tr("Open expanded")
            subtext: I18n.tr("Show notifications expanded by default")
            checked: GlobalConfig.notifs.openExpanded
            onToggled: GlobalConfig.notifs.openExpanded = checked
        }

        StepperRow {
            label: I18n.tr("Default timeout")
            subtext: I18n.tr("Seconds before a notification dismisses")
            value: GlobalConfig.notifs.defaultExpireTimeout / 1000
            from: 1
            to: 60
            stepSize: 1
            onMoved: value => GlobalConfig.notifs.defaultExpireTimeout = Math.round(value * 1000)
        }

        StepperRow {
            label: I18n.tr("Group preview count")
            subtext: I18n.tr("Notifications shown before a group collapses")
            value: GlobalConfig.notifs.groupPreviewNum
            from: 1
            to: 10
            stepSize: 1
            onMoved: value => GlobalConfig.notifs.groupPreviewNum = Math.round(value)
        }

        StepperRow {
            label: I18n.tr("Max popup notifications")
            subtext: I18n.tr("Only the newest popups are shown; the rest stay in the sidebar")
            value: GlobalConfig.notifs.maxPopups
            from: 0
            to: 30
            stepSize: 1
            onMoved: value => GlobalConfig.notifs.maxPopups = Math.round(value)
        }

        StepperRow {
            last: true
            label: I18n.tr("Max stored notifications")
            subtext: I18n.tr("Older notifications are dropped when the limit is reached")
            value: GlobalConfig.notifs.maxNotifs
            from: 20
            to: 2000
            stepSize: 50
            onMoved: value => GlobalConfig.notifs.maxNotifs = Math.round(value)
        }

        SectionHeader {
            text: I18n.tr("Taskbar")
        }

        ToggleRow {
            first: true
            last: true
            text: I18n.tr("Show notification icon")
            subtext: I18n.tr("Show notifications in taskbar status icons")
            checked: Config.bar.status.showNotifications
            onToggled: GlobalConfig.bar.status.showNotifications = checked
        }
    }
}