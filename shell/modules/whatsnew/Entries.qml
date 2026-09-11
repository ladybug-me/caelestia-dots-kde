import QtQuick
import Quickshell

// The What's New release notes.
//
// Append new entries to the end of `list` with a revision higher than every
// entry above them. Never renumber or reorder an entry that has already
// shipped: an entry's revision is how the shell records that a user has
// acknowledged it, so changing one either re-shows the entry to everybody or
// hides it from them. See the authoring notes in ../../assets/whatsnew/README.md.
QtObject {
    // Bare media names are resolved against this directory; "root:" addresses a
    // shared shell asset, matching the convention used by GlobalConfig paths.
    readonly property string assetDir: "../../assets/whatsnew/"

    readonly property var list: [
        {
            "id": "welcome_intro",
            "revision": 1,
            "icon": "celebration",
            "title": qsTr("Welcome to Caelestia Updates"),
            "description": qsTr("Whenever we introduce exciting new features, they will appear here so you never miss out. Enjoy the refined aesthetic and improved functionality!"),
            "mediaUrl": "root:/assets/kurukuru.gif"
        },
        {
            "id": "update_indicator",
            "revision": 2,
            "icon": "system_update",
            "title": qsTr("Taskbar Update Indicator"),
            "description": qsTr("Caelestia can now be updated from the system tray. Hover to show available options, left click to open the Update page and right click to check for updates. Can be enabled from Settings -> Panels -> Taskbar -> Toggle & rearrange -> Updates."),
            "mediaUrl": "update_indicator_9b5fa56.png"
        },
        {
            "id": "permanent_shell",
            "revision": 3,
            "icon": "keyboard_return",
            "title": qsTr("Integrated more than ever"),
            "description": qsTr("1. Alt+F4 no longer closes the shell. 2. Whenever you open and close any drawer, it will seamlessly return focus to the window you were previously using! 3. KWin native protocols are used to interact with windows, creating a much faster experience!")
        },
        {
            "id": "text_recognition",
            "revision": 4,
            "icon": "text_fields",
            "title": qsTr("Text Recognition (OCR)"),
            "description": qsTr("Extract text from any image or region on your screen instantly. Use the new Meta+Shift+D shortcut to select an area, and the recognized text will be automatically copied to your clipboard."),
            "mediaUrl": "text_recognition_512.png"
        },
        {
            "id": "window_region_selector",
            "revision": 5,
            "icon": "desktop_windows",
            "title": qsTr("Window Region Selector"),
            "description": qsTr("Capture specific application windows effortlessly. Toggle 'Window Selector' mode in the screenshot toolbar to automatically crop individual windows for screenshots / Google Search / text recognition. Hover over windows to preview them, then click to capture cleanly without manual cropping."),
            "mediaUrl": "window_region_selector_516.mp4"
        },
        {
            "id": "plugin_system",
            "revision": 6,
            "icon": "extension",
            "title": qsTr("Plugin System"),
            "description": qsTr("Caelestia now supports a plugin ecosystem for expanding the shell without touching core files. Browse community plugins, install them directly, and manage everything from the built-in plugin system to personalize your desktop experience."),
            "mediaUrl": "plugin_system_546.png"
        },
        {
            "id": "lockscreen_greeter",
            "revision": 7,
            "icon": "lock",
            "title": qsTr("Lockscreen Greeter"),
            "description": qsTr("The Caelestia lock screen brings the modern Quickshell lockscreen design into native KDE Plasma 6"),
            "mediaUrl": "lockscreen_greeter_600.png"
        },
        {
            "id": "greeter_addons",
            "revision": 8,
            "icon": "face",
            "title": qsTr("Greeter Add-ons"),
            "description": qsTr("Add more fun elements to the greeter, such as a Slideshow mode, you can also change the media files and text, right click on the greeter widget to explore all the options!"),
            "mediaUrl": "greeter_addons_682.png"
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
