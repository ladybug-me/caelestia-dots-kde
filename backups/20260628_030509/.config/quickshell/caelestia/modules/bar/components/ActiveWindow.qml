pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    readonly property string windowTitle: {
        const hr = new Date().getHours();
        const msg = hr < 12 ? "Good Morning" : hr < 18 ? "Good Afternoon" : hr < 22 ? "Good Evening" : "Good Night";
        const username = Quickshell.env("USER") || "User";
        const formattedUser = username.charAt(0).toUpperCase() + username.slice(1);
        return `${msg}, ${formattedUser}!`;
    }

    readonly property int maxSize: {
        const otherModules = bar.children.filter(c => c.id && c.item !== this && c.id !== "spacer");
        if (bar.isHorizontal) {
            const otherWidth = otherModules.reduce((acc, curr) => acc + (curr.item.nonAnimWidth ?? curr.width), 0);
            return bar.width - otherWidth - bar.spacing * (bar.children.length - 1) - bar.vPadding * 2;
        } else {
            const otherHeight = otherModules.reduce((acc, curr) => acc + (curr.item.nonAnimHeight ?? curr.height), 0);
            return bar.height - otherHeight - bar.spacing * (bar.children.length - 1) - bar.vPadding * 2;
        }
    }
    property Title current: text1

    clip: true
    implicitWidth: bar.isHorizontal ? (icon.implicitWidth + current.width + current.anchors.leftMargin) : Math.max(icon.implicitWidth, current.width)
    implicitHeight: bar.isHorizontal ? Math.max(icon.implicitHeight, current.height) : (icon.implicitHeight + current.height + current.anchors.topMargin)

    Loader {
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = bar.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : root.mapToItem(null, 0, root.implicitHeight / 2).y;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.horizontalCenter: bar.isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: bar.isHorizontal ? parent.verticalCenter : undefined

        animate: true
        text: "waving_hand"
        color: root.colour
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font: root.Tokens.font.body.builders.small.letterSpacing(1.4).build()

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = text;
            root.current = next;
        }
    }

    Behavior on implicitHeight {
        enabled: !bar.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        enabled: bar.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    component Title: Item {
        id: textContainer

        property alias text: styledText.text

        width: bar.isHorizontal ? styledText.implicitWidth : styledText.implicitHeight
        height: bar.isHorizontal ? styledText.implicitHeight : styledText.implicitWidth

        anchors.horizontalCenter: bar.isHorizontal ? undefined : icon.horizontalCenter
        anchors.verticalCenter: bar.isHorizontal ? icon.verticalCenter : undefined
        anchors.top: bar.isHorizontal ? undefined : icon.bottom
        anchors.topMargin: bar.isHorizontal ? 0 : Tokens.spacing.small
        anchors.left: bar.isHorizontal ? icon.right : undefined
        anchors.leftMargin: bar.isHorizontal ? Tokens.spacing.small : 0

        // Custom Title component does not have font/color directly, StyledText child does
        opacity: root.current === this ? 1 : 0

        StyledText {
            id: styledText

            anchors.centerIn: parent

            font.pointSize: metrics.font.pointSize
            font.family: metrics.font.family
            color: root.colour

            rotation: bar.isHorizontal ? 0 : (root.Config.bar.activeWindow.inverted ? 270 : 90)
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
