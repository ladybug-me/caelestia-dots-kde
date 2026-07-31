pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import ".."

StyledWindow {
    id: root

    property bool active: Visibilities.overview

    Config.screen: screen.name

    name: "overview"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    color: "transparent"
    visible: true 

    mask: active ? fullRegion : emptyRegion

    Region {
        id: emptyRegion
        x: -10
        y: -10
        width: 1
        height: 1
    }

    Region {
        id: fullRegion
        x: 0
        y: 0
        width: root.width
        height: root.height
    }
    
    Item {
        id: content
        anchors.fill: parent

        opacity: root.active ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        StyledRect {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.7)
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Visibilities.overview = false;
                }
            }
        }

        BlobGroup {
            id: blobGroup
            color: Colours.tPalette.m3surface
            smoothing: Tokens.rounding.large
        }

        BlobRect {
            group: blobGroup
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge
            radius: Tokens.rounding.large
        }

        WorkspaceSwitcher {
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge * 2
        }
    }
}
