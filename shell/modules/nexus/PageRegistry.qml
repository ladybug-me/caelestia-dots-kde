pragma Singleton

import QtQuick
import qs.utils

QtObject {
    id: root

    readonly property list<var> pages: [
        // Personalization
        {
            label: qsTr("Desktop"),
            icon: "desktop_windows",
            description: qsTr("Desktop addons, right click menu"),
            category: "personalization"
        },
        {
            label: qsTr("Appearance"),
            icon: "palette",
            description: Strings.localizeEnglishSpelling(qsTr("Wallpapers, fonts, colours")),
            category: "personalization"
        },

        // Connectivity
        {
            label: qsTr("Network"),
            icon: "wifi",
            description: qsTr("Wi-Fi, ethernet"),
            category: "connectivity"
        },
        {
            label: qsTr("Connected devices"),
            icon: "devices_other",
            description: qsTr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            label: qsTr("Audio"),
            icon: "volume_up",
            description: qsTr("App volumes, sound devices"),
            category: "connectivity"
        },

        // Controls
        {
            label: qsTr("Notifications"),
            icon: "notifications",
            description: qsTr("Toasts, alerts, notification behaviour"),
            category: "controls"
        },
        {
            label: qsTr("Utilities"),
            icon: "build",
            description: qsTr("Quick toggles, assistant, game mode"),
            category: "controls"
        },
        {
            label: qsTr("Power"),
            icon: "battery_charging_full",
            description: qsTr("Battery indicators, idle suspend"),
            category: "controls"
        },

        // Shell
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            label: qsTr("Apps"),
            icon: "apps",
            description: Strings.localizeEnglishSpelling(qsTr("Default apps, favourites, hidden apps")),
            category: "shell"
        },
        {
            label: qsTr("Services"),
            icon: "tune",
            description: qsTr("Polling, lyrics backend, service tuning"),
            category: "shell"
        },

        // System
        {
            label: qsTr("Language & region"),
            icon: "globe",
            description: qsTr("UI language, weather location, display units"),
            category: "system"
        },
        {
            label: qsTr("Updates"),
            icon: "update",
            description: qsTr("System updates"),
            category: "system"
        },
        {
            label: qsTr("Plugins"),
            icon: "extension",
            description: qsTr("Manage plugins"),
            category: "system"
        },

        // About
        {
            label: qsTr("About"),
            icon: "info",
            description: qsTr("System information, credits"),
            category: "about"
        },
    ]
}
