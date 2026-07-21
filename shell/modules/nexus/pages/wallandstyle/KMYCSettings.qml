pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root
    
    title: "Advanced Colors"
    isSubPage: true

    property bool pywal: false
    property bool pywalLight: false
    property real lightBlendMultiplier: 0.85
    property real darkBlendMultiplier: 0.5
    property bool sierraBreezeButtonsColor: false
    property bool disableKonsole: false
    property int konsoleOpacity: 20
    property int konsoleOpacityDark: 20
    property bool konsoleBlur: true
    property bool titlebarOpacityOverride: false
    property int titlebarOpacity: 100
    property int titlebarOpacityDark: 100
    property int toolbarOpacity: 100
    property int toolbarOpacityDark: 100
    property bool klassyWindecoOutline: false
    property bool useStartupDelay: false
    property int startupDelay: 5
    property int mainLoopDelay: 1
    property int screenshotDelay: 2
    property bool onceAfterChange: false
    property bool pauseMode: false
    property real chromaMultiplier: 1.0
    property real toneMultiplier: 1.0
    property real frameContrast: 0.2
    property real contrastLevel: 0.0
    property bool manualFetch: false
    property int specVersion: 2025
    property bool kdeRoundedCornersEffectOutline: false

    function parseConfig(text: string): void {
        const lines = text.split('\n');
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.startsWith('#') || line === '' || line.startsWith('[')) continue;
            
            const parts = line.split('=');
            if (parts.length >= 2) {
                const key = parts[0].trim();
                const value = parts.slice(1).join('=').trim();
                const bVal = value.toLowerCase() === "true";
                const fVal = parseFloat(value);
                const iVal = parseInt(value, 10);
                
                switch (key) {
                    case "pywal": root.pywal = bVal; break;
                    case "pywal_light": root.pywalLight = bVal; break;
                    case "light_blend_multiplier": root.lightBlendMultiplier = isNaN(fVal) ? 0.85 : fVal; break;
                    case "dark_blend_multiplier": root.darkBlendMultiplier = isNaN(fVal) ? 1.0 : fVal; break;
                    case "sierra_breeze_buttons_color": root.sierraBreezeButtonsColor = bVal; break;
                    case "disable_konsole": root.disableKonsole = bVal; break;
                    case "konsole_opacity": root.konsoleOpacity = isNaN(iVal) ? 85 : iVal; break;
                    case "konsole_opacity_dark": root.konsoleOpacityDark = isNaN(iVal) ? 85 : iVal; break;
                    case "konsole_blur": root.konsoleBlur = bVal; break;
                    case "titlebar_opacity_override": root.titlebarOpacityOverride = bVal; break;
                    case "titlebar_opacity": root.titlebarOpacity = isNaN(iVal) ? 85 : iVal; break;
                    case "titlebar_opacity_dark": root.titlebarOpacityDark = isNaN(iVal) ? 85 : iVal; break;
                    case "toolbar_opacity": root.toolbarOpacity = isNaN(iVal) ? 85 : iVal; break;
                    case "toolbar_opacity_dark": root.toolbarOpacityDark = isNaN(iVal) ? 85 : iVal; break;
                    case "klassy_windeco_outline": root.klassyWindecoOutline = bVal; break;
                    case "use_startup_delay": root.useStartupDelay = bVal; break;
                    case "startup_delay": root.startupDelay = isNaN(iVal) ? 5 : iVal; break;
                    case "main_loop_delay": root.mainLoopDelay = isNaN(iVal) ? 1 : iVal; break;
                    case "screenshot_delay": root.screenshotDelay = isNaN(iVal) ? 900 : iVal; break;
                    case "once_after_change": root.onceAfterChange = bVal; break;
                    case "pause_mode": root.pauseMode = bVal; break;
                    case "chroma_multiplier": root.chromaMultiplier = isNaN(fVal) ? 1.0 : fVal; break;
                    case "tone_multiplier": root.toneMultiplier = isNaN(fVal) ? 1.0 : fVal; break;
                    case "frame_contrast": root.frameContrast = isNaN(fVal) ? 0.2 : fVal; break;
                    case "contrast_level": root.contrastLevel = isNaN(fVal) ? 0.0 : fVal; break;
                    case "manual_fetch": root.manualFetch = bVal; break;
                    case "spec_version": root.specVersion = isNaN(iVal) ? 2025 : iVal; break;
                    case "kde_rounded_corners_effect_outline": root.kdeRoundedCornersEffectOutline = bVal; break;
                }
            }
        }
    }

    function setOption(key: string, value: string): void {
        const scriptPath = Quickshell.shellPath("scripts/sync-kmyc.sh");
        Quickshell.execDetached(["bash", scriptPath, "--set", key, value]);
    }

    ColumnLayout {
        id: contentLayout
        width: root.cappedWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: Tokens.spacing.medium

        FileView {
            id: configFile
            path: `${Paths.config}/kde-material-you-colors/config.conf`
            watchChanges: true
            onLoaded: root.parseConfig(text())
            onFileChanged: reload()
        }

        Item {
            Layout.preferredHeight: Tokens.spacing.small
        }

        SectionHeader {
            text: "Konsole & Pywal Integrations"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            ToggleRow {
                first: true
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                text: "Disable Konsole Sync"
                subtext: "Disable automatic Konsole theming"
                checked: root.disableKonsole
                onToggled: root.setOption("disable_konsole", checked ? "True" : "False")
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                text: "Konsole Blur"
                subtext: "Enable background blur for Konsole"
                checked: root.konsoleBlur
                onToggled: root.setOption("konsole_blur", checked ? "True" : "False")
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Konsole Opacity (Light)"
                subtext: "Konsole background opacity in light mode"
                value: root.konsoleOpacity
                from: 0
                to: 100
                stepSize: 5
                onMoved: v => root.setOption("konsole_opacity", Math.round(v).toString())
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Konsole Opacity (Dark)"
                subtext: "Konsole background opacity in dark mode"
                value: root.konsoleOpacityDark
                from: 0
                to: 100
                stepSize: 5
                onMoved: v => root.setOption("konsole_opacity_dark", Math.round(v).toString())
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                text: "Sync Pywal"
                subtext: "Use pywal to theme other programs using Material You colors"
                checked: root.pywal
                onToggled: root.setOption("pywal", checked ? "True" : "False")
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                last: true
                text: "Pywal & Konsole Light Mode"
                subtext: "Force light/dark mode for pywal and/or Konsole"
                checked: root.pywalLight
                onToggled: root.setOption("pywal_light", checked ? "True" : "False")
            }

        }

        SectionHeader {
            text: "Engine & Behavior"
            first: true
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            ToggleRow {
                first: true
                text: "Pause Mode"
                subtext: "Disables wallpaper detection and automatic theming for Applications, not the Shell"
                checked: root.pauseMode
                onToggled: root.setOption("pause_mode", checked ? "True" : "False")
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                text: "Manual Fetch"
                subtext: "Disables automatic color fetching"
                checked: root.manualFetch
                onToggled: root.setOption("manual_fetch", checked ? "True" : "False")
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                last: true
                text: "Only Apply Once After Change"
                subtext: "Extract colors from screenshot once after changing plugin (useful for animated loops)"
                checked: root.onceAfterChange
                onToggled: root.setOption("once_after_change", checked ? "True" : "False")
            }
        }

        SectionHeader {
            text: "Color Attributes"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StepperRow {
                first: true
                label: "Material Design Spec Version"
                subtext: "The version of the material color specification to use"
                value: root.specVersion
                from: 2021
                to: 2025
                stepSize: 4
                onMoved: v => root.setOption("spec_version", Math.round(v).toString())
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Chroma Multiplier"
                subtext: "Changes chroma (colorfulness) of theme"
                value: root.chromaMultiplier
                from: 0.5
                to: 10.0
                stepSize: 0.1
                onMoved: v => root.setOption("chroma_multiplier", v.toFixed(2))
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Tone Multiplier"
                subtext: "Changes tone (brightness) of theme"
                value: root.toneMultiplier
                from: 0.5
                to: 1.5
                stepSize: 0.1
                onMoved: v => root.setOption("tone_multiplier", v.toFixed(2))
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Contrast Level"
                subtext: "Overall color contrast level"
                value: root.contrastLevel
                from: -1.0
                to: 1.0
                stepSize: 0.1
                onMoved: v => root.setOption("contrast_level", v.toFixed(1))
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Frame Contrast"
                subtext: "Frames and outlines contrast"
                value: root.frameContrast
                from: 0.0
                to: 1.0
                stepSize: 0.1
                onMoved: v => root.setOption("frame_contrast", v.toFixed(1))
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Light Blend Multiplier"
                subtext: "Amount of perceptible color for backgrounds in light mode"
                value: root.lightBlendMultiplier
                from: 0.0
                to: 4.0
                stepSize: 0.1
                onMoved: v => root.setOption("light_blend_multiplier", v.toFixed(2))
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                last: true
                label: "Dark Blend Multiplier"
                subtext: "Amount of perceptible color for backgrounds in dark mode"
                value: root.darkBlendMultiplier
                from: 0.0
                to: 4.0
                stepSize: 0.1
                onMoved: v => root.setOption("dark_blend_multiplier", v.toFixed(2))
            }
        }
        
        SectionHeader {
            text: "Window Decorations (Requires Plugins)"
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            ToggleRow {
                first: true
                text: "Titlebar Opacity Override"
                subtext: "Override opacity values for titlebar"
                checked: root.titlebarOpacityOverride
                onToggled: root.setOption("titlebar_opacity_override", checked ? "True" : "False")
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Titlebar Opacity (Light)"
                subtext: "Requires Klassy or Sierra Breeze Enhanced"
                value: root.titlebarOpacity
                from: 0
                to: 100
                stepSize: 5
                onMoved: v => root.setOption("titlebar_opacity", Math.round(v).toString())
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Titlebar Opacity (Dark)"
                subtext: "Requires Klassy or Sierra Breeze Enhanced"
                value: root.titlebarOpacityDark
                from: 0
                to: 100
                stepSize: 5
                onMoved: v => root.setOption("titlebar_opacity_dark", Math.round(v).toString())
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Toolbar Opacity (Light)"
                subtext: "Requires Lightly Application Style"
                value: root.toolbarOpacity
                from: 0
                to: 100
                stepSize: 5
                onMoved: v => root.setOption("toolbar_opacity", Math.round(v).toString())
            }
            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                label: "Toolbar Opacity (Dark)"
                subtext: "Requires Lightly Application Style"
                value: root.toolbarOpacityDark
                from: 0
                to: 100
                stepSize: 5
                onMoved: v => root.setOption("toolbar_opacity_dark", Math.round(v).toString())
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                text: "Klassy Windeco Outline"
                subtext: "Tint Klassy Window Decoration window outline (Reloads KWin)"
                checked: root.klassyWindecoOutline
                onToggled: root.setOption("klassy_windeco_outline", checked ? "True" : "False")
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                text: "KDE Rounded Corners Outline"
                subtext: "Tint KDE Rounded Corners desktop effect window outline"
                checked: root.kdeRoundedCornersEffectOutline
                onToggled: root.setOption("kde_rounded_corners_effect_outline", checked ? "True" : "False")
            }
            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2
                last: true
                text: "Sierra Breeze Buttons Color"
                subtext: "Tint Sierra Breeze decoration buttons (Reloads KWin)"
                checked: root.sierraBreezeButtonsColor
                onToggled: root.setOption("sierra_breeze_buttons_color", checked ? "True" : "False")
            }
        }
    }
}
