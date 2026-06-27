pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia
import Caelestia.Config
import Caelestia.Services

Singleton {
    id: root

    property string previousSinkName: ""
    property string previousSourceName: ""

    property list<PwNode> sinks: []
    property list<PwNode> sources: []
    property list<PwNode> streams: []

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property bool sourceMuted: !!source?.audio?.muted
    readonly property real sourceVolume: source?.audio?.volume ?? 0

    readonly property alias cava: cava
    readonly property alias beatTracker: beatTracker

    function setVolume(newVolume: real): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function incrementVolume(amount: real): void {
        setVolume(volume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementVolume(amount: real): void {
        setVolume(volume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setSourceVolume(newVolume: real): void {
        if (source?.ready && source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function incrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume + (amount || GlobalConfig.services.audioIncrement));
    }

    function decrementSourceVolume(amount: real): void {
        setSourceVolume(sourceVolume - (amount || GlobalConfig.services.audioIncrement));
    }

    function setAudioSink(newSink: PwNode): void {
        Pipewire.preferredDefaultAudioSink = newSink;
    }

    function setAudioSource(newSource: PwNode): void {
        Pipewire.preferredDefaultAudioSource = newSource;
    }

    function cycleNextAudioOutput(): void {
        if (sinks.length === 0)
            return;

        const currentIndex = sinks.findIndex(s => s === sink);
        const nextIndex = (currentIndex + 1) % sinks.length;
        setAudioSink(sinks[nextIndex]);
    }

    function setStreamVolume(stream: PwNode, newVolume: real): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = false;
            stream.audio.volume = Math.max(0, Math.min(GlobalConfig.services.maxVolume, newVolume));
        }
    }

    function setStreamMuted(stream: PwNode, muted: bool): void {
        if (stream?.ready && stream?.audio) {
            stream.audio.muted = muted;
        }
    }

    function getStreamVolume(stream: PwNode): real {
        return stream?.audio?.volume ?? 0;
    }

    function getStreamMuted(stream: PwNode): bool {
        return !!stream?.audio?.muted;
    }

    function getStreamName(stream: PwNode): string {
        if (!stream)
            return qsTr("Unknown");
        // Try application name first, then description, then name
        return stream.properties["application.name"] || stream.description || stream.name || qsTr("Unknown Application");
    }

    function playSound(sfx: SoundEffect, setting: bool): void {
        if (!GlobalConfig.audio.sounds.enabled || !setting)
            return;
        sfx.play();
    }

    function playNotification(): void {
        if (GlobalConfig.audio.sounds.enabled) {
            notificationSound.play();
        }
    }

    function playCameraClick(): void {
        playSound(sfxCameraClick, GlobalConfig.audio.sounds.cameraClick);
    }

    function playChargingStarted(): void {
        playSound(sfxChargingStarted, GlobalConfig.audio.sounds.chargingStarted);
    }

    function playEffectTick(): void {
        playSound(sfxEffectTick, GlobalConfig.audio.sounds.effectTick);
    }

    function playLock(): void {
        playSound(sfxLock, GlobalConfig.audio.sounds.lock);
    }

    function playUnlock(): void {
        playSound(sfxUnlock, GlobalConfig.audio.sounds.unlock);
    }

    function playLowBattery(): void {
        playSound(sfxLowBattery, GlobalConfig.audio.sounds.lowBattery);
    }

    function playVideoRecord(): void {
        playSound(sfxVideoRecord, GlobalConfig.audio.sounds.screenRecord);
    }

    function playVideoStop(): void {
        playSound(sfxVideoStop, GlobalConfig.audio.sounds.screenRecord);
    }

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || qsTr("Unknown Device");

        if (previousSinkName && previousSinkName !== newSinkName && GlobalConfig.utilities.toasts.audioOutputChanged)
            Toaster.toast(qsTr("Audio output changed"), qsTr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || qsTr("Unknown Device");

        if (previousSourceName && previousSourceName !== newSourceName && GlobalConfig.utilities.toasts.audioInputChanged)
            Toaster.toast(qsTr("Audio input changed"), qsTr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    Component.onCompleted: {
        previousSinkName = sink?.description || sink?.name || qsTr("Unknown Device");
        previousSourceName = source?.description || source?.name || qsTr("Unknown Device");
    }

    Connections {
        function onValuesChanged(): void {
            const newSinks = [];
            const newSources = [];
            const newStreams = [];

            for (const node of Pipewire.nodes.values) {
                if (!node.isStream) {
                    if (node.isSink)
                        newSinks.push(node);
                    else if (node.audio)
                        newSources.push(node);
                } else if (node.audio) {
                    newStreams.push(node);
                }
            }

            root.sinks = newSinks;
            root.sources = newSources;
            root.streams = newStreams;
        }

        target: Pipewire.nodes
    }

    PwObjectTracker {
        objects: [...root.sinks, ...root.sources, ...root.streams]
    }

    CavaProvider {
        id: cava

        bars: GlobalConfig.services.visualiserBars
    }

    BeatTracker {
        id: beatTracker
    }

    IpcHandler {
        function cycleOutput(): void {
            root.cycleNextAudioOutput();
        }

        target: "audio"
    }

    SoundEffect {
        id: sfxCameraClick

        source: Qt.resolvedUrl("../assets/sounds/camera_click.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: sfxChargingStarted

        source: Qt.resolvedUrl("../assets/sounds/ChargingStarted.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: sfxEffectTick

        source: Qt.resolvedUrl("../assets/sounds/Effect_Tick.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: sfxLock

        source: Qt.resolvedUrl("../assets/sounds/Lock.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: sfxUnlock

        source: Qt.resolvedUrl("../assets/sounds/Unlock.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: sfxLowBattery

        source: Qt.resolvedUrl("../assets/sounds/LowBattery.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: sfxVideoRecord

        source: Qt.resolvedUrl("../assets/sounds/VideoRecord.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: sfxVideoStop

        source: Qt.resolvedUrl("../assets/sounds/VideoStop.wav")
        volume: GlobalConfig.audio.sounds.sfxVolume
    }

    SoundEffect {
        id: notificationSound

        source: Qt.resolvedUrl("../assets/sounds/notifications/" + GlobalConfig.audio.sounds.notificationSound)
        volume: GlobalConfig.audio.sounds.notificationVolume
    }
}
