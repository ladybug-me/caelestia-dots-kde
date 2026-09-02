import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: I18n.tr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        NavRow {
            first: true
            icon: "dashboard"
            label: I18n.tr("Dashboard")
            status: Config.dashboard.enabled ? I18n.tr("Enabled") : I18n.tr("Disabled")
            onClicked: root.nState.openSubPage(1)
        }
        NavRow {
            icon: "dock_to_bottom"
            label: I18n.tr("Taskbar")
            status: Config.bar.persistent ? I18n.tr("Always visible") : Config.bar.showOnHover ? I18n.tr("Reveal on hover") : I18n.tr("Reveal on drag")
            onClicked: root.nState.openSubPage(2)
        }
        NavRow {
            icon: "apps"
            label: I18n.tr("Launcher")
            status: Config.launcher.enabled ? I18n.tr("Enabled") : I18n.tr("Disabled")
            onClicked: root.nState.openSubPage(3)
        }
        NavRow {
            icon: "dock_to_right"
            label: I18n.tr("Sidebar")
            status: Config.sidebar.enabled ? I18n.tr("Enabled") : I18n.tr("Disabled")
            onClicked: root.nState.openSubPage(4)
        }
        NavRow {
            icon: "settings_input_component"
            label: I18n.tr("Quick toggle")
            status: Config.utilities.enabled ? I18n.tr("Enabled") : I18n.tr("Disabled")
            onClicked: root.nState.openSubPage(5)
        }
        NavRow {
            last: true
            icon: "view_carousel"
            label: I18n.tr("Overview")
            status: Config.overview.enabled ? I18n.tr("Enabled") : I18n.tr("Disabled")
            onClicked: root.nState.openSubPage(16)
        }
    }
}
