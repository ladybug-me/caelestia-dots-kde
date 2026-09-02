import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var client

    spacing: Tokens.spacing.small

    Label {
        text: root.client?.title ?? I18n.tr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        maximumLineCount: 2
        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
        Layout.topMargin: Tokens.padding.extraLargeIncreased
    }
    Label {
        text: root.client?.class ?? I18n.tr("No active client")
        color: Colours.palette.m3tertiary
        font: Tokens.font.body.large
    }
    StyledRect {
        color: Colours.palette.m3secondary
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Tokens.padding.extraLargeIncreased
        Layout.rightMargin: Tokens.padding.extraLargeIncreased
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.largeIncreased
    }
    Detail {
        icon: "location_on"
        text: I18n.tr("Address: %1").arg(root.client?.address ?? "unknown")
        color: Colours.palette.m3primary
    }
    Detail {
        icon: "location_searching"
        text: I18n.tr("Position: %1, %2").arg(root.client?.x ?? -1).arg(root.client?.y ?? -1)
    }
    Detail {
        icon: "resize"
        text: I18n.tr("Size: %1 x %2").arg(root.client?.width ?? -1).arg(root.client?.height ?? -1)
        color: Colours.palette.m3tertiary
    }
    Detail {
        icon: "workspaces"
        text: I18n.tr("Workspace: %1").arg(root.client?.workspace?.id ?? -1)
        color: Colours.palette.m3secondary
    }
    Detail {
        icon: "picture_in_picture_center"
        text: I18n.tr("Floating: %1").arg(root.client?.floating ? "yes" : "no")
        color: Colours.palette.m3secondary
    }
    Detail {
        icon: "fullscreen"
        text: {
            const fs = root.client?.fullscreen;
            if (fs !== undefined)
                return I18n.tr("Fullscreen state: %1").arg(fs ? "on" : "off");
            return I18n.tr("Fullscreen state: unknown");
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

        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            text: detail.icon
            Layout.alignment: Qt.AlignVCenter
        }
        StyledText {
            text: detail.text
            elide: Text.ElideRight
            font: Tokens.font.body.medium
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true
    }
    component Label: StyledText {
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true
    }
}
