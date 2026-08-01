pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import org.kde.pipewire as Pipewire
import Quickshell.Widgets

Item {
    id: root

    required property var client

    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitWidth: 400
    implicitHeight: 300

    Item {
        id: previewContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.spacing.medium

        StyledClippingRect {
            id: preview

            readonly property real windowAspect: {
                const w = root.client ? (root.client.width > 0 ? root.client.width : 16) : 16;
                const h = root.client ? (root.client.height > 0 ? root.client.height : 10) : 10;
                return w / h;
            }

            width: {
                const containerAspect = previewContainer.width / previewContainer.height;
                if (windowAspect > containerAspect) {
                    return previewContainer.width;
                } else {
                    return previewContainer.height * windowAspect;
                }
            }

            height: {
                const containerAspect = previewContainer.width / previewContainer.height;
                if (windowAspect > containerAspect) {
                    return previewContainer.width / windowAspect;
                } else {
                    return previewContainer.height;
                }
            }

            anchors.centerIn: parent
            radius: Tokens.rounding.medium

        property var streamRequest: null
        property string lastRequestedAddress: ""

        function updateStream() {
            const addr = (root.client && root.client.address) ? root.client.address : "";
            if (addr !== lastRequestedAddress) {
                if (lastRequestedAddress !== "") {
                    ScreencastManager.releaseStream(lastRequestedAddress);
                }
                if (addr !== "") {
                    streamRequest = ScreencastManager.requestStream(addr);
                } else {
                    streamRequest = null;
                }
                lastRequestedAddress = addr;
            }
        }

        Component.onCompleted: updateStream()
        Component.onDestruction: {
            if (lastRequestedAddress !== "") {
                ScreencastManager.releaseStream(lastRequestedAddress);
            }
        }

        Connections {
            target: root
            function onClientChanged() {
                preview.updateStream();
            }
        }

        readonly property int screencastSerial: streamRequest ? streamRequest.objectSerial : 0

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            active: !root.client || parent.screencastSerial === 0

            sourceComponent: ColumnLayout {
                spacing: 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "web_asset_off"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(3).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No active client")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.builders.large.size(28).weight(Font.Medium).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Try switching to a window")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.large
                }
            }
        }

        Pipewire.PipeWireSourceItem {
            id: view
            anchors.fill: parent
            visible: preview.screencastSerial !== 0
            objectSerial: preview.screencastSerial
        }
    }
}
}
