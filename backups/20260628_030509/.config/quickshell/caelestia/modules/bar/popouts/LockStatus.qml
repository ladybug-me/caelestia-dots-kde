import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal

    implicitWidth: Math.max(300, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.leftMargin: Tokens.padding.small
        text: qsTr("Keyboard Locks")
        font.weight: 500
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: cardLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.small

            StyledText {
                text: qsTr("Capslock: %1").arg(Hypr.capsLock ? "Enabled" : "Disabled")
            }

            StyledText {
                text: qsTr("Numlock: %1").arg(Hypr.numLock ? "Enabled" : "Disabled")
            }
        }
    }
}
