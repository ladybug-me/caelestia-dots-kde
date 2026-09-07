pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property PopoutState popouts

    // Injected by Content.qml's Popout.
    property real scaleOffset: 1.0
    property real fontScale: 1.0
    property bool _isSidebarOpen: false

    readonly property string mode: Config.bar.greeter.mode || "timeOfDay"

    function getTimeOfDayGif(): string {
        const hr = new Date().getHours();
        const mStart = Config.bar.greeter.morningStart ?? 5;
        const aStart = Config.bar.greeter.afternoonStart ?? 12;
        const eStart = Config.bar.greeter.eveningStart ?? 17;
        const nStart = Config.bar.greeter.nightStart ?? 20;

        let chosen = "";
        if (hr >= mStart && hr < aStart) {
            chosen = Config.bar.greeter.morningGif || "root:/assets/morning.gif";
        } else if (hr >= aStart && hr < eStart) {
            chosen = Config.bar.greeter.afternoonGif || "root:/assets/afternoon.gif";
        } else if (hr >= eStart && hr < nStart) {
            chosen = Config.bar.greeter.eveningGif || "root:/assets/evening.gif";
        } else {
            chosen = Config.bar.greeter.nightGif || "root:/assets/night.gif";
        }
        return Paths.absolutePath(chosen);
    }

    Instantiator {
        id: folderScanners

        model: Config.bar.greeter.slideshowFolders || []

        delegate: FileSystemModel {
            path: Paths.absolutePath(modelData)
            nameFilters: ["*.gif", "*.webp"]
            recursive: true
        }
    }

    readonly property var allSlideshowGifs: {
        let files = [];
        const manualGifs = Config.bar.greeter.slideshowGifs || [];
        for (let i = 0; i < manualGifs.length; i++) {
            if (manualGifs[i]) files.push(Paths.absolutePath(manualGifs[i]));
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
                Paths.absolutePath(Config.bar.greeter.morningGif || "root:/assets/morning.gif"),
                Paths.absolutePath(Config.bar.greeter.afternoonGif || "root:/assets/afternoon.gif"),
                Paths.absolutePath(Config.bar.greeter.eveningGif || "root:/assets/evening.gif"),
                Paths.absolutePath(Config.bar.greeter.nightGif || "root:/assets/night.gif")
            ];
        }
        return files;
    }

    property int slideshowIndex: 0
    property string slideshowCurrentGif: allSlideshowGifs.length > 0 ? allSlideshowGifs[slideshowIndex % allSlideshowGifs.length] : ""

    onAllSlideshowGifsChanged: {
        if (slideshowIndex >= allSlideshowGifs.length) {
            slideshowIndex = 0;
        }
        if (allSlideshowGifs.length > 0) {
            slideshowCurrentGif = allSlideshowGifs[slideshowIndex];
        }
    }

    Timer {
        id: slideshowTimer

        interval: Math.max(2, Math.round(Config.bar.greeter.slideshowInterval || 60)) * 1000
        running: root.mode === "slideshow" && root.allSlideshowGifs.length > 1
        repeat: true

        onTriggered: {
            const list = root.allSlideshowGifs;
            if (list.length === 0) return;
            if (Config.bar.greeter.slideshowRandom && list.length > 1) {
                let nextIdx = Math.floor(Math.random() * list.length);
                if (nextIdx === root.slideshowIndex) nextIdx = (nextIdx + 1) % list.length;
                root.slideshowIndex = nextIdx;
            } else {
                root.slideshowIndex = (root.slideshowIndex + 1) % list.length;
            }
            root.slideshowCurrentGif = list[root.slideshowIndex];
        }
    }

    property string timeOfDayCurrentGif: getTimeOfDayGif()

    Timer {
        interval: 60000
        running: root.mode !== "slideshow"
        repeat: true
        onTriggered: root.timeOfDayCurrentGif = root.getTimeOfDayGif()
    }

    readonly property string gifPath: mode === "slideshow" ? (slideshowCurrentGif || allSlideshowGifs[0] || "") : timeOfDayCurrentGif

    readonly property int previewSize: Math.round(Tokens.sizes.bar.windowPreviewSize * scaleOffset)

    implicitWidth: child.implicitWidth
    implicitHeight: child.implicitHeight

    Column {
        id: child

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        ClippingWrapperRectangle {
            color: "transparent"
            radius: Tokens.rounding.medium
            implicitWidth: previewSize
            implicitHeight: previewSize

            AnimatedImage {
                id: preview

                cache: false
                source: root.gifPath
                fillMode: root.gifPath.includes("morning.gif") ? Image.PreserveAspectFit : Image.PreserveAspectCrop

                width: previewSize
                height: previewSize
            }
        }
    }
}
