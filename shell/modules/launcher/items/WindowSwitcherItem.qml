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
import qs.utils
import qs.modules.launcher.services

Item {
    id: root

    required property var modelData
    required property var list

    property bool _skipOpenAnim: true

    function clicked(): void {
        KWinActiveWindowBridge.focusWindow(root.modelData.address);
        root.list.visibilities.launcher = false;
    }

    // Unlike clicked(), stays in the switcher rather than closing the launcher —
    // the point is closing several windows in a row without re-opening it each time.
    function closeWindow(): void {
        Windows.closeWindow(root.modelData.address);
    }

    width: list.itemWidth
    implicitWidth: previewBox.maxW + Tokens.padding.largeIncreased * 2
    implicitHeight: previewBox.maxH + label.height + Tokens.spacing.small / 2 + Tokens.padding.large + Tokens.padding.medium
    scale: 0.5
    opacity: 0
    z: ListView.isCurrentItem ? 1 : 0

    Component.onCompleted: {
        scale = Qt.binding(() => ListView.isCurrentItem ? 1 : 0.8);
        opacity = 1;

        if (root.modelData) {
            WinIcons.request(root.modelData.class, root.modelData.title, root.modelData.pid ?? 0, root.modelData.address ? String(root.modelData.address) : "");
        }

        Qt.callLater(() => {
            if (root.list && root.list.visibilities) {
                root.list.visibilities.skipLauncherAnim = false;
            }
        });
    }

    HoverHandler {
        id: tileHover
    }

    StateLayer {
        anchors.leftMargin: -Tokens.padding.large
        anchors.rightMargin: -Tokens.padding.large
        radius: Tokens.rounding.medium
        onClicked: root.clicked()
    }

    StyledRect {
        id: shadowRect

        anchors.fill: previewBox
        radius: previewBox.radius
        //color: Colours.layer(Colours.palette.m3surfaceContainerHighest, root.ListView.isCurrentItem ? 1 : 0)
        color: "transparent"
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
        readonly property real maxW: Tokens.sizes.launcher.windowSwitcherWidth
        readonly property real maxH: maxW / 16 * 9
        property var streamRequest: null
        readonly property int serial: streamRequest ? (streamRequest.objectSerial || streamRequest.nodeId) : 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        implicitWidth: {
            const h = maxW / windowAspect;
            if (h > maxH) return maxH * windowAspect;
            return maxW;
        }
        implicitHeight: {
            const w = maxH * windowAspect;
            if (w > maxW) return maxW / windowAspect;
            return maxH;
        }
        color: "transparent"
        radius: Tokens.rounding.medium

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
            source: root.modelData ? WinIcons.sourceFor(null, root.modelData.class, root.modelData.iconName, root.modelData.pid ?? 0) : ""
        }

        Pipewire.PipeWireSourceItem {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height * previewBox.windowAspect)
            height: Math.min(parent.height, parent.width / previewBox.windowAspect)
            visible: previewBox.serial !== 0
            Component.onCompleted: {
                if ("objectSerial" in this) {
                    this.objectSerial = Qt.binding(() => previewBox.streamRequest ? previewBox.streamRequest.objectSerial : 0)
                } else if ("nodeId" in this) {
                    this.nodeId = Qt.binding(() => previewBox.streamRequest ? previewBox.streamRequest.nodeId : 0)
                }
            }
        }

        // Close button — only revealed while hovering this tile, same convention as
        // the taskbar's own preview popup (DockHover.qml).
        StyledRect {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * 2
            implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceVariant
            opacity: tileHover.hovered ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                Anim {}
            }

            StateLayer {
                anchors.fill: parent
                radius: Tokens.rounding.small
                onClicked: root.closeWindow()
            }

            MaterialIcon {
                id: closeIcon

                anchors.centerIn: parent
                text: "close"
            }
        }
    }

    StyledText {
        id: label

        anchors.top: previewBox.bottom
        anchors.topMargin: Tokens.spacing.small / 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: previewBox.maxW - Tokens.padding.medium * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.modelData?.title ?? ""
        font: Tokens.font.body.medium
    }

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

    Behavior on scale {
        enabled: !root._skipOpenAnim

        Anim { type: Anim.FastSpatial }
    }

    Behavior on opacity {
        enabled: !root._skipOpenAnim

        Anim { type: Anim.FastEffects }
    }
}
