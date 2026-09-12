pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Window Switcher")
    isSubPage: true

    readonly property list<MenuItem> layoutItems: [
        MenuItem {
            property string value: "caelestia"

            text: qsTr("Caelestia (Material 3)")
        },
        MenuItem {
            property string value: "compact"

            text: qsTr("Compact")
        },
        MenuItem {
            property string value: "sidebar"

            text: qsTr("Sidebar")
        },
        MenuItem {
            property string value: "big_icons"

            text: qsTr("Big Icons")
        },
        MenuItem {
            property string value: "coverswitch"

            text: qsTr("Cover Switch")
        },
        MenuItem {
            property string value: "flipswitch"

            text: qsTr("Flip Switch")
        }
    ]

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Behavior Section
        SectionHeader {
            first: true
            text: qsTr("Behavior")
        }

        ToggleRow {
            first: true
            text: qsTr("Filter by current desktop")
            subtext: qsTr("Only show windows belonging to the active virtual desktop")
            checked: Config.tabSwitch.currentDesktopOnly
            onToggled: {
                GlobalConfig.tabSwitch.currentDesktopOnly = checked;
                GlobalConfig.save();
                Quickshell.execDetached(["bash", "-c", `
                    kwriteconfig6 --file kwinrc --group "TabBox" --key "DesktopMode" "${checked ? "1" : "0"}"
                    qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
                `]);
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Preview window on desktop")
            subtext: qsTr("Highlight and show the window itself on the workspace while cycling Alt+Tab")
            checked: Config.tabSwitch.previewOnDesktop
            onToggled: {
                GlobalConfig.tabSwitch.previewOnDesktop = checked;
                GlobalConfig.save();
                Quickshell.execDetached(["bash", "-c", `
                    kwriteconfig6 --file kwinrc --group "TabBox" --key "HighlightWindows" "${checked ? "true" : "false"}"
                    qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
                `]);
            }
        }

        // Display Section
        SectionHeader {
            text: qsTr("Display")
        }

        ToggleRow {
            first: true
            text: qsTr("Show minimized windows")
            subtext: qsTr("Include minimized windows in the window switcher")
            checked: Config.tabSwitch.showMinimized
            onToggled: {
                GlobalConfig.tabSwitch.showMinimized = checked;
                GlobalConfig.save();
                Quickshell.execDetached(["bash", "-c", `
                    kwriteconfig6 --file kwinrc --group "TabBox" --key "MinMode" "${checked ? "0" : "1"}"
                    qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
                `]);
            }
        }

        ToggleRow {
            text: qsTr("Show windows from all screens")
            subtext: qsTr("Include windows from all connected monitors")
            checked: Config.tabSwitch.allScreens
            onToggled: {
                GlobalConfig.tabSwitch.allScreens = checked;
                GlobalConfig.save();
                Quickshell.execDetached(["bash", "-c", `
                    kwriteconfig6 --file kwinrc --group "TabBox" --key "MultiScreenMode" "${checked ? "0" : "1"}"
                    qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
                `]);
            }
        }

        SelectRow {
            last: true
            label: qsTr("KWin Switcher Layout")
            subtext: qsTr("Choose the visual layout used for native Alt+Tab")
            menuItems: root.layoutItems
            active: {
                const cur = Config.tabSwitch.layout || "caelestia";
                for (let i = 0; i < root.layoutItems.length; ++i) {
                    if (root.layoutItems[i].value === cur) return i;
                }
                return 0;
            }
            onSelected: item => {
                GlobalConfig.tabSwitch.layout = item.value;
                GlobalConfig.save();
                Quickshell.execDetached(["bash", "-c", `
                    kwriteconfig6 --file kwinrc --group "TabBox" --key "LayoutName" "${item.value}"
                    qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || true
                `]);
            }
        }
    }
}
