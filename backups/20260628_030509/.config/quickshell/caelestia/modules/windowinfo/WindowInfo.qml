import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    property string clientAddress: ""

    property HyprlandToplevel client: {
        if (clientAddress !== "") {
            for (const t of Hypr.toplevels.values) {
                if (t.address === clientAddress) {
                    return t;
                }
            }
        }
        return Hypr.activeToplevel;
    }

    implicitWidth: child.implicitWidth
    implicitHeight: screen.height * Tokens.sizes.winfo.heightMult

    RowLayout {
        id: child

        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        spacing: Tokens.spacing.medium

        Preview {
            screen: root.screen
            client: root.client
        }

        ColumnLayout {
            spacing: Tokens.spacing.medium

            Layout.preferredWidth: Tokens.sizes.winfo.detailsWidth
            Layout.fillHeight: true

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.large
                clip: true

                Details {
                    client: root.client
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: buttons.implicitHeight

                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.large

                Buttons {
                    id: buttons

                    client: root.client
                }
            }
        }
    }
}
