pragma Singleton

import QtQuick

// Import C++ backend
import Caelestia as Backend

// Import QML Services
import "../services" as Services
import "../utils" as Utils
import "../modules/launcher/services" as LauncherServices

QtObject {
    id: apiRoot

    readonly property QtObject system: QtObject {
        readonly property var session: Backend.SessionManager
        readonly property var utils: Backend.CUtils
        readonly property var cpu: Backend.Cpu
        readonly property var memory: Backend.Memory
        readonly property var gpu: Backend.Gpu
        readonly property var storage: Backend.Storage
        readonly property var sysInfo: Utils.SysInfo
        readonly property var time: Services.Time
        readonly property var update: Services.UpdateChecker
    }

    readonly property QtObject windows: QtObject {
        readonly property var kwin: Backend.KWinActiveWindowBridge
        readonly property var workspaces: Backend.KWinWorkspaceState
        readonly property var geometry: Backend.MinimizeGeometry
        readonly property var edges: Backend.ScreenEdges
    }

    readonly property QtObject network: QtObject {
        readonly property var manager: Backend.NmQt
        readonly property var requests: Backend.Requests
        readonly property var usage: Services.NetworkUsage
        readonly property var vpn: Services.VPN
    }

    readonly property QtObject media: QtObject {
        readonly property var audio: Services.Audio
        readonly property var players: Services.Players
        readonly property var lyrics: Backend.Lyrics
        readonly property var recorder: Services.Recorder
        readonly property var discord: Backend.DiscordIpc
    }

    readonly property QtObject visuals: QtObject {
        readonly property var wallpaper: Services.Wallpapers
        readonly property var colors: Services.Colours
        readonly property var nightLight: Backend.NightColorBridge
        readonly property var brightness: Backend.KdeOutputDevice
    }

    readonly property QtObject ui: QtObject {
        readonly property var toast: Backend.Toast
        readonly property var clipboard: Backend.ClipboardManager
        readonly property var emojis: Backend.EmojiDb
        readonly property var shortcuts: Backend.GlobalShortcutDispatcher
        readonly property var keyboard: Services.KbLayout
    }
}
