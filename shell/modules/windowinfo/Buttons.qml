pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var client
    property bool moveToWsExpanded

    spacing: Tokens.spacing.small

    RowLayout {
        Layout.topMargin: Tokens.padding.large
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large

        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Move to workspace")
            elide: Text.ElideRight
        }

        StyledRect {
            color: Colours.palette.m3primary
            radius: Tokens.rounding.medium

            implicitWidth: moveToWsIcon.implicitWidth + Tokens.padding.small
            implicitHeight: moveToWsIcon.implicitHeight + Tokens.padding.extraSmall

            StateLayer {
                color: Colours.palette.m3onPrimary
                onClicked: root.moveToWsExpanded = !root.moveToWsExpanded
            }

            MaterialIcon {
                id: moveToWsIcon

                anchors.centerIn: parent

                animate: true
                text: root.moveToWsExpanded ? "expand_more" : "keyboard_arrow_right"
                color: Colours.palette.m3onPrimary
                fontStyle: Tokens.font.icon.large
            }
        }
    }

    GridLayout {
        id: wsGrid

        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: root.moveToWsExpanded ? Tokens.spacing.medium : 0
        Layout.preferredHeight: root.moveToWsExpanded ? implicitHeight : 0
        opacity: root.moveToWsExpanded ? 1 : 0
        clip: true

        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small
        columns: 5

        Behavior on Layout.bottomMargin {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Repeater {
            model: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces.length : 10

            Button {
                required property int index
                readonly property int wsId: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces[index].id : index + 1
                readonly property string wsName: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces[index].name : wsId
                readonly property bool isCurrent: root.client?.workspace?.id === wsId

                onClicked: {
                    if (typeof KWinActiveWindowBridge !== "undefined") {
                        KWinActiveWindowBridge.setWindowDesktop(root.client?.address, wsId);
                    }
                }

                color: isCurrent ? Colours.tPalette.m3surfaceContainerHighest : Colours.palette.m3tertiaryContainer
                onColor: isCurrent ? Colours.palette.m3onSurface : Colours.palette.m3onTertiaryContainer
                text: wsName
                disabled: isCurrent
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.bottomMargin: Tokens.padding.large

        spacing: Tokens.spacing.small

        Button {
            color: Colours.palette.m3secondaryContainer
            onColor: Colours.palette.m3onSecondaryContainer
            text: root.client?.maximized ? qsTr("Restore") : qsTr("Maximize")
            onClicked: {
                if (typeof KWinActiveWindowBridge !== "undefined") {
                    KWinActiveWindowBridge.maximizeWindow(root.client?.address, !root.client?.maximized, !root.client?.maximized);
                }
            }
        }

        Loader {
            asynchronous: true
            active: true
            Layout.fillWidth: active
            Layout.leftMargin: active ? 0 : -parent.spacing
            Layout.rightMargin: active ? 0 : -parent.spacing

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
                }
            }
        }

        Button {
            color: Colours.palette.m3errorContainer
            onColor: Colours.palette.m3onErrorContainer
            text: qsTr("Kill")
            onClicked: {
                if (typeof KWinActiveWindowBridge !== "undefined") {
                    KWinActiveWindowBridge.closeWindow(root.client?.address);
                }
            }
        }
    }

    component Button: StyledRect {
        property color onColor: Colours.palette.m3onSurface
        property alias disabled: stateLayer.disabled
        property alias text: label.text

        signal clicked

        radius: Tokens.rounding.medium

        Layout.fillWidth: true
        implicitHeight: label.implicitHeight + Tokens.padding.small

        StateLayer {
            id: stateLayer

            color: parent.onColor
            onClicked: parent.clicked()
        }

        StyledText {
            id: label

            anchors.centerIn: parent

            animate: true
            color: parent.onColor
            font: Tokens.font.body.medium
        }
    }
}
