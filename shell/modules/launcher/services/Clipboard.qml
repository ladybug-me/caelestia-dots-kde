pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services

QtObject {
    id: root

    readonly property var items: ClipboardManager.items

    /// Forwarded from C++ so QML items can connect to a single source of truth.
    signal imageReady(int id, string path)

    readonly property string imageCacheDir: ClipboardManager.imageCacheDir

    function reload(): void {
        ClipboardManager.reload();
    }

    function getSortedItems(): var {
        if (!items.length)
            return [];
        const favClips = new Set((GlobalConfig.launcher.favouriteClips || []).map(String));
        const favs = [];
        const rest = [];
        for (const item of items) {
            if (favClips.has(String(item.id))) {
                favs.push(item);
            } else {
                rest.push(item);
            }
        }
        return [...favs, ...rest];
    }

    function getImagePath(clipId: int): string {
        return imageCacheDir + "/" + clipId + ".png";
    }

    /// Connections block to forward the C++ imageReady signal to the QML world.
    property var _conn: Connections {
        target: ClipboardManager
        function onImageReady(id: int, path: string): void {
            root.imageReady(id, path);
        }
    }
}
