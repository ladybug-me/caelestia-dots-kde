pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    function create(parent: Item, props: var): var {
        return nexusComp.createObject(parent ?? dummy, props);
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win
            
            property alias nexus: nexus
            
            property int initialPageIdx: 0
            property int initialSubPageIdx: -1

            color: Colours.tPalette.m3surface
            // Commented because nexus bg depends on the above
            // color: GlobalConfig.appearance.transparency.enabled ? Qt.alpha(Colours.tPalette.m3surface, 0) : Colours.tPalette.m3surface
            
            surfaceFormat.opaque: false

            BackgroundEffect.blurRegion: Region {
                Region { x: -10; y: -10; width: 1; height: 1 } // Prevent full-window blur fallback when disabled
                Region { item: (GlobalConfig.appearance.transparency.enabled && GlobalConfig.appearance.blur) ? nexus : null }
            }

            onVisibleChanged: {
                // Some Quickshell versions do not expose a cancellable close
                // signal on FloatingWindow. If the window is being hidden while
                // an update runs, reopen and route through Nexus' close guard.
                if (!visible && UpdateChecker.updateRunning) {
                    visible = true;
                    nexus.requestClose();
                    return;
                }

                if (!visible)
                    destroy();
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: Tokens.sizes.nexus.minWidth
            minimumSize.height: Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: I18n.tr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx].label)

            Nexus {
                id: nexus

                anchors.fill: parent
                initialPageIdx: win.initialPageIdx
                initialSubPageIdx: win.initialSubPageIdx
                nState.screen: win.screen
                nState.isWindow: true
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
