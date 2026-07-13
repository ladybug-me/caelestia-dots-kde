import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property var modelData
    required property var list

    function clicked() {
        if (!root.modelData)
            return;
        root.list.visibilities.launcher = false;
        const preview = root.modelData.preview.length > 30 ? root.modelData.preview.slice(0, 30) + "..." : root.modelData.preview;
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + root.modelData.id + " | wl-copy"]);
        Toaster.toast(qsTr("Copied to clipboard"), preview, "content_paste");
    }

    Component.onCompleted: {
        if (!root.modelData?.isImage) return;

        // Check whether the image was already pre-warmed during reload()
        const cached = Clipboard.getImagePath(root.modelData.id);
        // FileInfo is not available in QML directly; use a heuristic: if imagePath is
        // already set by an earlier imageReady emission, we are done. Otherwise listen.
        // The C++ backend emits imageReady for already-cached files too, so we will
        // always receive the signal — but set eagerly in case it fires before onCompleted.
        imagePreview.imagePath = cached;
    }

    /// Listen for the imageReady signal from the C++ backend (forwarded via Clipboard singleton).
    /// This fires as soon as the decoded file is fully written — no timers needed.
    Connections {
        target: Clipboard
        function onImageReady(id: int, path: string): void {
            if (root.modelData?.isImage && id === root.modelData.id)
                imagePreview.imagePath = path;
        }
    }

    implicitHeight: (root.modelData?.isImage ?? false) ? Tokens.sizes.launcher.itemHeight * 2 : Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: root.clicked()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        MaterialIcon {
            id: icon

            text: (root.modelData?.isImage ?? false) ? "image" : "content_paste"
            fontStyle: Tokens.font.icon.builders.large.scale(1.3).build()

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
        }

        Item {
            id: imagePreview

            property string imagePath: ""

            width: (root.modelData?.isImage ?? false) ? 120 : 0
            height: (root.modelData?.isImage ?? false) ? 80 : 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: icon.right
            anchors.leftMargin: (root.modelData?.isImage ?? false) ? Tokens.spacing.medium : 0
            visible: root.modelData?.isImage ?? false

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: imagePreview.imagePath.length > 0 ? "file://" + imagePreview.imagePath : ""
            }
        }

        StyledText {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.medium
            anchors.right: favIcon.left
            anchors.rightMargin: Tokens.spacing.small
            anchors.verticalCenter: parent.verticalCenter

            text: root.modelData?.preview ?? ""
            font: Tokens.font.body.medium
            elide: Text.ElideRight
            visible: !(root.modelData?.isImage ?? false)
        }

        MouseArea {
            id: favIcon

            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            hoverEnabled: true
            onClicked: {
                const clipId = String(root.modelData?.id);
                if (!clipId)
                    return;
                const favClips = GlobalConfig.launcher.favouriteClips ? [...GlobalConfig.launcher.favouriteClips] : [];
                if (favClips.includes(clipId)) {
                    const idx = favClips.indexOf(clipId);
                    if (idx !== -1)
                        favClips.splice(idx, 1);
                } else {
                    favClips.push(clipId);
                }
                GlobalConfig.launcher.favouriteClips = favClips;
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: GlobalConfig.launcher.favouriteClips && GlobalConfig.launcher.favouriteClips.includes(String(root.modelData?.id)) ? "favorite" : "favorite_border"
                fill: GlobalConfig.launcher.favouriteClips && GlobalConfig.launcher.favouriteClips.includes(String(root.modelData?.id)) ? 1 : 0
                color: favIcon.containsMouse ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
