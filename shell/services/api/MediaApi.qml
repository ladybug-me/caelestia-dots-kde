import QtQuick
import Caelestia as Backend
import "../" as Services

QtObject {
    readonly property var audio: Services.Audio
    readonly property var players: Services.Players
    readonly property var lyrics: Backend.Lyrics
    readonly property var recorder: Services.Recorder
    readonly property var discord: Backend.DiscordIpc
}
