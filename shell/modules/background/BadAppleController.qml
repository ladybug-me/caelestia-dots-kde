pragma Singleton

import QtQuick
import QtMultimedia

QtObject {
    readonly property bool playing: video.playing

    property var video: null

    function play(): void {
        video.play();
    }

    function stop(): void {
        video.stop();
    }
}
