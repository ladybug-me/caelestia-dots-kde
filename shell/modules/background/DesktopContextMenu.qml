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
                    if (text.trim().length > 0) {
                        json = JSON.parse(text);
                    }
                } catch(e) {}
                
                if (!json || json.length === 0) {
                    json = [
                        { id: "refresh", label: qsTr("Refresh"), icon: "refresh", action: "Quickshell.reload()", enabled: true, type: "default" },
                        { id: "wallpaper_style", label: qsTr("Wallpaper & style"), icon: "wallpaper", action: "WindowFactory.create()", enabled: true, type: "default" },
                        { id: "next_wallpaper", label: qsTr("Next Wallpaper"), icon: "skip_next", action: "Wallpapers.next()", enabled: true, type: "default" },
                        { id: "system_settings", label: qsTr("System Settings"), icon: "settings", command: "systemsettings", enabled: true, type: "default" },
                        { id: "open_terminal", label: qsTr("Open Terminal"), icon: "terminal", command: "terminal", enabled: true, type: "default" },
                        { id: "add_shortcut", label: qsTr("Add Shortcut..."), icon: "add", action: "OpenRightClickMenu", enabled: true, type: "default" }
                    ];
                }

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
                            else if (entry.action === "OpenTerminal") {
                                Quickshell.execDetached([...GlobalConfig.general.apps.terminal]);
                            }
                        } else if (entry.command) {
                            if (entry.command === "terminal") {
                                Quickshell.execDetached([...GlobalConfig.general.apps.terminal]);
                            } else {
                                Quickshell.execDetached(typeof entry.command === "string" ? entry.command.split(" ") : entry.command);
                            }
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
