pragma Singleton

import Quickshell
import Caelestia.Services
import qs.components
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()
    property string launcherInitialSearch: ""
    property string initialSidebarTab: "notifications"
    property bool isCaelestiaMode: false
    property string preOverviewActiveWindowAddress: ""

    // Raised when the overview shortcut is pressed while the overview is
    // already up: the grid moves its selection on instead of the drawer
    // closing under the user.
    signal cycleOverview(bool backwards)

    function load(screen: ShellScreen, visibilities: DrawerVisibilities): void {
        screens.set(Hypr.monitorFor(screen), visibilities);
        screens = new Map(screens); // Force QML property change notification
        visibilities.launcherChanged.connect(() => {
            if (!visibilities.launcher)
                return;
            for (const other of screens.values()) {
                if (other !== visibilities)
                    other.launcher = false;
            }
        });
    }
    function registerBar(screen: ShellScreen, barWrapper: var): void {
        bars.set(screen.name, barWrapper);
        bars = new Map(bars); // Force QML property change notification by changing the Map reference
    }
    function getForActive(): DrawerVisibilities {
        const monitor = Hypr.monitors[KWinActiveWindowBridge.cursorOutputName()] || Hypr.focusedMonitor;
        return screens.get(monitor) || screens.values().next().value;
    }
    /**
     * Opens or closes the overview on every screen at once.
     *
     * With per-output desktops each screen shows its own workspace, so opening
     * the overview on the focused screen alone reads as broken on a
     * multi-monitor setup -- one screen goes to the overview and the other
     * carries on as if nothing happened.
     */
    function setOverview(visible: bool): void {
        for (const visibilities of screens.values())
            visibilities.overview = visible;
    }
}
