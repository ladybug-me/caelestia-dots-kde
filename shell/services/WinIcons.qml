pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Services

// Icons pulled straight out of a window's own _NET_WM_ICON (XWayland) for apps
// that have no resolvable desktop entry or themed icon — Minecraft, most Steam
// games, launcher-spawned windows and so on.
//
// This lives in a singleton rather than on the Dock because the Dock is
// instantiated more than once (one per bar/screen) and the popouts are built
// separately again: a per-Dock map meant whichever instance synced last won,
// and an instance that never ran the extractor would clobber the populated map
// with an empty one. A singleton gives every Dock tile and every hover popup
// the same map and the same "already tried" bookkeeping.
Singleton {
    id: root

    // appClass -> extracted png path
    property var paths: ({})

    // appClass -> extraction already attempted (don't re-spawn the helper)
    property var tried: ({})

    // Ask the plugin for the icon, at most once per class. The extraction is a
    // direct XGetWindowProperty read on _NET_WM_ICON — no helper process, and no
    // python-xlib/Pillow to have installed.
    function request(appClass: string, title: string): void {
        if (!appClass || root.tried[appClass])
            return;

        const t = root.tried;
        t[appClass] = true;
        root.tried = t;

        const path = WindowIcon.extract(appClass, title || "");
        if (path)
            root.register(appClass, path);
    }

    // Cached hits come straight back from extract(), but a window that only
    // appears later still reports through the signal.
    Connections {
        target: WindowIcon

        function onExtracted(appClass: string, path: string): void {
            root.register(appClass, path);
        }
    }

    // Record a freshly extracted icon. Reassigning a copy is what notifies the
    // bindings that read paths[...] — mutating in place would not.
    function register(appClass: string, path: string): void {
        if (!path || path === "" || root.paths[appClass] === path)
            return;
        const m = root.paths;
        m[appClass] = path;
        root.paths = Object.assign({}, m);
    }

    // Resolve an icon for a dock entry, in the order the taskbar tile and the
    // hover popup must agree on: desktop entry icon, then extracted window
    // icon, then the window class as a themed-icon name.
    function sourceFor(entry: var, appClass: string, iconName: string): string {
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable");
        const wp = root.paths[appClass];
        if (wp)
            return "file://" + wp;
        return Quickshell.iconPath(iconName, "application-x-executable");
    }
}
