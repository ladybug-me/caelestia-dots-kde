pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    ExclusionZone {
        anchors.left: true
        exclusiveZone: Config.bar.position === "left" ? root.bar.exclusiveZone : contentItem.Config.border.thickness
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: Config.bar.position === "top" ? root.bar.exclusiveZone : contentItem.Config.border.thickness
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: Config.bar.position === "right" ? root.bar.exclusiveZone : contentItem.Config.border.thickness
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: Config.bar.position === "bottom" ? root.bar.exclusiveZone : contentItem.Config.border.thickness
        Config.screen: root.screen.name
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        Config.screen: root.screen.name
    }
}
