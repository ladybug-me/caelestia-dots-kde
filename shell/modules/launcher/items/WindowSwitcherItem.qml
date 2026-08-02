import org.kde.pipewire as Pipewire
import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import Caelestia.Models
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.images
import qs.services

Item {
    id: root

    required property var modelData
    required property var list
    property bool _skipOpenAnim: true

    function clicked(): void {
        KWinActiveWindowBridge.focusWindow(root.modelData.address);
        root.list.visibilities.launcher = false;
    }

    Component.onCompleted: {
        scale = Qt.binding(() => ListView.isCurrentItem ? 1 : 0.8);
        opacity = 1;
        
        if (root.modelData) {
            WinIcons.request(root.modelData.class, root.modelData.title);
        }

        Qt.callLater(() => {
            if (root.list && root.list.visibilities) {
                root.list.visibilities.skipLauncherAnim = false;
            }
        });
    }
    scale: 0.5
    opacity: 0
    z: ListView.isCurrentItem ? 1 : 0
    implicitWidth: previewBox.width + Tokens.padding.largeIncreased * 2
    implicitHeight: previewBox.height + label.height + Tokens.spacing.small / 2 + Tokens.padding.large + Tokens.padding.medium
    width: list.itemWidth

    Connections {
        function onSelectedIndexChanged() {
            root._skipOpenAnim = false;
        }

        target: Windows
    }
    Timer {
        interval: 400
        running: true
        onTriggered: root._skipOpenAnim = false
    }
    StateLayer {
        radius: Tokens.rounding.medium
        onClicked: root.clicked()
    }
    StyledRect {
        id: shadowRect

        anchors.fill: previewBox
        radius: previewBox.radius
        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, root.ListView.isCurrentItem ? 1 : 0)
        opacity: root.ListView.isCurrentItem ? 1 : 0

        Behavior on opacity {
            Anim { type: Anim.FastEffects }
        }
    }
    StyledClippingRect {
        id: previewBox

        readonly property real windowAspect: {
            const size = root.modelData?.size;
            if (size && size.length >= 2) {
                const w = size[0];
                const h = size[1];
                if (w > 0 && h > 0) return w / h;
            }
            return 16.0 / 9.0;
        }
        property var streamRequest: null
        readonly property int serial: streamRequest ? streamRequest.objectSerial : 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium
        implicitWidth: Tokens.sizes.launcher.windowSwitcherWidth
        implicitHeight: implicitWidth / 16 * 9
        Component.onDestruction: {
            if (previewBox.streamRequest && root.modelData && root.modelData.address) {
                ScreencastManager.releaseStream(root.modelData.address);
            }
        }

        Timer {
            id: debounceTimer

            interval: 20
            running: true
            repeat: false
            onTriggered: {
                if (root.modelData && root.modelData.address) {
                    previewBox.streamRequest = ScreencastManager.requestStream(root.modelData.address);
                }
            }
        }
        IconImage {
            anchors.centerIn: parent
            implicitSize: previewBox.height * 0.5
            asynchronous: true
            visible: previewBox.serial === 0
            source: root.modelData ? WinIcons.sourceFor(null, root.modelData.class, root.modelData.iconName) : ""
        }
        Pipewire.PipeWireSourceItem {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height * previewBox.windowAspect)
            height: Math.min(parent.height, parent.width / previewBox.windowAspect)
            visible: previewBox.serial !== 0
            objectSerial: previewBox.serial
        }
    }
    StyledText {
        id: label

        anchors.top: previewBox.bottom
        anchors.topMargin: Tokens.spacing.small / 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: previewBox.width - Tokens.padding.medium * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.modelData?.title ?? ""
        font: Tokens.font.body.medium
    }
    Behavior on scale {
        enabled: !root._skipOpenAnim

        Anim { type: Anim.FastSpatial }
    }
    Behavior on opacity {
        enabled: !root._skipOpenAnim

        Anim { type: Anim.FastEffects }
    }
}
