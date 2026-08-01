pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root
    
    // Base duration for the entire overview opening/closing sequence (in ms)
    property int baseDuration: 700
    
    // speeds relative to the base duration
    property real blobScaleSpeed: 1.0
    property real wallpaperFadeSpeed: 1.0
    property real gridFadeSpeed: 1.0

    readonly property int blobDuration: Math.round(baseDuration / blobScaleSpeed)
    readonly property int wallpaperDuration: Math.round(baseDuration / wallpaperFadeSpeed)
    readonly property int gridDuration: Math.round(baseDuration / gridFadeSpeed)
}
