pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    // Injected by Content.qml's Popout.
    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    readonly property string mode: Config.bar.greeter.mode

    function resolvePath(p: string): string {
        if (!p) return "";
        if (p.startsWith("file://")) {
            p = p.slice(7);
        }
        if (p.startsWith("root:/")) {
            return Quickshell.shellPath(p.slice(6));
        }
        if (p.startsWith("~")) {
            return Paths.home + p.slice(1);
        }
        return p;
    }

    readonly property string timeOfDayCurrentMedia: {
        const hr = Time.hours;
        const mStart = Config.bar.greeter.morningStart;
        const aStart = Config.bar.greeter.afternoonStart;
        const eStart = Config.bar.greeter.eveningStart;
        const nStart = Config.bar.greeter.nightStart;

        if (hr >= mStart && hr < aStart) {
            return resolvePath(Config.bar.greeter.morningGif);
        } else if (hr >= aStart && hr < eStart) {
            return resolvePath(Config.bar.greeter.afternoonGif);
        } else if (hr >= eStart && hr < nStart) {
            return resolvePath(Config.bar.greeter.eveningGif);
        } else {
            return resolvePath(Config.bar.greeter.nightGif);
        }
    }

    Instantiator {
        id: folderScanners

        model: Config.bar.greeter.slideshowFolders

        delegate: FileSystemModel {
            path: root.resolvePath(modelData)
            nameFilters: Images.validImageExtensions.concat(Images.validVideoExtensions).map(e => `*.${e}`)
            recursive: true
        }
    }

    readonly property var allSlideshowMedia: {
        let files = [];
        const manualMedia = Config.bar.greeter.slideshowGifs || [];
        for (let i = 0; i < manualMedia.length; i++) {
            if (manualMedia[i]) files.push(root.resolvePath(manualMedia[i]));
        }
        for (let i = 0; i < folderScanners.count; i++) {
            const scanner = folderScanners.objectAt(i);
            if (scanner && scanner.entries) {
                for (let j = 0; j < scanner.entries.length; j++) {
                    const entry = scanner.entries[j];
                    if (entry && entry.path && !files.includes(entry.path)) {
                        files.push(entry.path);
                    }
                }
            }
        }
        if (files.length === 0) {
            return [
                root.resolvePath(Config.bar.greeter.morningGif),
                root.resolvePath(Config.bar.greeter.afternoonGif),
                root.resolvePath(Config.bar.greeter.eveningGif),
                root.resolvePath(Config.bar.greeter.nightGif)
            ];
        }
        return files;
    }

    property int slideshowIndex: 0
    property string slideshowCurrentMedia: allSlideshowMedia.length > 0 ? allSlideshowMedia[slideshowIndex % allSlideshowMedia.length] : ""

    onAllSlideshowMediaChanged: {
        if (slideshowIndex >= allSlideshowMedia.length) {
            slideshowIndex = 0;
        }
        if (allSlideshowMedia.length > 0) {
            slideshowCurrentMedia = allSlideshowMedia[slideshowIndex];
        }
    }

    Timer {
        id: slideshowTimer

        interval: Math.max(2, Math.round(Config.bar.greeter.slideshowInterval)) * 1000
        running: root.mode === "slideshow" && root.allSlideshowMedia.length > 1
        repeat: true

        onTriggered: {
            const list = root.allSlideshowMedia;
            if (list.length === 0) return;
            if (Config.bar.greeter.slideshowRandom && list.length > 1) {
                let nextIdx = Math.floor(Math.random() * list.length);
                if (nextIdx === root.slideshowIndex) nextIdx = (nextIdx + 1) % list.length;
                root.slideshowIndex = nextIdx;
            } else {
                root.slideshowIndex = (root.slideshowIndex + 1) % list.length;
            }
            root.slideshowCurrentMedia = list[root.slideshowIndex];
        }
    }

    readonly property string mediaPath: mode === "slideshow" ? (slideshowCurrentMedia || allSlideshowMedia[0] || "") : timeOfDayCurrentMedia

    readonly property int previewSize: Math.round(Tokens.sizes.bar.windowPreviewSize * scaleOffset)

    implicitWidth: previewSize
    implicitHeight: previewSize
    width: implicitWidth
    height: implicitHeight

    ClippingWrapperRectangle {
        id: clipRect

        width: root.previewSize
        height: root.previewSize
        implicitWidth: root.previewSize
        implicitHeight: root.previewSize
        anchors.centerIn: parent
        color: "transparent"
        radius: Tokens.rounding.medium

        Loader {
            anchors.fill: parent

            sourceComponent: {
                if (!root.mediaPath) return null;
                if (Images.isVideo(root.mediaPath)) return videoComp;
                if (Images.isAnimated(root.mediaPath)) return animatedComp;
                return imageComp;
            }
        }

        Component {
            id: animatedComp

            AnimatedImage {
                anchors.fill: parent
                cache: false
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: root.mediaPath.startsWith("file:") || root.mediaPath.startsWith("qrc:") ? root.mediaPath : "file://" + root.mediaPath
                playing: true

                onSourceChanged: playing = true
                onStatusChanged: {
                    if (status === Image.Ready) {
                        playing = false;
                        playing = true;
                    }
                }
            }
        }

        Component {
            id: imageComp

            CachingImage {
                anchors.fill: parent
                path: root.mediaPath
                fillMode: Image.PreserveAspectCrop
            }
        }

        Component {
            id: videoComp

            CachingVideo {
                anchors.fill: parent
                path: root.mediaPath
                fillMode: VideoOutput.PreserveAspectCrop
            }
        }
    }
}

