import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

StyledRect {
    id: root

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.large
    clip: true

    property string clientAddress: ""

    property var client: {
        if (typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.windowList) {
            if (clientAddress !== "") {
                for (let i = 0; i < KWinActiveWindowBridge.windowList.length; ++i) {
                    if (KWinActiveWindowBridge.windowList[i].address === clientAddress) {
                        return KWinActiveWindowBridge.windowList[i];
                    }
                }
            } else {
                for (let i = 0; i < KWinActiveWindowBridge.windowList.length; ++i) {
                    if (KWinActiveWindowBridge.activeWindow && KWinActiveWindowBridge.windowList[i].address === KWinActiveWindowBridge.activeWindow.address) {
                        return KWinActiveWindowBridge.windowList[i];
                    }
                }
            }
        }
        return null;
    }

    implicitWidth: child.implicitWidth
    implicitHeight: typeof Quickshell !== "undefined" && Quickshell.ShellRoot.activeScreen ? Quickshell.ShellRoot.activeScreen.height * Tokens.sizes.winfo.heightMult : 600

    RowLayout {
        id: child

        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        spacing: Tokens.spacing.medium

        Preview {
            Layout.preferredWidth: {
                const w = root.client ? (root.client.width > 0 ? root.client.width : 16) : 16;
                const h = root.client ? (root.client.height > 0 ? root.client.height : 10) : 10;
                const aspect = w / h;
                const availableHeight = 600 - Tokens.padding.large * 2;
                return Math.min(availableHeight * aspect, 600); // Max preview width is 600px
            }
            Layout.fillHeight: true
            client: root.client
        }

        ColumnLayout {
            spacing: Tokens.spacing.medium

            Layout.fillWidth: true
            Layout.fillHeight: true

            Details {
                Layout.fillWidth: true
                Layout.fillHeight: true
                client: root.client
            }

            Buttons {
                id: buttons

                Layout.fillWidth: true
                client: root.client
            }
        }
    }
}
