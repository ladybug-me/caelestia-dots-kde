import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.utils

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
            {"icon": "image_search", "name": qsTr("Google Lens")},
            {"icon": "text_fields", "name": qsTr("Text Recognition")}
        ]
        currentIndex: root.action === RegionSelection.SnipAction.Search ? 1 : (root.action === RegionSelection.SnipAction.CharRecognition ? 2 : 0)
        onCurrentIndexChanged: {
            if (currentIndex === 0) root.action = RegionSelection.SnipAction.Copy;
            else if (currentIndex === 1) root.action = RegionSelection.SnipAction.Search;
            else if (currentIndex === 2) root.action = RegionSelection.SnipAction.CharRecognition;
            
            root.selectionMode = RegionSelection.SelectionMode.RectCorners;
        }
    }
}
