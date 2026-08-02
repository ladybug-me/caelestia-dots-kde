pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config

QtObject {
    id: root
    // Base duration for the entire overview opening/closing sequence (in ms)

    property int baseDuration: GlobalConfig.overview.baseDuration
    // speeds relative to the base duration
    property real blobScaleSpeed: GlobalConfig.overview.blobScaleSpeed
    property real wallpaperFadeSpeed: GlobalConfig.overview.wallpaperFadeSpeed
    property real gridFadeSpeed: GlobalConfig.overview.gridFadeSpeed
    // animation type
    property int easingType: GlobalConfig.overview.easingType
    readonly property int blobDuration: Math.round(baseDuration / blobScaleSpeed)
    readonly property int wallpaperDuration: Math.round(baseDuration / wallpaperFadeSpeed)
    readonly property int gridDuration: Math.round(baseDuration / gridFadeSpeed)
}
