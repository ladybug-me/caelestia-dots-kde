import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Quickshell
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Adjust for all monitors")
        }

        NavRow {
            first: true
            icon: "dashboard"
            label: qsTr("Dashboard")
            status: GlobalConfig.dashboard.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: {
                root.nState.targetScreenName = ""
                root.nState.openSubPage(1)
            }
        }
        NavRow {
            icon: "dock_to_bottom"
            label: qsTr("Taskbar")
            status: GlobalConfig.bar.persistent ? qsTr("Always visible") : GlobalConfig.bar.showOnHover ? qsTr("Reveal on hover") : qsTr("Reveal on drag")
            onClicked: {
                root.nState.targetScreenName = ""
                root.nState.openSubPage(2)
            }
        }
        NavRow {
            icon: "apps"
            label: qsTr("Launcher")
            status: GlobalConfig.launcher.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: {
                root.nState.targetScreenName = ""
                root.nState.openSubPage(3)
            }
        }
        NavRow {
            icon: "dock_to_right"
            label: qsTr("Sidebar")
            status: GlobalConfig.sidebar.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: {
                root.nState.targetScreenName = ""
                root.nState.openSubPage(4)
            }
        }
        NavRow {
            icon: "settings_input_component"
            label: qsTr("Quick toggle")
            status: GlobalConfig.utilities.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: {
                root.nState.targetScreenName = ""
                root.nState.openSubPage(5)
            }
        }
        NavRow {
            last: true
            icon: "view_carousel"
            label: qsTr("Overview")
            status: GlobalConfig.overview.enabled ? qsTr("Enabled") : qsTr("Disabled")
            onClicked: {
                root.nState.targetScreenName = ""
                root.nState.openSubPage(16)
            }
        }

        Repeater {
            model: Quickshell.screens

            delegate: ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    text: qsTr("Adjust for ") + model.name
                }

                NavRow {
                    first: true
                    icon: "dashboard"
                    label: qsTr("Dashboard")
                    status: GlobalConfig.forScreen(model.name).dashboard.enabled ? qsTr("Enabled") : qsTr("Disabled")
                    onClicked: {
                        root.nState.targetScreenName = model.name
                        root.nState.openSubPage(1)
                    }
                }
                NavRow {
                    icon: "dock_to_bottom"
                    label: qsTr("Taskbar")
                    status: GlobalConfig.forScreen(model.name).bar.persistent ? qsTr("Always visible") : GlobalConfig.forScreen(model.name).bar.showOnHover ? qsTr("Reveal on hover") : qsTr("Reveal on drag")
                    onClicked: {
                        root.nState.targetScreenName = model.name
                        root.nState.openSubPage(2)
                    }
                }
                NavRow {
                    icon: "apps"
                    label: qsTr("Launcher")
                    status: GlobalConfig.forScreen(model.name).launcher.enabled ? qsTr("Enabled") : qsTr("Disabled")
                    onClicked: {
                        root.nState.targetScreenName = model.name
                        root.nState.openSubPage(3)
                    }
                }
                NavRow {
                    icon: "dock_to_right"
                    label: qsTr("Sidebar")
                    status: GlobalConfig.forScreen(model.name).sidebar.enabled ? qsTr("Enabled") : qsTr("Disabled")
                    onClicked: {
                        root.nState.targetScreenName = model.name
                        root.nState.openSubPage(4)
                    }
                }
                NavRow {
                    icon: "settings_input_component"
                    label: qsTr("Quick toggle")
                    status: GlobalConfig.forScreen(model.name).utilities.enabled ? qsTr("Enabled") : qsTr("Disabled")
                    onClicked: {
                        root.nState.targetScreenName = model.name
                        root.nState.openSubPage(5)
                    }
                }
                NavRow {
                    last: true
                    icon: "view_carousel"
                    label: qsTr("Overview")
                    status: GlobalConfig.forScreen(model.name).overview.enabled ? qsTr("Enabled") : qsTr("Disabled")
                    onClicked: {
                        root.nState.targetScreenName = model.name
                        root.nState.openSubPage(16)
                    }
                }
            }
        }
    }
}
