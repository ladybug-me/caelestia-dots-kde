pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var client

    signal closeRequested()

    spacing: Tokens.spacing.small

    RowLayout {
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Move to workspace")
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Layout.topMargin: Tokens.padding.large
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
    }
    Flow {
        id: wsGrid

        clip: true
        spacing: Tokens.spacing.small

        Repeater {
            model: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces.length : 10

            Button {
                required property int index
                readonly property int wsId: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces[index].index : index + 1
                readonly property string wsName: wsId.toString()
                readonly property bool isCurrent: root.client?.workspace?.id === wsId

                onClicked: {
                    if (typeof KWinActiveWindowBridge !== "undefined") {
                        KWinActiveWindowBridge.setWindowDesktop(root.client?.address, wsId);
                        if (typeof KWinWorkspaceState !== "undefined") {
                            KWinWorkspaceState.switchTo(wsId);
                        }
                    }
                    Visibilities.getForActive().overview = false;
                }
                color: isCurrent ? Colours.tPalette.m3surfaceContainerHighest : Colours.palette.m3tertiaryContainer
                onColor: isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
                text: wsName
                disabled: isCurrent
            }
        }
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.spacing.medium
    }
    RowLayout {
        spacing: Tokens.spacing.small

        Button {
            color: Colours.palette.m3secondaryContainer
            onColor: Colours.palette.m3onSecondaryContainer
            text: root.client?.maximized ? qsTr("Restore") : qsTr("Maximize")
            onClicked: {
                console.log("Maximize clicked. Address:", root.client?.address, "Maximized:", root.client?.maximized);
                if (typeof KWinActiveWindowBridge !== "undefined") {
                    console.log("Calling KWinActiveWindowBridge.maximizeWindow");
                    KWinActiveWindowBridge.maximizeWindow(root.client?.address, !root.client?.maximized, !root.client?.maximized);
                } else {
                    console.log("KWinActiveWindowBridge is undefined");
                }
                Visibilities.getForActive().overview = false;
            }
        }
        Loader {
            asynchronous: true
            active: true
            sourceComponent: Button {
                color: Colours.palette.m3secondaryContainer
                onColor: Colours.palette.m3onSecondaryContainer
                text: root.client?.minimized ? qsTr("Unminimize") : qsTr("Minimize")
                onClicked: {
                    if (typeof KWinActiveWindowBridge !== "undefined") {
                        if (root.client?.minimized) {
                            KWinActiveWindowBridge.focusWindow(root.client?.address);
                        } else {
                            KWinActiveWindowBridge.minimizeWindow(root.client?.address);
                        }
                    }
                    Visibilities.getForActive().overview = false;
                }
            }
            Layout.fillWidth: active
            Layout.leftMargin: active ? 0 : -parent.spacing
            Layout.rightMargin: active ? 0 : -parent.spacing
        }
        Button {
            color: Colours.palette.m3errorContainer
            onColor: Colours.palette.m3onErrorContainer
            text: qsTr("Kill")
            onClicked: {
                console.log("Kill clicked. Address:", root.client?.address);
                if (typeof KWinActiveWindowBridge !== "undefined") {
                    console.log("Calling KWinActiveWindowBridge.closeWindow");
                    KWinActiveWindowBridge.closeWindow(root.client?.address);
                }
                Visibilities.getForActive().overview = false;
            }
        }
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.padding.large
    }

    component Button: StyledRect {
        property color onColor: Colours.palette.m3onSurface
        property alias disabled: stateLayer.disabled
        property alias text: label.text

        signal clicked

        radius: Tokens.rounding.medium
        implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: label.implicitHeight + Tokens.padding.small

        StateLayer {
            id: stateLayer

            color: parent.onColor
            onClicked: {
                parent.clicked()
                root.closeRequested()
                const v = typeof Visibilities !== "undefined" ? Visibilities.getForActive() : null;
                if (v) v.overview = false;
            }
        }
        StyledText {
            id: label

            anchors.centerIn: parent
            animate: true
            color: parent.onColor
            font: Tokens.font.body.medium
        }
        Layout.fillWidth: true
    }
}
