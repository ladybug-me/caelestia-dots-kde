import ".."
import qs.services
import qs.utils
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Options toolbar
Toolbar {
    id: root

    // Use a synchronizer on these
    property var action
    property var selectionMode
    // Signals
    signal dismiss()

    ToolbarTabBar {
        id: tabBar
        tabButtonList: [
            {"icon": "content_cut", "name": qsTr("Screenshot")},
            {"icon": "image_search", "name": qsTr("Google Lens")}
        ]
        currentIndex: root.action === RegionSelection.SnipAction.Search ? 1 : 0
        onCurrentIndexChanged: {
            root.action = currentIndex === 0 ? RegionSelection.SnipAction.Copy : RegionSelection.SnipAction.Search;
            root.selectionMode = RegionSelection.SelectionMode.RectCorners;
        }
    }
}
