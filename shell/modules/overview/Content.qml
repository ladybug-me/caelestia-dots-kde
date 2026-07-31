pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import "../background"
import ".."

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var panels

    property real wallpaperWidthRatio: 0.7
    property real wallpaperHeightRatio: 0.7

    Item {
        id: centerContainer
        anchors.centerIn: parent
        width: parent.width * root.wallpaperWidthRatio
        height: parent.height * root.wallpaperHeightRatio

        BlobGroup {
            id: overviewBlobGroup
            color: Colours.palette.m3surfaceContainerLow
        }

        BlobRect {
            anchors.fill: parent
            group: overviewBlobGroup
            radius: Tokens.rounding.extraLarge
        }

        Item {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: ShaderEffectSource {
                    sourceItem: Rectangle {
                        width: centerContainer.width - Tokens.padding.large * 2
                        height: centerContainer.height - Tokens.padding.large * 2
                        radius: Tokens.rounding.extraLarge
                    }
                    hideSource: true
                }
            }

            Wallpaper {
                anchors.fill: parent
                screen: QsWindow.window ? QsWindow.window.screen : null
            }
        }
    }

    WindowGrid {
        anchors.fill: parent
    }
}
