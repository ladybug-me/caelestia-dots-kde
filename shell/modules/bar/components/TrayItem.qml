pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property SystemTrayItem modelData
    property int trayIndex: -1
    property var popouts
    property bool isHorizontal: false
    readonly property bool hasMenuEntries: menuOpener.children.values.some(entry => !entry.isSeparator)

    implicitWidth: Tokens.font.body.small.pointSize * 2
    implicitHeight: Tokens.font.body.small.pointSize * 2

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: root.implicitWidth + Tokens.padding.extraSmall
        implicitHeight: root.implicitHeight + Tokens.padding.extraSmall
        radius: Tokens.rounding.full
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: event => {
            if (event.button === Qt.RightButton) {
                if (root.popouts) {
                    root.popouts.currentName = `traymenu${root.trayIndex}`;
                    root.popouts.currentCenter = root.isHorizontal
                        ? root.mapToItem(null, root.implicitWidth / 2, 0).x
                        : root.mapToItem(null, 0, root.implicitHeight / 2).y;
                    root.popouts.hasCurrent = true;
                }
            } else {
                root.modelData.activate();
            }
        }
    }

    QsMenuOpener {
        id: menuOpener

        menu: root.modelData.menu // qmllint disable unresolved-type
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
