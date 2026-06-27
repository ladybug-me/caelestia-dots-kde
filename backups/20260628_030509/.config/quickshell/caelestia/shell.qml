pragma ComponentBehavior: Bound

//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQml
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components.containers
import qs.utils
import qs.services
import "modules"
import "modules/drawers"
import "modules/background"
import "modules/shimeji"
import "modules/areapicker"
import "modules/lock"
import "modules/polkit"
import "modules/screenshot/regionSelector"

ShellRoot {
    settings.watchFiles: false

    GSFLoader {}

    Background {}
    BadAppleOverlay {}

    Drawers {}
    AreaPicker {}
    Lock {
        id: lock
    }
    PolkitModule {}
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

    Variants {
        model: Quickshell.screens.filter(s => (GlobalConfig.shimeji?.enabled ?? false) && (GlobalConfig.shimeji?.path?.length ?? 0) > 0 && !Strings.testRegexList(GlobalConfig.shimeji?.excludedScreens ?? [], s.name))

        Shimeji {
            shimejiCount: GlobalConfig.shimeji?.count ?? 1
        }
    }

    ConfigToasts {}
    Shortcuts {}

    Component.onCompleted: {
        Qt.callLater(() => { Weather.reload(); });
    }
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
    BluetoothReconnect {}

    // Force service initialization
    property var _arpcInit: DiscordRPC
    property var _gameModeInit: GameMode
}
