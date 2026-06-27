pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled

                sourceComponent: Wallpaper {
                    screen: win.modelData
                }
            }


            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
                z: 2
            }


        }

        Loader {
            id: clockLoader

            readonly property int clockBarZone: Visibilities.bars.get(win.modelData.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
            readonly property int clockBaseMargin: Tokens.padding.extraLargeIncreased

            asynchronous: true
            active: Config.background.desktopClock.enabled

            anchors.margins: clockBaseMargin
            anchors.leftMargin: Config.bar.position === "left" ? clockBaseMargin + clockBarZone : clockBaseMargin
            anchors.rightMargin: Config.bar.position === "right" ? clockBaseMargin + clockBarZone : clockBaseMargin
            anchors.topMargin: Config.bar.position === "top" ? clockBaseMargin + clockBarZone : clockBaseMargin
            anchors.bottomMargin: Config.bar.position === "bottom" ? clockBaseMargin + clockBarZone : clockBaseMargin

            anchors.horizontalCenterOffset: {
                if (Config.bar.position === "left") return clockBarZone / 2;
                if (Config.bar.position === "right") return -clockBarZone / 2;
                return 0;
            }
            anchors.verticalCenterOffset: {
                if (Config.bar.position === "top") return clockBarZone / 2;
                if (Config.bar.position === "bottom") return -clockBarZone / 2;
                return 0;
            }

            state: Config.background.desktopClock.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x
                absY: clockLoader.y
            }
        }

        Loader {
            id: lyricsLoader

            readonly property int lyricsBarZone: Visibilities.bars.get(win.modelData.name)?.exclusiveZone ?? (Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness))
            readonly property int lyricsBaseMargin: Tokens.padding.large * 2

            asynchronous: true
            active: Config.background.desktopLyrics.enabled && !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableDesktopLyrics)

            anchors.margins: lyricsBaseMargin
            anchors.leftMargin: Config.bar.position === "left" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
            anchors.rightMargin: Config.bar.position === "right" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
            anchors.topMargin: Config.bar.position === "top" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin
            anchors.bottomMargin: Config.bar.position === "bottom" ? lyricsBaseMargin + lyricsBarZone : lyricsBaseMargin

            anchors.horizontalCenterOffset: {
                if (Config.bar.position === "left") return lyricsBarZone / 2;
                if (Config.bar.position === "right") return -lyricsBarZone / 2;
                return 0;
            }
            anchors.verticalCenterOffset: {
                if (Config.bar.position === "top") return lyricsBarZone / 2;
                if (Config.bar.position === "bottom") return -lyricsBarZone / 2;
                return 0;
            }

            state: Config.background.desktopLyrics.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopLyrics {
                screen: modelData
                wallpaper: behindClock
                absX: lyricsLoader.x
                absY: lyricsLoader.y
            }
        }
    }
}
