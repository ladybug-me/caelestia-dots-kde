pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.utils

// Reveal-animated list row shared by the bar popouts (network, bluetooth).
// Each popout used to copy this preamble into every row and drift in small
// ways; now the reveal lives in one place and rows declare content only.
RowLayout {
    id: root

    property real rowScale: 1.0

    Layout.fillWidth: true
    Layout.rightMargin: Tokens.padding.extraSmall * root.rowScale
    spacing: Tokens.spacing.small * root.rowScale

    opacity: 0
    scale: 0.7

    Component.onCompleted: {
        opacity = 1;
        scale = 1;
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Behavior on scale {
        Anim {}
    }
}
