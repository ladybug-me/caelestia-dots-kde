pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit 0.1
import qs.components

Scope {
    id: root

    PolkitAgent {
        id: agent
        // PolkitAgent handles dbus registration automatically.
    }

    PolkitDialog {
        agent: agent
        screen: Quickshell.screens[0]
    }
}
