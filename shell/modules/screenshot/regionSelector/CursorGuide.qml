import ".."
import QtQuick
import qs.components

Item {
    id: root
    property var action
    property var selectionMode

    property string description: switch (root.action) {
    case RegionSelection.SnipAction.Copy:
    case RegionSelection.SnipAction.Edit:
        return qsTr("Copy region (LMB) or annotate (RMB)");
    case RegionSelection.SnipAction.Search:
        return qsTr("Search with Google Lens");
    case RegionSelection.SnipAction.CharRecognition:
        return qsTr("Recognize text");
    case RegionSelection.SnipAction.Record:
    case RegionSelection.SnipAction.RecordWithSound:
        return qsTr("Record region");
    }
    property string materialSymbol: switch (root.action) {
    case RegionSelection.SnipAction.Copy:
    case RegionSelection.SnipAction.Edit:
        return "content_cut";
    case RegionSelection.SnipAction.Search:
        return "image_search";
    case RegionSelection.SnipAction.CharRecognition:
        return "document_scanner";
    case RegionSelection.SnipAction.Record:
    case RegionSelection.SnipAction.RecordWithSound:
        return "videocam";
    default:
        return "";
    }

    property bool showDescription: true
    function hideDescription() {
        root.showDescription = false
    }
    Timer {
        id: descTimeout
        interval: 1000
        running: true
        onTriggered: {
            root.hideDescription()
        }
    }
    onActionChanged: {
        root.showDescription = true
        descTimeout.restart()
    }

    property int margins: 8
    implicitWidth: content.implicitWidth + margins * 2
    implicitHeight: content.implicitHeight + margins * 2

    Rectangle {
        id: content
        anchors.centerIn: parent

        property real padding: 8
        implicitHeight: 38
        implicitWidth: root.showDescription ? contentRow.implicitWidth + padding * 2 : implicitHeight
        clip: true

        topLeftRadius: 6
        bottomLeftRadius: implicitHeight - topLeftRadius
        bottomRightRadius: bottomLeftRadius
        topRightRadius: bottomLeftRadius

        color: Colours.palette.m3primary

        Behavior on topLeftRadius {
            animation: NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
        }
        Behavior on implicitWidth {
            animation: NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
        }

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
                color: Colours.palette.m3onPrimary
                text: root.materialSymbol
            }

            StyledText {
                id: descriptionText
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.showDescription ? 1 : 0
                visible: opacity > 0
                color: Colours.palette.m3onPrimary
                text: root.description
                anchors.right: parent.right
                anchors.rightMargin: 6
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
