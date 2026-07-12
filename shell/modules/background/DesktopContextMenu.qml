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

    Component {
        id: menuItemComp
        Controls.MenuItem {}
    }

    Process {
        id: fileReader
        command: ["cat", Quickshell.env("HOME") + "/.config/quickshell/caelestia/context_menu.json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let json = [];
                try {
                    json = JSON.parse(text);
                } catch(e) {}

                let newArr = [];

                for (let i = 0; i < json.length; i++) {
                    let entry = json[i];
                    if (!entry.enabled) continue;
                    
                    let item = menuItemComp.createObject(root, {
                        text: entry.label,
                        icon: entry.icon || "application-x-executable"
                    });
                    
                    item.clicked.connect(() => {
                        if (entry.action) {
                            if (entry.action === "Wallpapers.next()") Wallpapers.next();
                            else if (entry.action === "Quickshell.reload()") Quickshell.reload();
                            else if (entry.action === "WindowFactory.create()") WindowFactory.create();
                            else if (entry.action === "OpenRightClickMenu") {
                                let win = WindowFactory.create();
                                win.nexus.nState.currentPageIdx = 0; // Wallpaper & Style
                                win.nexus.nState.openSubPage(9); // Right Click Menu is index 9
                            }
                        } else if (entry.command) {
                            Quickshell.execDetached(typeof entry.command === "string" ? entry.command.split(" ") : entry.command);
                        }
                    });
                    
                    newArr.push(item);
                }

                if (root.dynamicModel) {
                    for (let i = 0; i < root.dynamicModel.length; i++) {
                        root.dynamicModel[i].destroy();
                    }
                }

                root.dynamicModel = newArr;
            }
        }
    }

    function reloadMenu() {
        fileReader.running = true;
    }

    onExpandedChanged: {
        if (expanded) {
            reloadMenu();
        }
    }

    Component.onCompleted: reloadMenu()
}
