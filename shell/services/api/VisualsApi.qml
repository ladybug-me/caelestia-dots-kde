import "../" as Services
import QtQuick
import Caelestia as Backend

QtObject {
    readonly property var wallpaper: Services.Wallpapers
    readonly property var colors: Services.Colours
    readonly property var nightLight: Backend.NightColorBridge
    readonly property var brightness: Backend.KdeOutputDevice
}
