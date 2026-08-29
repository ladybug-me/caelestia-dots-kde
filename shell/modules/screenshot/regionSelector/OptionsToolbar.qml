import ".."
import "../../../components/controls"
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
    property bool showWindowOutlines: false

    // Signals
    signal dismiss()

    IconButton {
        Layout.alignment: Qt.AlignVCenter
        icon: "desktop_windows"
        isToggle: true
        type: IconButton.Text
        padding: 4
        implicitWidth: 32
        implicitHeight: 32
        checked: root.showWindowOutlines
        onClicked: {
            root.showWindowOutlines = internalChecked;
        }

        Tooltip {
            target: parent
            text: qsTr("Window Selector")
        }
    }

    ToolbarTabBar {
        id: tabBar

        tabButtonList: [
            {"icon": "content_cut", "name": qsTr("Screenshot")},
            {"icon": "image_search", "name": qsTr("Google Lens")},
            {"icon": "text_fields", "name": qsTr("Text Recognition")}
        ]
        currentIndex: root.action === ScreenshotAction.SnipAction.Search ? 1 : (root.action === ScreenshotAction.SnipAction.CharRecognition ? 2 : 0)
        onCurrentIndexChanged: {
            let newAction;
            if (currentIndex === 0) newAction = ScreenshotAction.SnipAction.Copy;
            else if (currentIndex === 1) newAction = ScreenshotAction.SnipAction.Search;
            else if (currentIndex === 2) newAction = ScreenshotAction.SnipAction.CharRecognition;
            else return;

            if (root.action !== newAction) {
                root.action = newAction;
                root.selectionMode = RegionSelection.SelectionMode.RectCorners;
            }
        }
    }
}
