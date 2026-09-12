import QtQuick
import Quickshell

// The What's New release notes.
//
// Append new entries to the end of `list` with a revision higher than every
// entry above them. Never renumber or reorder an entry that has already
// shipped: an entry's revision is how the shell records that a user has
// acknowledged it, so changing one either re-shows the entry to everybody or
// hides it from them. Pruning old entries is fine, but their revisions stay
// used up, which is why this list does not start at 1. See the authoring notes
// in ../../assets/whatsnew/README.md.
QtObject {
    // Bare media names are resolved against this directory; "root:" addresses a
    // shared shell asset, matching the convention used by GlobalConfig paths.
    readonly property string assetDir: "../../assets/whatsnew/"

    readonly property var list: [
        {
            "id": "window_switcher_addons",
            "revision": 9,
            "icon": "tab",
            "title": qsTr("Window Switcher Add-ons"),
            "description": qsTr("The window switcher now runs on a KWin-native backend, and window previews are cached so they appear instantly. Its own page under Settings -> Panels -> Window Switcher adds filtering by current desktop, minimized windows, windows from all screens, a live preview on the workspace, and a switch to turn it off entirely.")
        },
        {
            "id": "notification_monitor_fullscreen",
            "revision": 10,
            "icon": "notifications",
            "title": qsTr("Notifications on Any Screen"),
            "description": qsTr("Notification popups can now follow the screen they belong to instead of always using the focused one, and the shell can stay quiet while a fullscreen app is focused. Both live in Settings -> Services -> Notifications, as 'Display on screen' and 'Show in fullscreen'.")
        },
        {
            "id": "gif_recording",
            "revision": 11,
            "icon": "gif_box",
            "title": qsTr("GIF Recording"),
            "description": qsTr("The screen recorder can capture a region straight to an animated GIF. Choose Record GIF from the recorder menu - it is enabled by default and can be switched off under Settings -> Utilities -> Utilities panel.")
        },
        {
            "id": "sddm_theme_default",
            "revision": 12,
            "icon": "login",
            "title": qsTr("SDDM Theme Out of the Box"),
            "description": qsTr("The Material You login screen, with wallpaper and color sync, is now installed by default, so the greeter matches your desktop from the first boot. It remains optional in the installer for anyone who prefers the stock theme.")
        },
        {
            "id": "audio_reactive_desktop_shapes",
            "revision": 13,
            "icon": "graphic_eq",
            "title": qsTr("Audio-Reactive Desktop Shapes"),
            "description": qsTr("The media visualiser is now a set of audio-reactive material shapes, and it can live on the wallpaper as well as in the dashboard. Turn on 'Desktop media shapes' under Settings -> Desktop -> Desktop Addons and let it auto-hide while a window is open.")
        },
        {
            "id": "chinese_translations",
            "revision": 14,
            "icon": "translate",
            "title": qsTr("Chinese Translations"),
            "description": qsTr("The shell now ships Simplified and Traditional Chinese catalogues, so the interface follows your language instead of staying English. Pick one from Settings -> Language & region.")
        },
        {
            "id": "caelestia_kde_identity",
            "revision": 15,
            "icon": "auto_awesome",
            "title": qsTr("A New Name and Look"),
            "description": qsTr("The project is now caelestia-kde. The repository, its references and the artwork have been renamed and brought onto one palette and one logo. Your configuration and settings are untouched.")
        }
    ]

    function mediaSource(entry: var): url {
        if (!entry || !entry.mediaUrl)
            return "";
        if (entry.mediaUrl.startsWith("root:"))
            return Qt.resolvedUrl(`${Quickshell.shellDir}${entry.mediaUrl.slice("root:".length)}`);
        return Qt.resolvedUrl(`${assetDir}${entry.mediaUrl}`);
    }
}
