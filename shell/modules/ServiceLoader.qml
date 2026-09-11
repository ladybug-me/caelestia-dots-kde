import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        GameMode;
        Notifs;
        Players;
        Brightness;
        Weather.reload();

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;

        // Watches for kde-material-you-colors re-applying the Plasma colour
        // scheme in a loop, which flashes the screen every second.
        KMYGuard;
    }
}
