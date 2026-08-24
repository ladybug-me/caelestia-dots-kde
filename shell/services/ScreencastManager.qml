pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Services

Item {
    id: root

    // If true, keeps streams alive after refCount reaches 0.
    // WARNING: Setting this true means PipeWire/KWin screencast nodes are never
    // freed.  Too many concurrent nodes can exhaust KWin's screencast resources and
    // cause other applications (Vesktop, OBS, browsers) to crash or fail when they
    // try to capture the screen or camera.  Prefer `idleTimeoutMs` instead.
    property bool continuousMode: false
    // When continuousMode is true, automatically destroy streams that have been
    // idle (refCount == 0) for this many milliseconds.  0 = never time out
    // (dangerous — see continuousMode warning).  Default 30 seconds.
    property int idleTimeoutMs: 30000
    // Maximum number of concurrent screencast streams (both active and idle).
    // When the limit is hit, the oldest idle stream is evicted first, then the
    // request is denied.  0 = unlimited (NOT recommended — KWin has finite
    // screencast resources).  Default 16.
    property int maxStreams: 16
    // Global toggle for all screencasts. Tied to GlobalConfig.bar.livePreviews so
    // users on setups where KWin's screencast protocol can't handle a second
    // concurrent client (e.g. some NVIDIA + Vesktop combinations) have a way to
    // fully disable this shell's use of it.
    property bool enableStreams: GlobalConfig.bar.livePreviews
    // Internal dictionary: uuid -> { refCount: number, requestItem: WindowScreencastRequest, lastUsed: Date }
    property var _streams: ({})
    // Ordered list of uuids by last-access time — oldest first, used for eviction.
    property var _streamOrder: []

    function _touchStream(uuid: string): void {
        // Move uuid to end of order (most recently used)
        let order = root._streamOrder;
        let idx = order.indexOf(uuid);
        if (idx >= 0) {
            order.splice(idx, 1);
        }
        order.push(uuid);
        root._streamOrder = order;
    }

    function _evictIfNeeded(): void {
        if (root.maxStreams <= 0) return;

        let streams = root._streams;
        let order = root._streamOrder;
        let count = Object.keys(streams).length;

        // Evict idle streams first (oldest first)
        while (count > root.maxStreams && order.length > 0) {
            let evicted = false;
            // Iterate from oldest to newest
            for (let i = 0; i < order.length && count > root.maxStreams; i++) {
                let uuid = order[i];
                let entry = streams[uuid];
                if (entry && entry.refCount <= 0) {
                    console.debug("[ScreencastManager] EVICTING idle stream for uuid:", uuid, "(maxStreams limit)");
                    entry.requestItem.destroy();
                    delete streams[uuid];
                    order.splice(i, 1);
                    i--;
                    count--;
                    evicted = true;
                }
            }
            if (!evicted) break; // no more idle streams to evict
        }

        root._streamOrder = order;
        root._streams = streams;
    }

    // Must not be called while QML is still creating the object that calls it.
    // Doing so — from a delegate's Component.onCompleted, say — creates a
    // screencast object and mutates this singleton's bookkeeping in the middle
    // of QQmlObjectCreator::finalize, and V4 segfaults writing the entry
    // (insertMember, under StoreElement). It takes a busy dock popout and a
    // handful of windows to hit, but then it is reliable — four times in five
    // on a stress that swaps the hovered icon repeatedly. Callers wrap this in
    // Qt.callLater; WindowSwitcherItem's 20ms timer predates the explanation
    // and does the same thing.
    function requestStream(uuid: string): var {
        if (!enableStreams) return null;
        if (!uuid) return null;
        if (root.maxStreams > 0 && Object.keys(root._streams).length >= root.maxStreams) {
            // Check if any are idle — if not, deny the request
            let streams = root._streams;
            let hasIdle = false;
            for (let key in streams) {
                if (streams[key] && streams[key].refCount <= 0) {
                    hasIdle = true;
                    break;
                }
            }
            if (!hasIdle) {
                console.warn("[ScreencastManager] DENYING stream for uuid:", uuid, "- maxStreams limit reached (", root.maxStreams, ") with all streams active");
                return null;
            }
            root._evictIfNeeded();
        }

        let streams = root._streams;
        let entry = streams[uuid];

        if (!entry) {
            console.debug("[ScreencastManager] CREATING new stream for uuid:", uuid);
            let item = screencastComponent.createObject(root, { targetUuid: uuid });
            entry = {
                refCount: 1,
                requestItem: item,
                lastUsed: new Date()
            };
            streams[uuid] = entry;
            root._streams = streams;
            root._touchStream(uuid);
            root._evictIfNeeded();
        } else {
            entry.refCount += 1;
            entry.lastUsed = new Date();
            console.debug(`[ScreencastManager] REUSING existing stream for uuid: ${uuid} (refCount: ${entry.refCount})`);
            root._touchStream(uuid);
        }

        if (idleCleanupTimer) idleCleanupTimer.restart();
        return entry.requestItem;
    }
    function releaseStream(uuid: string): void {
        if (!uuid) return;

        let streams = root._streams;
        let entry = streams[uuid];

        if (entry) {
            entry.refCount -= 1;
            entry.lastUsed = new Date();
            console.debug(`[ScreencastManager] RELEASED stream for uuid: ${uuid} (new refCount: ${entry.refCount})`);
            if (entry.refCount <= 0) {
                if (!root.continuousMode || root.idleTimeoutMs <= 0) {
                    // Immediate cleanup when continuousMode is off or no timeout
                    if (!root.continuousMode) {
                        console.debug("[ScreencastManager] DESTROYING stream for uuid:", uuid, "because continuousMode is false");
                    }
                    entry.requestItem.destroy();
                    delete streams[uuid];
                    let order = root._streamOrder;
                    let idx = order.indexOf(uuid);
                    if (idx >= 0) order.splice(idx, 1);
                    root._streamOrder = order;
                } else {
                    console.debug("[ScreencastManager] KEEPING stream alive in background for uuid:", uuid, "(idle timeout:", root.idleTimeoutMs, "ms)");
                    if (idleCleanupTimer) idleCleanupTimer.restart();
                }
            }
            root._streams = streams;
        }
    }
    onEnableStreamsChanged: {
        if (!enableStreams) {
            let streams = root._streams;
            let keys = Object.keys(streams);
            for (let i = 0; i < keys.length; i++) {
                let uuid = keys[i];
                streams[uuid].requestItem.destroy();
                delete streams[uuid];
            }
            root._streams = streams;
            root._streamOrder = [];
        }
    }

    // Periodic cleanup of idle streams when continuousMode + idleTimeoutMs are set
    Timer {
        id: idleCleanupTimer

        interval: root.idleTimeoutMs > 0 ? root.idleTimeoutMs : 30000
        repeat: false
        onTriggered: {
            if (!root.continuousMode || root.idleTimeoutMs <= 0) return;
            let now = new Date();
            let streams = root._streams;
            let order = root._streamOrder;
            let keys = Object.keys(streams);
            let changed = false;

            for (let i = 0; i < keys.length; i++) {
                let uuid = keys[i];
                let entry = streams[uuid];
                if (entry && entry.refCount <= 0) {
                    let idleMs = now.getTime() - entry.lastUsed.getTime();
                    if (idleMs >= root.idleTimeoutMs) {
                        console.debug("[ScreencastManager] IDLE TIMEOUT destroying stream for uuid:", uuid, "(idle for", idleMs, "ms)");
                        entry.requestItem.destroy();
                        delete streams[uuid];
                        let idx = order.indexOf(uuid);
                        if (idx >= 0) order.splice(idx, 1);
                        changed = true;
                    }
                }
            }
            if (changed) {
                root._streams = streams;
                root._streamOrder = order;
            }
            // Restart if there are still idle streams
            let hasIdle = false;
            let remainingKeys = Object.keys(root._streams);
            for (let j = 0; j < remainingKeys.length; j++) {
                let e = root._streams[remainingKeys[j]];
                if (e && e.refCount <= 0) { hasIdle = true; break; }
            }
            if (hasIdle) restart();
        }
    }

    Component {
        id: screencastComponent

        WindowScreencastRequest {
            property string targetUuid

            uuid: targetUuid
        }
    }
    // Garbage collect streams for windows that have actually closed
    // This is needed for continuousMode where streams stay alive forever.
    Connections {
        function onWindowListChanged() {
            let activeUuids = {};
            let wList = KWinActiveWindowBridge.windowList;
            if (wList) {
                for (let i = 0; i < wList.length; i++) {
                    if (wList[i] && wList[i].address) {
                        activeUuids[String(wList[i].address)] = true;
                    }
                }
            }
            
            let streams = root._streams;
            let keys = Object.keys(streams);
            let deletedAny = false;
            
            for (let i = 0; i < keys.length; i++) {
                let uuid = keys[i];
                if (!activeUuids[uuid]) {
                    console.debug("[ScreencastManager] GARBAGE COLLECTING closed window stream for uuid:", uuid);
                    streams[uuid].requestItem.destroy();
                    delete streams[uuid];
                    let order = root._streamOrder;
                    let idx = order.indexOf(uuid);
                    if (idx >= 0) order.splice(idx, 1);
                    root._streamOrder = order;
                    deletedAny = true;
                }
            }
            if (deletedAny) {
                root._streams = streams;
            }
        }
        target: typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge : null
    }
}
