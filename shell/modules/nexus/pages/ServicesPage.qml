import "../../../utils/scripts/solartime.js" as Solar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> autoSchemeItems: [
        MenuItem {
            text: I18n.tr("Sunrise and sunset")
        },
        MenuItem {
            text: I18n.tr("Fixed times")
        }
    ]
    readonly property list<string> autoSchemeValues: ["solar", "fixed"]

    /// The hour of an "HH:MM" config value, for the steppers.
    function schemeHour(time: string): int {
        const minutes = Solar.parseTime(time);
        return minutes < 0 ? 0 : Math.floor(minutes / 60);
    }

    /// Replaces only the hour, so minutes set by hand in the config file are
    /// not thrown away by touching the stepper.
    function withHour(time: string, hour: int): string {
        const minutes = Solar.parseTime(time);
        const mins = minutes < 0 ? 0 : minutes % 60;
        return `${String(hour).padStart(2, "0")}:${String(mins).padStart(2, "0")}`;
    }

    // Lyrics backends, ordered to match LyricsBackend::Backend (Auto, Local, LRCLIB, NetEase)
    readonly property list<MenuItem> lyricsItems: [
        MenuItem {
            text: I18n.tr("Auto")
        },
        MenuItem {
            text: "Local"
        },
        MenuItem {
            text: "LRCLIB"
        },
        MenuItem {
            text: "NetEase"
        }
    ]

    // GPU options + the config string each maps to (see Gpu::parseType)
    readonly property list<MenuItem> gpuItems: [
        MenuItem {
            text: I18n.tr("Auto")
        },
        MenuItem {
            text: "NVIDIA"
        },
        MenuItem {
            text: I18n.tr("Generic")
        },
        MenuItem {
            text: I18n.tr("None")
        }
    ]

    readonly property list<string> gpuValues: ["", "NVIDIA", "GENERIC", "None"]

    function gpuKeyToIndex(key: string): int {
        const u = (key ?? "").trim().toUpperCase();
        if (u === "")
            return 0; // Auto
        if (u === "NVIDIA")
            return 1;
        if (u === "GENERIC")
            return 2;
        return 3; // None
    }

    title: I18n.tr("Services")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Detected running players, used as default-player options
        Variants {
            id: playerVariants

            model: [...new Set(Players.list.map(p => Players.getIdentity(p)).filter(id => id))]

            MenuItem {
                required property string modelData

                text: modelData
                icon: modelData === GlobalConfig.services.defaultPlayer ? "check" : ""
                activeIcon: "music_note"
            }
        }

        // Polling
        SectionHeader {
            first: true
            text: I18n.tr("Polling")
        }

        StepperRow {
            first: true
            label: I18n.tr("Media refresh")
            subtext: I18n.tr("How often the media position updates (ms)")
            value: GlobalConfig.dashboard.mediaUpdateInterval
            from: 100
            to: 2000
            stepSize: 50
            onMoved: v => GlobalConfig.dashboard.mediaUpdateInterval = v
        }

        StepperRow {
            label: I18n.tr("System stats refresh")
            subtext: I18n.tr("CPU, memory and GPU update interval (seconds)")
            value: GlobalConfig.dashboard.resourceUpdateInterval / 1000
            from: 0.5
            to: 10
            stepSize: 0.5
            onMoved: v => GlobalConfig.dashboard.resourceUpdateInterval = Math.round(v * 1000)
        }

        StepperRow {
            last: true
            label: I18n.tr("Wi-Fi rescan")
            subtext: I18n.tr("How often available networks are rescanned (seconds)")
            value: GlobalConfig.nexus.networkRescanInterval / 1000
            from: 5
            to: 120
            stepSize: 5
            onMoved: v => GlobalConfig.nexus.networkRescanInterval = Math.round(v * 1000)
        }

        // Media & lyrics
        SectionHeader {
            text: I18n.tr("Media & lyrics")
        }

        SelectRow {
            first: true
            label: I18n.tr("Lyrics backend")
            subtext: I18n.tr("Source used to fetch synced lyrics")
            menuItems: root.lyricsItems
            active: root.lyricsItems[Lyrics.preferredBackend] ?? root.lyricsItems[0]
            onSelected: item => Lyrics.preferredBackend = root.lyricsItems.indexOf(item)
        }

        SelectRow {
            last: true
            label: I18n.tr("Default player")
            subtext: I18n.tr("Preferred media player when several are open")
            menuItems: playerVariants.instances
            active: menuItems.find(i => i.text === GlobalConfig.services.defaultPlayer) ?? null
            fallbackIcon: "music_note"
            fallbackText: GlobalConfig.services.defaultPlayer || I18n.tr("Auto")
            onSelected: item => GlobalConfig.services.defaultPlayer = item.text
        }

        // Input increments
        SectionHeader {
            text: I18n.tr("Input increments")
        }

        StepperRow {
            first: true
            label: I18n.tr("Volume step")
            subtext: I18n.tr("Amount the volume changes per scroll (%)")
            value: Math.round(GlobalConfig.services.audioIncrement * 100)
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.services.audioIncrement = v / 100
        }

        StepperRow {
            label: I18n.tr("Brightness step")
            subtext: I18n.tr("Amount the brightness changes per scroll (%)")
            value: Math.round(GlobalConfig.services.brightnessIncrement * 100)
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.services.brightnessIncrement = v / 100
        }

        StepperRow {
            last: true
            label: I18n.tr("Max volume")
            subtext: I18n.tr("Upper limit for output volume (%)")
            value: Math.round(GlobalConfig.services.maxVolume * 100)
            from: 50
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.services.maxVolume = v / 100
        }

        // Service tuning
        SectionHeader {
            text: I18n.tr("Service tuning")
        }

        NavRow {
            first: true
            icon: "chat" // Using chat since discord icon might not be available in Material icons
            label: I18n.tr("Discord Rich Presence")
            status: I18n.tr("Broadcast your status to Vesktop")
            onClicked: root.nState.openSubPage(1)
        }

        StepperRow {
            label: I18n.tr("Visualiser bars")
            subtext: I18n.tr("Number of bars in the audio visualisers")
            value: GlobalConfig.services.visualiserBars
            from: 10
            to: 120
            stepSize: 2
            onMoved: v => GlobalConfig.services.visualiserBars = v
        }

        ToggleRow {
            text: Strings.localizeEnglishSpelling(I18n.tr("Smart colour scheme"))
            subtext: I18n.tr("Derive theme mode and variant from the wallpaper")
            checked: GlobalConfig.services.smartScheme
            onToggled: GlobalConfig.services.smartScheme = checked
        }

        ToggleRow {
            text: I18n.tr("Automatic light and dark")
            subtext: I18n.tr("Switch the theme mode on a schedule")
            checked: GlobalConfig.services.autoSchemeEnabled
            onToggled: GlobalConfig.services.autoSchemeEnabled = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: I18n.tr("Schedule")
            subtext: AutoScheme.coords ? I18n.tr("Sunrise and sunset use your weather location") : I18n.tr("Set a weather location to use sunrise and sunset")
            menuItems: root.autoSchemeItems
            active: root.autoSchemeItems[Math.max(0, root.autoSchemeValues.indexOf(GlobalConfig.services.autoSchemeMode))]
            onSelected: item => GlobalConfig.services.autoSchemeMode = root.autoSchemeValues[root.autoSchemeItems.indexOf(item)]
        }

        StepperRow {
            label: I18n.tr("Light mode hour")
            subtext: I18n.tr("Switches at %1").arg(GlobalConfig.services.autoSchemeLightTime)
            value: root.schemeHour(GlobalConfig.services.autoSchemeLightTime)
            from: 0
            to: 23
            onMoved: h => GlobalConfig.services.autoSchemeLightTime = root.withHour(GlobalConfig.services.autoSchemeLightTime, h)
        }

        StepperRow {
            label: I18n.tr("Dark mode hour")
            subtext: I18n.tr("Switches at %1, also used when sunrise and sunset are unavailable").arg(GlobalConfig.services.autoSchemeDarkTime)
            value: root.schemeHour(GlobalConfig.services.autoSchemeDarkTime)
            from: 0
            to: 23
            onMoved: h => GlobalConfig.services.autoSchemeDarkTime = root.withHour(GlobalConfig.services.autoSchemeDarkTime, h)
        }

        SelectRow {
            Layout.fillWidth: true
            last: true
            label: I18n.tr("GPU")
            subtext: Gpu.name ? I18n.tr("Monitoring: %1").arg(Gpu.name) : I18n.tr("Override for GPU type")
            menuOnTop: true
            menuItems: root.gpuItems
            active: root.gpuItems[root.gpuKeyToIndex(GlobalConfig.services.gpuType)]
            onSelected: item => GlobalConfig.services.gpuType = root.gpuValues[root.gpuItems.indexOf(item)]
        }
    }
}
