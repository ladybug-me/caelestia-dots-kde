pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Services

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root

    readonly property var windowList: HyprlandState.windowList
    readonly property var addresses: HyprlandState.addresses
    readonly property var windowByAddress: HyprlandState.windowByAddress
    readonly property var workspaces: HyprlandState.workspaces
    readonly property var workspaceIds: HyprlandState.workspaceIds
    readonly property var workspaceById: HyprlandState.workspaceById
    readonly property var activeWorkspace: HyprlandState.activeWorkspace
    readonly property var activeWindow: HyprlandState.activeWindow
    readonly property var monitors: HyprlandState.monitors
    readonly property var layers: HyprlandState.layers

    // True when the KDE bridge is serving the window data: workspaces,
    // activeWorkspace, monitors and layers stay empty there, because there is
    // no KDE source for them. Forwarded so QML does not have to import
    // Caelestia.Services just to ask.
    readonly property bool kdeFallback: HyprlandState.kdeFallback

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = root.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        HyprlandState.updateWindowList();
    }

    function updateLayers() {
        HyprlandState.updateLayers();
    }

    function updateMonitors() {
        HyprlandState.updateMonitors();
    }

    function updateWorkspaces() {
        HyprlandState.updateWorkspaces();
        HyprlandState.updateActiveWorkspace();
    }

    function updateAll() {
        HyprlandState.updateAll();
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = root.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }
}
