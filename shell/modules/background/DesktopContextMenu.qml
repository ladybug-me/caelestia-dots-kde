pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.controls as Controls
import qs.services
import qs.modules.nexus

Controls.Menu {
    id: root

    attachSideX: Controls.Menu.Right
    attachSideY: Controls.Menu.Bottom
    thisSideX: Controls.Menu.Left
    thisSideY: Controls.Menu.Top

    property list<Controls.MenuItem> defaultItems: [
        Controls.MenuItem {
            text: qsTr("Refresh")
            icon: "refresh"
            onClicked: Quickshell.reload()
        },
        Controls.MenuItem {
            text: qsTr("Wallpaper & style")
            icon: "wallpaper"
            onClicked: WindowFactory.create()
        },
        Controls.MenuItem {
            text: qsTr("Next Wallpaper")
            icon: "skip-next"
            onClicked: Wallpapers.setRandom()
        },
        Controls.MenuItem {
            text: qsTr("System Settings")
            icon: "settings"
            onClicked: Quickshell.execDetached(["systemsettings"])
        },
        Controls.MenuItem {
            text: qsTr("Open Terminal")
            icon: "terminal"
            onClicked: Quickshell.execDetached(GlobalConfig.general.apps.terminal)
        }
    ]

    Component {
        id: customMenuItemComp
        Controls.MenuItem {}
    }

    Component {
        id: addShortcutItemComp
        Controls.MenuItem {
            text: qsTr("Add Shortcut...")
            icon: "plus"
            onClicked: addShortcutDialog.open()
        }
    }

    Process {
        id: fileReader
        command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/caelestia/desktop_shortcuts.json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let json = [];
                try {
                    json = JSON.parse(text);
                } catch(e) {}

                let newArr = [];
                for (let i = 0; i < defaultItems.length; i++) {
                    newArr.push(defaultItems[i]);
                }

                for (let i = 0; i < json.length; i++) {
                    let shortcut = json[i];
                    let item = customMenuItemComp.createObject(root, {
                        text: shortcut.label,
                        icon: shortcut.icon || "application-x-executable"
                    });
                    item.clicked.connect(() => {
                        Quickshell.execDetached(shortcut.command.split(" "));
                    });
                    newArr.push(item);
                }

                let addItem = addShortcutItemComp.createObject(root);
                newArr.push(addItem);

                root.items = newArr;
            }
        }
    }

    function reloadCustomItems() {
        fileReader.running = true;
    }

    Component.onCompleted: reloadCustomItems()

    AddShortcutDialog {
        id: addShortcutDialog
        onClosed: reloadCustomItems()
    }
}
