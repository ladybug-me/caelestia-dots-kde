import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var client

    anchors.fill: parent
    spacing: Tokens.spacing.small

    Label {
        Layout.topMargin: Tokens.padding.extraLargeIncreased

        text: root.client?.title ?? qsTr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
    }

    Label {
        text: root.client?.class ?? qsTr("No active client")
        color: Colours.palette.m3tertiary

        font: Tokens.font.body.large
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Tokens.padding.extraLargeIncreased
        Layout.rightMargin: Tokens.padding.extraLargeIncreased
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.largeIncreased

        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "location_on"
        text: qsTr("Address: %1").arg(root.client?.address ?? "unknown")
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "location_searching"
        text: qsTr("Position: %1, %2").arg(root.client?.x ?? -1).arg(root.client?.y ?? -1)
    }

    Detail {
        icon: "resize"
        text: qsTr("Size: %1 x %2").arg(root.client?.width ?? -1).arg(root.client?.height ?? -1)
        color: Colours.palette.m3tertiary
    }

    Detail {
        icon: "workspaces"
        text: qsTr("Workspace: %1").arg(root.client?.workspace?.id ?? -1)
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "picture_in_picture_center"
        text: qsTr("Floating: %1").arg(root.client?.floating ? "yes" : "no")
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "fullscreen"
        text: {
            const fs = root.client?.fullscreen;
            if (fs !== undefined)
                return qsTr("Fullscreen state: %1").arg(fs ? "on" : "off");
            return qsTr("Fullscreen state: unknown");
        }
        color: Colours.palette.m3tertiary
    }

    Item {
        Layout.fillHeight: true
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text
        property alias color: icon.color

        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true

        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: detail.icon
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: detail.text
            elide: Text.ElideRight
            font: Tokens.font.body.medium
        }
    }

    component Label: StyledText {
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
    }
}
