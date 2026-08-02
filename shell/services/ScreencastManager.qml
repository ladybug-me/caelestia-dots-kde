pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Services

Item {
    id: root
    // If true, keeps streams alive after refCount reaches 0.

    property bool continuousMode: true
    // Global toggle for all screencasts
    property bool enableStreams: true
    // Internal dictionary: uuid -> { refCount: number, requestItem: WindowScreencastRequest }
    property var _streams: ({})

    function requestStream(uuid: string): var {
        if (!enableStreams) return null;
        if (!uuid) return null;
        
        let streams = root._streams;
        let entry = streams[uuid];
        
        if (!entry) {
            console.debug("[ScreencastManager] CREATING new stream for uuid:", uuid);
            let item = screencastComponent.createObject(root, { targetUuid: uuid });
            entry = {
                refCount: 1,
                requestItem: item
            };
            streams[uuid] = entry;
        } else {
            entry.refCount += 1;
            console.debug(`[ScreencastManager] REUSING existing stream for uuid: ${uuid} (refCount: ${entry.refCount})`);
        }
        
        return entry.requestItem;
    }
    function releaseStream(uuid: string): void {
        if (!uuid) return;
        
        let streams = root._streams;
        let entry = streams[uuid];
        
        if (entry) {
            entry.refCount -= 1;
            console.debug(`[ScreencastManager] RELEASED stream for uuid: ${uuid} (new refCount: ${entry.refCount})`);
            if (entry.refCount <= 0 && !root.continuousMode) {
                console.debug("[ScreencastManager] DESTROYING stream for uuid:", uuid, "because continuousMode is false");
                entry.requestItem.destroy();
                delete streams[uuid];
            } else if (entry.refCount <= 0) {
                console.debug("[ScreencastManager] KEEPING stream alive in background for uuid:", uuid, "because continuousMode is true");
            }
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
