pragma Singleton

import QtQuick
import qs.utils

QtObject {
    id: root

    function normalizeText(v: var): string {
        return (v ?? "").toString().toLowerCase().trim();
    }

    function fuzzyScore(haystackRaw: var, needleRaw: var): real {
        const haystack = normalizeText(haystackRaw);
        const needle = normalizeText(needleRaw);

        if (!needle)
            return 0;

        if (!haystack)
            return -1;

        let score = 0;

        if (haystack === needle)
            score += 1200;

        if (haystack.startsWith(needle))
            score += 500;

        const words = haystack.split(/[^a-z0-9]+/).filter(Boolean);
        if (words.some(w => w.startsWith(needle)))
            score += 280;

        const containsAt = haystack.indexOf(needle);
        if (containsAt >= 0)
            score += 220 - Math.min(160, containsAt * 6);

        let searchFrom = 0;
        let firstMatch = -1;
        let prevMatch = -1;
        let totalGap = 0;

        for (let i = 0; i < needle.length; i++) {
            const at = haystack.indexOf(needle[i], searchFrom);
            if (at < 0)
                return -1;

            if (firstMatch < 0)
                firstMatch = at;
            if (prevMatch >= 0)
                totalGap += at - prevMatch - 1;

            prevMatch = at;
            searchFrom = at + 1;
        }

        score += Math.max(0, 240 - totalGap * 18);
        score += Math.max(0, 120 - firstMatch * 5);
        score -= Math.max(0, haystack.length - needle.length) * 1.5;

        return score;
    }

    function fuzzyPages(query: string): list<var> {
        const needle = normalizeText(query);
        const indexed = pages.map((page, pageIdx) => ({
            page,
            pageIdx
        }));

        if (!needle)
            return indexed;

        return indexed.map(e => {
            const labelScore = fuzzyScore(e.page.label, needle);
            const descScore = fuzzyScore(e.page.description, needle);
            const categoryScore = fuzzyScore(e.page.category, needle);
            const score = Math.max(labelScore, descScore * 0.7, categoryScore * 0.4);
            return {
                page: e.page,
                pageIdx: e.pageIdx,
                score
            };
        }).filter(e => e.score >= 0).sort((a, b) => b.score - a.score || a.pageIdx - b.pageIdx);
    }

    readonly property list<var> pages: [
        // Personalization
        {
            label: qsTr("Appearance"),
            icon: "palette",
            description: Strings.localizeEnglishSpelling(qsTr("Wallpapers, fonts, colours")),
            category: "personalization"
        },
        {
            label: qsTr("Desktop"),
            icon: "desktop_windows",
            description: qsTr("Enable KDE Desktop, addons, right click menu"),
            category: "personalization"
        },
        {
            label: qsTr("Panels"),
            icon: "dock_to_bottom",
            description: qsTr("Dashboard, taskbar, launcher, sidebar"),
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
        {
            label: qsTr("Language & region"),
            icon: "globe",
            description: qsTr("UI language, weather location, display units"),
            category: "shell"
        },

        // System
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
        {
            label: qsTr("About"),
            icon: "info",
            description: qsTr("System information, credits"),
            category: "system"
        },

        // AI
        {
            label: qsTr("AI Assistant"),
            icon: "smart_toy",
            description: qsTr("Claude Code, accounts, providers"),
            category: "controls"
        },
    ]
}
