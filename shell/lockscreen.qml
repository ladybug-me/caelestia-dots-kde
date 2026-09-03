pragma ComponentBehavior: Bound

import "modules"
import "modules/lock"
import QtQml
import Quickshell
import Caelestia.Config

ShellRoot {
    Component.onCompleted: {
        Qt.application.name = "caelestia-lockscreen";
    }

    Fonts {}
    GSFLoader {}

    Variants {
        model: Quickshell.screens
        
        LockBackgroundWindow {
            required property var modelData

            targetScreen: modelData
        }
    }
}
