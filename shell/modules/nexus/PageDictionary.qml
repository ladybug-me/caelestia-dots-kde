pragma Singleton

import QtQuick
import qs.utils
import qs.services

QtObject {
    readonly property list<var> pages: [
        // Personalization
        {
            label: I18n.tr("Appearance"),
            icon: "palette",
            description: Strings.localizeEnglishSpelling(I18n.tr("Wallpapers, fonts, colours")),
            category: "personalization",
            settings: [
                { label: I18n.tr("Theme & Effects"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 },
                { label: I18n.tr("Accent Colors"), pagePath: "wallandstyle/ColourSelect.qml", subPageIdx: 3 },
                { label: I18n.tr("Blur & Opacity"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 },
                { label: I18n.tr("Corner Radius"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 },
                { label: I18n.tr("Wallpapers"), pagePath: "wallandstyle/WallpaperSelect.qml", subPageIdx: 1 },
                { label: I18n.tr("Animations"), pagePath: "wallandstyle/AppearancePage.qml", subPageIdx: 8 }
            ]
        },
        {
            label: I18n.tr("Desktop & Tiling"),
            icon: "desktop_windows",
            description: I18n.tr("KDE Desktop, addons, right click menu"),
            category: "personalization",
            settings: [
                { label: I18n.tr("KDE Desktop Integration"), keywords: ["plasma", "icons", "desktop"] },
                { label: I18n.tr("Right Click Menu"), pagePath: "wallandstyle/ContextMenuPage.qml", subPageIdx: 2 },
                { label: I18n.tr("Desktop Addons"), pagePath: "wallandstyle/DesktopAddonsPage.qml", subPageIdx: 1 },
                { label: I18n.tr("Window Tiling"), pagePath: "desktop/KrohnkitePage.qml", keywords: ["krohnkite", "tiling", "layouts"], subPageIdx: 3 },
                { label: I18n.tr("Virtual Workspaces"), keywords: ["desktops", "virtual", "switcher"] }
            ]
        },
        {
            label: I18n.tr("Panels"),
            icon: "dock_to_bottom",
            description: I18n.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "personalization",
            settings: [
                { label: I18n.tr("Taskbar"), pagePath: "panels/TaskbarPanel.qml", subPageIdx: 2 },
                { label: I18n.tr("Dashboard"), pagePath: "panels/DashboardPanel.qml", subPageIdx: 1 },
                { label: I18n.tr("Launcher"), pagePath: "panels/LauncherPanel.qml", subPageIdx: 3 },
                { label: I18n.tr("Sidebar"), pagePath: "panels/SidebarPanel.qml", subPageIdx: 4 },
                { label: I18n.tr("Quick Toggles Panel"), pagePath: "panels/UtilitiesPanel.qml", subPageIdx: 5 },
                { label: I18n.tr("Overview"), pagePath: "panels/OverviewPanel.qml", keywords: ["overview", "animations", "blur"], subPageIdx: 16 }
            ]
        },
        // Connectivity
        {
            label: I18n.tr("Network"),
            icon: "wifi",
            description: I18n.tr("Wi-Fi and VPN connections"),
            category: "connectivity",
            settings: [
                { label: I18n.tr("Wi-Fi"), keywords: ["wireless", "internet", "connections"] },
                { label: I18n.tr("VPN"), keywords: ["vpn", "tunnel", "secure"] }
            ]
        },
        {
            label: I18n.tr("Connected devices"),
            icon: "bluetooth",
            description: I18n.tr("Bluetooth, pairing, drivers"),
            category: "connectivity",
            settings: [
                { label: I18n.tr("Bluetooth"), keywords: ["wireless", "devices", "accessories"] },
                { label: I18n.tr("Pairing"), pagePath: "bluetooth/BluetoothPairing.qml", subPageIdx: 2 }
            ]
        },
        {
            label: I18n.tr("Audio & Sound"),
            icon: "volume_up",
            description: I18n.tr("Output, input, app volume, sound effects"),
            category: "connectivity",
            settings: [
                { label: I18n.tr("Speakers & Output"), keywords: ["volume", "playback", "sink"] },
                { label: I18n.tr("Microphones"), keywords: ["input", "recording", "source"] },
                { label: I18n.tr("App Volumes"), pagePath: "audio/AppVolumes.qml", subPageIdx: 1 },
                { label: I18n.tr("Sound Effects"), pagePath: "audio/SoundEffectsPage.qml", subPageIdx: 2, keywords: ["sfx", "feedback", "camera", "screen lock"] },
                { label: I18n.tr("Muted Notification Apps"), pagePath: "audio/NotificationSilencingPage.qml", subPageIdx: 3, keywords: ["silence", "mute", "notification sound"] }
            ]
        },
        // Controls
        {
            label: I18n.tr("Notifications"),
            icon: "notifications",
            description: I18n.tr("Alerts, toasts, and delivery behavior"),
            category: "controls",
            settings: [
                { label: I18n.tr("Notification behavior"), pagePath: "services/NotificationPreferencesPage.qml", subPageIdx: 1, keywords: ["fullscreen", "position", "timeout", "taskbar"] },
                { label: I18n.tr("Toasts"), pagePath: "services/ToastPreferencesPage.qml", subPageIdx: 2, keywords: ["popup", "banner", "sound", "volume"] },
                { label: I18n.tr("Toast events"), pagePath: "services/ToastEventsPage.qml", subPageIdx: 3, keywords: ["charging", "clipboard", "vpn", "keyboard", "audio"] }
            ]
        },
        {
            label: I18n.tr("Utilities"),
            icon: "build",
            description: I18n.tr("Quick controls, clipboard, game mode"),
            category: "controls",
            settings: [
                { label: I18n.tr("On-screen Sliders"), subPageIdx: 3, keywords: ["volume", "microphone", "brightness", "osd"] },
                { label: I18n.tr("Clipboard"), subPageIdx: 4, keywords: ["history", "copied", "paste"] },
                { label: I18n.tr("Utilities Panel"), subPageIdx: 5, keywords: ["keep awake", "screenshot", "record"] },
                { label: I18n.tr("Quick Toggles"), subPageIdx: 6, keywords: ["toggles", "dashboard", "switches"] },
                { label: I18n.tr("Game Mode"), pagePath: "services/GameModePage.qml", subPageIdx: 1 }
            ]
        },
        {
            label: I18n.tr("Power"),
            icon: "battery_charging_full",
            description: I18n.tr("Battery indicators, idle suspend"),
            category: "controls",
            settings: [
                { label: I18n.tr("Battery Status"), keywords: ["percentage", "charging", "health"] },
                { label: I18n.tr("Power Saving"), keywords: ["suspend", "sleep", "idle"] },
                { label: I18n.tr("Screen Timeout"), keywords: ["dim", "turn off screen"] }
            ]
        },
        {
            label: I18n.tr("Shortcuts"),
            icon: "keyboard",
            description: I18n.tr("Keyboard shortcuts, custom keybinds"),
            category: "controls",
            settings: [
                { label: I18n.tr("System Shortcuts"), keywords: ["global", "keys", "hotkeys"] },
                { label: I18n.tr("App Shortcuts"), keywords: ["launch", "open", "binding"] },
                { label: I18n.tr("Custom Keybinds"), pagePath: "wallandstyle/AddShortcutDialog.qml", keywords: ["scripts", "commands", "actions"] }
            ]
        },
        // Shell
        {
            label: I18n.tr("Apps"),
            icon: "apps",
            description: I18n.tr("Default apps, file types, app details"),
            category: "shell",
            settings: [
                { label: I18n.tr("Default Apps"), keywords: ["browser", "email", "default"] },
                { label: I18n.tr("File Types"), keywords: ["associations", "extensions", "open with"] },
                { label: I18n.tr("All Apps"), keywords: ["installed", "list", "uninstall"], subPageIdx: 1 },
                { label: I18n.tr("Favorites & Hidden"), keywords: ["pinned", "dock", "launcher", "ignore"], subPageIdx: 1 }
            ]
        },
        {
            label: I18n.tr("Services"),
            icon: "settings_suggest",
            description: I18n.tr("Background services, daemon control"),
            category: "shell",
            settings: [
                { label: I18n.tr("Background Services"), keywords: ["daemons", "systemd", "tuning"], subPageIdx: 1 },
                { label: I18n.tr("Rich Presence"), pagePath: "services/ArpcPage.qml", subPageIdx: 1 }
            ]
        },
        {
            label: I18n.tr("Language & region"),
            icon: "language",
            description: I18n.tr("Locale, timezone, formats"),
            category: "shell",
            settings: [
                { label: I18n.tr("Language"), keywords: ["locale", "translation", "ui"] },
                { label: I18n.tr("Time & Date"), keywords: ["clock", "timezone", "format"] },
                { label: I18n.tr("Weather Location"), keywords: ["city", "forecast", "units", "celsius", "fahrenheit"] }
            ]
        },
        // System
        {
            label: I18n.tr("Updates"),
            icon: "update",
            description: I18n.tr("System updates"),
            category: "system",
            settings: [
                { label: I18n.tr("Software Updates"), keywords: ["upgrade", "packages", "pacman", "dnf", "apt"] },
                { label: I18n.tr("Firmware Updates"), keywords: ["bios", "fwupd", "hardware"] }
            ]
        },
        {
            label: I18n.tr("Plugins"),
            icon: "extension",
            description: I18n.tr("Plugin support is not available yet"),
            category: "system",
            settings: [
                { label: I18n.tr("Plugin support"), description: I18n.tr("Not available yet"), keywords: ["extensions", "addons", "plugins"] }
            ]
        },
        {
            label: I18n.tr("About System"),
            icon: "info",
            description: I18n.tr("Specs, version, system information"),
            category: "system",
            settings: [
                { label: I18n.tr("Device Info"), keywords: ["hardware", "specs", "cpu", "ram"] },
                { label: I18n.tr("OS Version"), keywords: ["caelestia", "quickshell", "release"] }
            ]
        },
        // AI
        // Last, to stay aligned with PageCompRegistry.pageComps — this list is
        // indexed by position, so entries cannot be reordered independently.
        {
            label: I18n.tr("AI Assistant"),
            icon: "smart_toy",
            description: I18n.tr("Claude Code, accounts, providers"),
            category: "assistant",
            settings: [
                { label: I18n.tr("Claude Code"), keywords: ["claude", "cli", "subscription", "login"] },
                { label: I18n.tr("Accounts"), keywords: ["claude", "account", "login", "switch"] },
                { label: I18n.tr("Providers"), keywords: ["ollama", "openai", "chatgpt", "gemini", "openrouter", "api key"] }
            ]
        }
    ]
}
