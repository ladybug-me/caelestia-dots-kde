pragma Singleton

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps
import qs.modules.nexus.pages.audio
import qs.modules.nexus.pages.bluetooth
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar

QtObject {
    id: root

    readonly property list<Component> pageComps: [
        // Personalization
        Component {
            // Appearance
            StackPage {
                Component {
                    WallpaperAndStyle {}
                }
                Component {
                    WallpaperSelect {}
                }
                Component {
                    WallpaperCategory {}
                }
                Component {
                    ColourSelect {}
                }
                Component {
                    WallhavenPage {}
                }
                Component {
                    WallpaperSettingsPage {}
                }
                Component {
                    SlideshowAndOrderPage {}
                }
                Component {
                    VideoWallpapersPage {}
                }
                Component {
                    AppearancePage {}
                }
            }
        },
        Component {
            // Desktop
            StackPage {
                Component {
                    DesktopPage {}
                }
                Component {
                    DesktopAddonsPage {}
                }
                Component {
                    ContextMenuPage {}
                }
            }
        },
        Component {
            // Panels
            StackPage {
                Component {
                    PanelsPage {}
                }
                Component {
                    DashboardPanel {}
                }
                Component {
                    TaskbarPanel {}
                }
                Component {
                    LauncherPanel {}
                }
                Component {
                    SidebarPanel {}
                }

                // Taskbar component sub-pages
                Component {
                    BarComponents {}
                }
                Component {
                    BarWorkspaces {}
                }
                Component {
                    BarActiveWindow {}
                }
                Component {
                    BarTray {}
                }
                Component {
                    BarStatusIcons {}
                }
                Component {
                    BarClock {}
                }
                Component {
                    BarDock {}
                }
                Component {
                    BarGithub {}
                }
                Component {
                    BarPreviewScales {}
                }
                Component {
                    TaskbarElements {}
                }
            }
        },

        // Connectivity
        Component {
            // Network
            StackPage {
                Component {
                    NetworkPage {}
                }
            }
        },
        Component {
            // Bluetooth
            StackPage {
                Component {
                    BluetoothPage {}
                }
                Component {
                    BtDeviceInfo {}
                }
                Component {
                    BluetoothPairing {}
                }
            }
        },
        Component {
            // Audio
            StackPage {
                Component {
                    AudioPage {}
                }
                Component {
                    AppVolumes {}
                }
            }
        },

        // Controls
        Component {
            // Notifications
            StackPage {
                Component {
                    NotificationsPage {}
                }
            }
        },
        Component {
            // Utilities
            StackPage {
                Component {
                    UtilitiesPage {}
                }
                Component {
                    GameModePage {}
                }
                Component {
                    GameModeTargetsPage {}
                }
            }
        },
        Component {
            // Power
            StackPage {
                Component {
                    PowerPage {}
                }
            }
        },

        // Shell
        Component {
            // Apps
            StackPage {
                Component {
                    AppsPage {}
                }
                Component {
                    AllApps {}
                }
                Component {
                    AppInfo {}
                }
            }
        },
        Component {
            // Services
            StackPage {
                Component {
                    ServicesPage {}
                }
                Component {
                    ArpcPage {}
                }
            }
        },
        Component {
            // Language & region
            StackPage {
                Component {
                    LanguageAndRegion {}
                }
            }
        },

        // System
        Component {
            // Updates
            StackPage {
                Component {
                    UpdatesPage {}
                }
            }
        },
        Component {
            // Plugins
            StackPage {
                Component {
                    PluginsPage {}
                }
            }
        },
        Component {
            StackPage {
                Component {
                    AboutPage {}
                }
            }
        }
    ]

    readonly property Component placeholderComp: Component {
        PlaceholderComp {}
    }

    component PlaceholderComp: Item {
        property NexusState nState // To avoid the warning from non-existent property

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.padding.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "handyman"
                color: Colours.palette.m3outlineVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Page under construction")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.title.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("This page will be available in a future update.")
                color: Colours.palette.m3outlineVariant
                font: Tokens.font.body.large
            }
        }
    }
}
