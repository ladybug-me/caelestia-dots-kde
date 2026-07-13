pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

StyledRect {
    id: root

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property int barThickness: Math.round(Tokens.sizes.bar.innerWidth * Math.max(0.6, !isNaN(Config.bar.scale) ? Config.bar.scale : 1.0))

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    implicitWidth: isHorizontal ? (icon.implicitWidth + Tokens.padding.medium * 2) : barThickness
    implicitHeight: isHorizontal ? barThickness : (icon.implicitHeight + Tokens.padding.medium * 2)

    MaterialIcon {
        id: icon

        anchors.centerIn: parent
        text: {
            if (Notifs.dnd)
                return "notifications_off";
            if (Notifs.notClosed.length > 0)
                return "notifications_unread";
            return "notifications";
        }
        color: Colours.palette.m3secondary
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Notifs.dnd = !Notifs.dnd;
            } else {
                const vis = Visibilities.getForActive();
                vis.sidebar = !vis.sidebar;
            }
        }
    }
}