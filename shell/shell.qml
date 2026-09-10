pragma ComponentBehavior: Bound

// Environment variables originally set via //@ pragma directives moved to
// the launcher scripts (08-build-shell.sh, 10-autostart.sh) for broader
// quickshell version compatibility.
//@ pragma Env QS_CRASHREPORT_URL=https://github.com/ladybug-me/caelestia-dots-kde/issues/new?template=crash.yml
// //@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
// //@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
// //@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
// //@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "services" as Services
import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import "modules/polkit"
import "modules/screenshot/regionSelector"
import "modules/overview"
import "modules/welcome" as Welcome
import qs.services.api
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.components.containers
import qs.services
import qs.utils

ShellRoot {
    id: root

    settings.watchFiles: false

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    // Several QtCore.Settings {} elements throughout the codebase (BlurOffsets,
    // ContentWindow, UpdateChecker) rely on QCoreApplication's organization/app
    // identifiers to build their QSettings storage path. Quickshell's host
    // binary never sets these, so QSettings previously failed to initialize
    // (status code 1) with "application identifiers have not been set"
    // warnings everywhere. Setting Qt.application.* here runs during this
    // object's property-binding phase, which always completes (for the whole
    // tree) before any child's componentComplete/Component.onCompleted -
    // i.e. before any Settings {} element is finalized - so this reliably
    // fixes it project-wide from a single place.
    readonly property bool _appIdentifiersSet: (function() {
        Qt.application.organization = "Caelestia";
        Qt.application.domain = "caelestia.dots";
        Qt.application.name = "caelestia-shell";
        return true;
    })()

    // UI translations. The catalogues live next to the shell (shell/translations,
    // installed as <shell>/translations/caelestia_<code>.qm), so resolving the
    // path relative to this file works both from the install tree and when
    // running the shell straight from a checkout.
    Binding {
        target: Translations
        property: "extraSearchPaths"
        value: [Qt.resolvedUrl("translations")]
    }

    Binding {
        target: Translations
        property: "language"
        value: GlobalConfig.general.language
    }

    Fonts {}
    GSFLoader {}
    ServiceLoader {}

    Background {}
    BadAppleOverlay {}

    Drawers {}
    // AreaPicker {}
    Lock {
        id: lock
    }
    // PolkitModule {}

    property var regionSelector: RegionSelector {}

    IpcHandler {
        target: "region"

        function screenshot(): void {
            regionSelector.screenshot()
        }

        function search(): void {
            regionSelector.search()
        }

        function ocr(): void {
            regionSelector.ocr()
        }

        function record(): void {
            regionSelector.record()
        }

        function recordWithSound(): void {
            regionSelector.recordWithSound()
        }
    }

    ConfigToasts {}
    Shortcuts {}
    ScreenCorners {}

    Component.onCompleted: {
        Qt.callLater(() => { Weather.reload(); });
        PluginLoader.loadPlugins();
    }

    Services.StartupTasks {}
    Welcome.WelcomeWidget {}

    Process {
        id: bbdxCheckProcess

        running: true
        command: ["bash", "-c", `
            IS_ENABLED=$(kreadconfig6 --file kwinrc --group Plugins --key better_blur_dxEnabled)
            if [ "$IS_ENABLED" = "true" ]; then
                BLUR_MATCHING=$(kreadconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurMatching)
                BLUR_NON_MATCHING=$(kreadconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurNonMatching)
                WINDOW_CLASSES=$(kreadconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses)

                if [ -z "$BLUR_MATCHING" ]; then BLUR_MATCHING="true"; fi
                if [ -z "$BLUR_NON_MATCHING" ]; then BLUR_NON_MATCHING="false"; fi

                MODIFIED=false

                if [ "$BLUR_MATCHING" = "true" ] && [ "$BLUR_NON_MATCHING" = "false" ]; then
                    if echo "$WINDOW_CLASSES" | grep -q '\\bquickshell\\b'; then
                        # Remove quickshell without destroying the rest of the line if comma-separated
                        NEW_CLASSES=$(echo "$WINDOW_CLASSES" | sed -E 's/\\bquickshell\\b//g' | sed 's/,,/,/g' | sed 's/^,//' | sed 's/,$//')
                        kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses "$NEW_CLASSES"
                        MODIFIED=true
                    fi
                elif [ "$BLUR_MATCHING" = "false" ] && [ "$BLUR_NON_MATCHING" = "true" ]; then
                    if ! echo "$WINDOW_CLASSES" | grep -q '\\bquickshell\\b'; then
                        if [ -z "$WINDOW_CLASSES" ]; then
                            NEW_CLASSES="quickshell"
                        elif echo "$WINDOW_CLASSES" | grep -q ','; then
                            NEW_CLASSES="$WINDOW_CLASSES,quickshell"
                        else
                            NEW_CLASSES="$WINDOW_CLASSES"$'\n'"quickshell"
                        fi
                        kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses "$NEW_CLASSES"
                        MODIFIED=true
                    fi
                fi

                if [ "$MODIFIED" = "true" ]; then
                    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
                    qdbus6 org.kde.KWin /Effects reconfigureEffect better_blur_dx 2>/dev/null || true
                fi

                echo "BBDX_ENABLED"
            fi
        `]

        stdout: StdioCollector {
            id: bbdxStdout
        }

        onExited: {
            if (bbdxStdout.text.trim() === "BBDX_ENABLED") {
                GlobalConfig.appearance.blur = true;
            }
        }
    }

    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
    BluetoothReconnect {}

    // Force service initialization
    property var _arpcInit: DiscordRPC

    property var _gameModeInit: GameMode

    property var _updateCheckerInit: UpdateChecker

    property var _autoSchemeInit: AutoScheme
}
