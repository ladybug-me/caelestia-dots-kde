pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components

Item {
    id: root
    
    enabled: false

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels

    readonly property bool shouldBeActive: visibilities.overview

    onShouldBeActiveChanged: {
        Quickshell.execDetached(["bash", "-c", `
            STATE=$(qdbus6 org.kde.KWin /KWin org.kde.KWin.showingDesktop)
            TARGET=${shouldBeActive ? "true" : "false"}
            if [ "$STATE" != "$TARGET" ]; then
                qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut "Show Desktop"
            fi
        `]);
    }

    width: (shouldBeActive || opacity > 0) ? parent.width : 0
    height: (shouldBeActive || opacity > 0) ? parent.height : 0
    
    // Position it at 0,0 when it has size
    x: 0
    y: 0

    visible: shouldBeActive || opacity > 0
    opacity: shouldBeActive ? 1 : 0

    Behavior on opacity {
        Anim { type: Anim.DefaultEffects }
    }

    Loader {
        id: content
        anchors.fill: parent
        active: root.shouldBeActive || root.visible
        sourceComponent: Component {
            Content {
                visibilities: root.visibilities
                panels: root.panels
            }
        }
    }
}
