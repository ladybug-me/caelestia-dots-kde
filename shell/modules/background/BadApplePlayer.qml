pragma Singleton

import QtQuick
import QtMultimedia

Item {
    property bool shouldPlay: false
    property var firstInstance: null

    signal toggleRequested

    function play(): void {
        shouldPlay = true;
        toggleRequested();
    }

    function stop(): void {
        shouldPlay = false;
        toggleRequested();
    }

    function toggle(): void {
        shouldPlay = !shouldPlay;
        toggleRequested();
    }
}
