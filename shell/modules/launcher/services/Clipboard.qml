pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services

QtObject {
    id: root

    readonly property var items: ClipboardManager.items

    readonly property string imageCacheDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/caelestia-clipboard`

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

    function ensureImageCached(id: int, onReady: var): void {
        const imgPath = getImagePath(id);
        ClipboardManager.decodeImage(id, imgPath);
        // Give the async decode a moment to complete then call back
        if (onReady) {
            Qt.callLater(() => { onReady(imgPath); }, 500);
        }
    }
}
