pragma Singleton

import QtQuick
import qs.utils

QtObject {
    readonly property list<var> pages: [
        // Personalization
        {
            label: qsTr("Appearance"),
            icon: "palette",
            description: Strings.localizeEnglishSpelling(qsTr("Wallpapers, fonts, colours")),
            category: "personalization",
            settings: [
                { label: qsTr("Theme & Effects"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 },
                { label: qsTr("Accent Colors"), pagePath: "wallandstyle/ColourSelect.qml", subPageIdx: 3 },
                { label: qsTr("Blur & Opacity"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 },
                { label: qsTr("Corner Radius"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 },
                { label: qsTr("Wallpapers"), pagePath: "wallandstyle/WallpaperSelect.qml", subPageIdx: 1 },
                { label: qsTr("Animations"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 }
            ]
        },
        {
            label: qsTr("Desktop & Tiling"),
            icon: "desktop_windows",
            description: qsTr("KDE Desktop, addons, right click menu"),
            category: "personalization",
            settings: [
                { label: qsTr("KDE Desktop Integration"), keywords: ["plasma", "icons", "desktop"] },
                { label: qsTr("Right Click Menu"), pagePath: "wallandstyle/ContextMenuPage.qml", subPageIdx: 2 },
                { label: qsTr("Desktop Addons"), pagePath: "wallandstyle/DesktopAddonsPage.qml", subPageIdx: 1 },
                { label: qsTr("Window Tiling"), pagePath: "desktop/KrohnkitePage.qml", keywords: ["krohnkite", "tiling", "layouts"], subPageIdx: 3 },
                { label: qsTr("Virtual Workspaces"), keywords: ["desktops", "virtual", "switcher"] }
            ]
        },
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
            category: "personalization",
            settings: [
                { label: qsTr("Taskbar"), pagePath: "panels/TaskbarPanel.qml", subPageIdx: 2 },
                { label: qsTr("Dashboard"), pagePath: "panels/DashboardPanel.qml", subPageIdx: 1 },
                { label: qsTr("Launcher"), pagePath: "panels/LauncherPanel.qml", subPageIdx: 3 },
                { label: qsTr("Sidebar"), pagePath: "panels/SidebarPanel.qml", subPageIdx: 4 },
                { label: qsTr("Quick Toggles Panel"), pagePath: "panels/UtilitiesPanel.qml", subPageIdx: 5 },
                { label: qsTr("Overview"), pagePath: "panels/OverviewPanel.qml", keywords: ["overview", "animations", "blur"], subPageIdx: 16 }
            ]
        },
        // Connectivity
        {
            label: qsTr("Network"),
            icon: "wifi",
            description: qsTr("Wi-Fi, ethernet, proxy, VPNs"),
            category: "connectivity",
            settings: [
                { label: qsTr("Wi-Fi"), keywords: ["wireless", "internet", "connections"] },
                { label: qsTr("Ethernet"), keywords: ["wired", "lan", "internet"] },
                { label: qsTr("Proxy"), keywords: ["proxy", "network"] },
                { label: qsTr("VPN"), keywords: ["vpn", "tunnel", "secure"] }
            ]
        },
        {
            label: qsTr("Connected devices"),
            icon: "bluetooth",
            description: qsTr("Bluetooth, pairing, drivers"),
            category: "connectivity",
            settings: [
                { label: qsTr("Bluetooth"), keywords: ["wireless", "devices", "accessories"] },
                { label: qsTr("Pairing"), pagePath: "bluetooth/BluetoothPairing.qml", subPageIdx: 2 }
            ]
        },
        {
            label: qsTr("Audio & Sound"),
            icon: "volume_up",
            description: qsTr("Speakers, mics, mixing, EQ"),
            category: "connectivity",
            settings: [
                { label: qsTr("Speakers & Output"), keywords: ["volume", "playback", "sink"] },
                { label: qsTr("Microphones"), keywords: ["input", "recording", "source"] },
                { label: qsTr("App Volumes"), pagePath: "audio/AppVolumes.qml", subPageIdx: 1 }
            ]
        },
        // Controls
        {
            label: qsTr("Notifications"),
            icon: "notifications",
            description: qsTr("Toasts, alerts, notification behaviour"),
            category: "controls",
            settings: [
                { label: qsTr("Do Not Disturb"), keywords: ["dnd", "silent", "quiet"] },
                { label: qsTr("Popup Banners"), pagePath: "services/NotificationsPage.qml", keywords: ["toasts", "alerts", "popups"] },
                { label: qsTr("Notification History"), keywords: ["log", "past", "sidebar"] }
            ]
        },
        {
            label: qsTr("Utilities"),
            icon: "build",
            description: qsTr("Quick toggles, assistant, game mode"),
            category: "controls",
            settings: [
                { label: qsTr("Quick Settings"), keywords: ["toggles", "dashboard", "switches"] },
                { label: qsTr("Game Mode"), pagePath: "services/GameModePage.qml", subPageIdx: 1 },
                { label: qsTr("Screenshot & Record"), keywords: ["capture", "screen", "video"] }
            ]
        },
        {
            label: qsTr("Power"),
            icon: "battery_charging_full",
            description: qsTr("Battery indicators, idle suspend"),
            category: "controls",
            settings: [
                { label: qsTr("Battery Status"), keywords: ["percentage", "charging", "health"] },
                { label: qsTr("Power Saving"), keywords: ["suspend", "sleep", "idle"] },
                { label: qsTr("Screen Timeout"), keywords: ["dim", "turn off screen"] }
            ]
        },
        {
            label: qsTr("Shortcuts"),
            icon: "keyboard",
            description: qsTr("Keyboard shortcuts, custom keybinds"),
            category: "controls",
            settings: [
                { label: qsTr("System Shortcuts"), keywords: ["global", "keys", "hotkeys"] },
                { label: qsTr("App Shortcuts"), keywords: ["launch", "open", "binding"] },
                { label: qsTr("Custom Keybinds"), pagePath: "wallandstyle/AddShortcutDialog.qml", keywords: ["scripts", "commands", "actions"] }
            ]
        },
        // Shell
        {
            label: qsTr("Apps"),
            icon: "apps",
            description: qsTr("Default apps, file types, app details"),
            category: "shell",
            settings: [
                { label: qsTr("Default Apps"), keywords: ["browser", "email", "default"] },
                { label: qsTr("File Types"), keywords: ["associations", "extensions", "open with"] },
                { label: qsTr("All Apps"), keywords: ["installed", "list", "uninstall"], subPageIdx: 1 },
                { label: qsTr("Favorites & Hidden"), keywords: ["pinned", "dock", "launcher", "ignore"], subPageIdx: 1 }
            ]
        },
        {
            label: qsTr("Services"),
            icon: "settings_suggest",
            description: qsTr("Background services, daemon control"),
            category: "shell",
            settings: [
                { label: qsTr("Background Services"), keywords: ["daemons", "systemd", "tuning"], subPageIdx: 1 },
                { label: qsTr("Rich Presence"), pagePath: "services/ArpcPage.qml", subPageIdx: 1 }
            ]
        },
        {
            label: qsTr("Language & region"),
            icon: "language",
            description: qsTr("Locale, timezone, formats"),
            category: "shell",
            settings: [
                { label: qsTr("Language"), keywords: ["locale", "translation", "ui"] },
                { label: qsTr("Time & Date"), keywords: ["clock", "timezone", "format"] },
                { label: qsTr("Weather Location"), keywords: ["city", "forecast", "units", "celsius", "fahrenheit"] }
            ]
        },
        // System
        {
            label: qsTr("Updates"),
            icon: "update",
            description: qsTr("System updates"),
            category: "system",
            settings: [
                { label: qsTr("Software Updates"), keywords: ["upgrade", "packages", "pacman"] },
                { label: qsTr("Firmware Updates"), keywords: ["bios", "fwupd", "hardware"] }
            ]
        },
        {
            label: qsTr("Plugins"),
            icon: "extension",
            description: qsTr("Manage quickshell plugins"),
            category: "system",
            settings: [
                { label: qsTr("Installed Plugins"), keywords: ["extensions", "addons", "manage"] },
                { label: qsTr("Plugin Store"), keywords: ["download", "browse", "community"] }
            ]
        },
        {
            label: qsTr("About System"),
            icon: "info",
            description: qsTr("Specs, version, system information"),
            category: "system",
            settings: [
                { label: qsTr("Device Info"), keywords: ["hardware", "specs", "cpu", "ram"] },
                { label: qsTr("OS Version"), keywords: ["caelestia", "quickshell", "release"] }
            ]
        },
        // AI
        // Last, to stay aligned with PageCompRegistry.pageComps — this list is
        // indexed by position, so entries cannot be reordered independently.
        {
            label: qsTr("AI Assistant"),
            icon: "smart_toy",
            description: qsTr("Claude Code, accounts, providers"),
            category: "controls",
            settings: [
                { label: qsTr("Claude Code"), keywords: ["claude", "cli", "subscription", "login"] },
                { label: qsTr("Accounts"), keywords: ["claude", "account", "login", "switch"] },
                { label: qsTr("Providers"), keywords: ["ollama", "openai", "chatgpt", "gemini", "openrouter", "api key"] }
            ]
        }
    ]
}
