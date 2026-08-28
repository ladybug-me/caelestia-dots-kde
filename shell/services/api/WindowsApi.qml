import QtQuick
import Caelestia as Backend

QtObject {
    readonly property var kwin: Backend.KWinActiveWindowBridge
    readonly property var workspaces: Backend.KWinWorkspaceState
    readonly property var geometry: Backend.MinimizeGeometry
    readonly property var edges: Backend.ScreenEdges
}
