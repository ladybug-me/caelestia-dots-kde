import ".."
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property var action
    property var selectionMode
    property bool active: false

    visible: opacity > 0
    opacity: active ? 1.0 : 0.0

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: root.active ? 150 : 0 }
            Anim { type: Anim.FastEffects }
        }
    }

    property string description: switch (root.action) {
    case ScreenshotAction.SnipAction.Copy:
    case ScreenshotAction.SnipAction.Edit:
        return qsTr("Copy region (LMB) or annotate (RMB)");
    case ScreenshotAction.SnipAction.Search:
        return qsTr("Search with Google Lens");
    case ScreenshotAction.SnipAction.CharRecognition:
        return qsTr("Recognize text");
    case ScreenshotAction.SnipAction.Record:
    case ScreenshotAction.SnipAction.RecordWithSound:
        return qsTr("Record region");
    }

    property string materialSymbol: switch (root.action) {
    case ScreenshotAction.SnipAction.Copy:
    case ScreenshotAction.SnipAction.Edit:
        return "content_cut";
    case ScreenshotAction.SnipAction.Search:
        return "image_search";
    case ScreenshotAction.SnipAction.CharRecognition:
        return "document_scanner";
    case ScreenshotAction.SnipAction.Record:
    case ScreenshotAction.SnipAction.RecordWithSound:
        return "videocam";

    default:
        return "";
    }

    property bool showDescription: true

    property int margins: 8

    implicitWidth: content.implicitWidth + margins * 2

    implicitHeight: content.implicitHeight + margins * 2

    Rectangle {
        id: content

        anchors.left: parent.left
        anchors.leftMargin: root.margins
        anchors.verticalCenter: parent.verticalCenter

        property real padding: 8
        implicitHeight: 38
        implicitWidth: root.showDescription ? contentRow.implicitWidth + padding * 2 : implicitHeight
        width: root.active ? implicitWidth : implicitHeight

        Behavior on width {
            SequentialAnimation {
                PauseAnimation { duration: root.active ? 150 : 0 }
                Anim { type: Anim.SlowSpatial }
            }
        }

        clip: true

        topLeftRadius: 6

        bottomLeftRadius: implicitHeight - topLeftRadius

        bottomRightRadius: bottomLeftRadius

        topRightRadius: bottomLeftRadius

        color: Colours.palette.m3surfaceContainerHigh

        border.width: 1

        border.color: Colours.palette.m3outlineVariant

        Row {
            id: contentRow
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: content.padding
            }

            spacing: 12

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                fontStyle.pointSize: 22
                color: Colours.palette.m3onSurface
                text: root.materialSymbol
            }

            StyledText {
                id: descriptionText

                anchors.verticalCenter: parent.verticalCenter
                color: Colours.palette.m3onSurface
                text: root.description
            }
        }
    }
}
