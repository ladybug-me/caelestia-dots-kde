pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property string hash: ""
    property string subject: ""
    property string author: ""
    property string date: ""
    property string details: ""
    property int detailsMaxLines: 8

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: "commit"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.subject
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.date !== "" ? qsTr("%1 • %2").arg(root.author).arg(root.date) : root.author
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.details !== ""
                text: root.details
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
                wrapMode: Text.Wrap
                maximumLineCount: root.detailsMaxLines
                elide: Text.ElideRight
            }
        }

        StyledRect {
            color: Colours.tPalette.m3surfaceContainerHigh
            radius: Tokens.rounding.extraSmall
            implicitWidth: hashText.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: hashText.implicitHeight + Tokens.padding.extraSmall * 2

            StyledText {
                id: hashText
                anchors.centerIn: parent
                text: root.hash
                font: Tokens.font.label.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
