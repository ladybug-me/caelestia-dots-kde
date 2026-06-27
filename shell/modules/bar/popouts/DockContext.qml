pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts
    property var model: popouts.dockModel

    property bool isPinned: {
        if (!model)
            return false;
        const current = GlobalConfig.launcher.favouriteApps || [];
        for (let i = 0; i < current.length; i++) {
            if (model.id === current[i] || (model.entry && model.entry.id === current[i])) {
                return true;
            }
        }
        return false;
    }

    width: 200
    implicitWidth: 200
    spacing: Tokens.spacing.medium

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true
        visible: model && model.entry != null

        ColumnLayout {
            id: cardLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            // Pin/Unpin action
            StyledRect {
                id: pinItem

                Layout.fillWidth: true
                implicitHeight: pinLabel.implicitHeight

                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    anchors.margins: -Tokens.padding.medium / 2
                    anchors.leftMargin: -Tokens.padding.medium
                    anchors.rightMargin: -Tokens.padding.medium

                    radius: pinItem.radius

                    onClicked: {
                        if (isPinned) {
                            const current = GlobalConfig.launcher.favouriteApps ? [...GlobalConfig.launcher.favouriteApps] : [];
                            let index = current.indexOf(model.id);
                            if (index === -1 && model.entry)
                                index = current.indexOf(model.entry.id);
                            if (index !== -1) {
                                current.splice(index, 1);
                                GlobalConfig.launcher.favouriteApps = current;
                            }
                        } else {
                            const current = GlobalConfig.launcher.favouriteApps ? [...GlobalConfig.launcher.favouriteApps] : [];
                            const idToPin = model.entry ? model.entry.id : model.id;
                            if (!current.includes(idToPin)) {
                                current.push(idToPin);
                                GlobalConfig.launcher.favouriteApps = current;
                            }
                        }
                        root.popouts.hasCurrent = false;
                    }
                }

                StyledText {
                    id: pinLabel

                    anchors.left: parent.left
                    text: isPinned ? qsTr("Unpin from dock") : qsTr("Pin to dock")
                }
            }

            // New window action
            StyledRect {
                id: newWinItem

                Layout.fillWidth: true
                implicitHeight: newWinLabel.implicitHeight

                radius: Tokens.rounding.full
                color: "transparent"

                StateLayer {
                    anchors.margins: -Tokens.padding.medium / 2
                    anchors.leftMargin: -Tokens.padding.medium
                    anchors.rightMargin: -Tokens.padding.medium

                    radius: newWinItem.radius

                    onClicked: {
                        if (model.entry) {
                            const subCmd = model.entry.runInTerminal
                                ? [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...model.entry.command]
                                : model.entry.command;
                            Quickshell.execDetached({
                                command: subCmd,
                                workingDirectory: model.entry.workingDirectory
                            });
                        }
                        root.popouts.hasCurrent = false;
                    }
                }

                StyledText {
                    id: newWinLabel

                    anchors.left: parent.left
                    text: qsTr("Open new window")
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small
        text: qsTr("End task")
        icon: "close"
        visible: model && model.toplevels && model.toplevels.length > 0

        onClicked: {
            for (const toplevel of model.toplevels) {
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${toplevel.address}" })` : `closewindow address:0x${toplevel.address}`);
            }
            root.popouts.hasCurrent = false;
        }
    }
}
