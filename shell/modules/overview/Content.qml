pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import ".."

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var panels

    WorkspaceSwitcher {
        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge
    }
}
