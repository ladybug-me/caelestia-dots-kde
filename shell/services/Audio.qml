pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.services

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

    // CavaProvider is only registered when the plugin was built with libcava
    // available (see shell/plugin/CMakeLists.txt). Create it dynamically so a
    // build without Cava doesn't fail this whole singleton's component load.
    property var cava: null
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
            return I18n.tr("Unknown");
        // Try application name first, then description, then name
        return stream.properties["application.name"] || stream.description || stream.name || I18n.tr("Unknown Application");
    }

    Component {
        id: sfxComponent

        SoundEffect {}
    }

    property var _sfxCache: ({})

    function playSoundSource(sourcePath: string, enabled: bool, volume: real): void {
        if (!GlobalConfig.audio.sounds.enabled || !enabled)
            return;
            
        let sfx = root._sfxCache[sourcePath];
        if (!sfx) {
            sfx = sfxComponent.createObject(root, { source: sourcePath, volume: volume });
            root._sfxCache[sourcePath] = sfx;
        } else {
            sfx.volume = volume;
        }
        sfx.play();
    }

    function playNotification(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/notifications/" + GlobalConfig.audio.sounds.notificationSound), true, GlobalConfig.audio.sounds.notificationVolume);
    }

    function playCameraClick(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/camera_click.wav"), GlobalConfig.audio.sounds.cameraClick, GlobalConfig.audio.sounds.sfxVolume);
    }

    function playChargingStarted(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/ChargingStarted.wav"), GlobalConfig.audio.sounds.chargingStarted, GlobalConfig.audio.sounds.sfxVolume);
    }

    function playEffectTick(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/Effect_Tick.wav"), GlobalConfig.audio.sounds.effectTick, GlobalConfig.audio.sounds.sfxVolume);
    }

    function playLock(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/Lock.wav"), GlobalConfig.audio.sounds.lock, GlobalConfig.audio.sounds.sfxVolume);
    }

    function playUnlock(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/Unlock.wav"), GlobalConfig.audio.sounds.unlock, GlobalConfig.audio.sounds.sfxVolume);
    }

    function playLowBattery(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/LowBattery.wav"), GlobalConfig.audio.sounds.lowBattery, GlobalConfig.audio.sounds.sfxVolume);
    }

    function playVideoRecord(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/VideoRecord.wav"), GlobalConfig.audio.sounds.screenRecord, GlobalConfig.audio.sounds.sfxVolume);
    }

    function playVideoStop(): void {
        playSoundSource(Qt.resolvedUrl("../assets/sounds/VideoStop.wav"), GlobalConfig.audio.sounds.screenRecord, GlobalConfig.audio.sounds.sfxVolume);
    }

    function refreshNodes(): void {
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

    onSinkChanged: {
        if (!sink?.ready)
            return;

        const newSinkName = sink.description || sink.name || I18n.tr("Unknown Device");

        if (previousSinkName && previousSinkName !== newSinkName && GlobalConfig.utilities.toasts.audioOutputChanged)
            Toaster.toast(I18n.tr("Audio output changed"), I18n.tr("Now using: %1").arg(newSinkName), "volume_up");

        previousSinkName = newSinkName;
    }

    onSourceChanged: {
        if (!source?.ready)
            return;

        const newSourceName = source.description || source.name || I18n.tr("Unknown Device");

        if (previousSourceName && previousSourceName !== newSourceName && GlobalConfig.utilities.toasts.audioInputChanged)
            Toaster.toast(I18n.tr("Audio input changed"), I18n.tr("Now using: %1").arg(newSourceName), "mic");

        previousSourceName = newSourceName;
    }

    // Populate immediately: Pipewire.nodes may already be filled by the time this
    // lazily-loaded singleton is created, so onValuesChanged would never fire.
    Component.onCompleted: {
        refreshNodes();
        previousSinkName = sink?.description || sink?.name || I18n.tr("Unknown Device");
        previousSourceName = source?.description || source?.name || I18n.tr("Unknown Device");

        // CavaProvider is only registered when the plugin was built with
        // libcava available (see shell/plugin/CMakeLists.txt); create it
        // dynamically so a build without Cava doesn't fail this singleton's load.
        try {
            root.cava = Qt.createQmlObject(
                'import Caelestia.Config\nimport Caelestia.Services\nCavaProvider { bars: GlobalConfig.services.visualiserBars }',
                root, "CavaProviderDynamic");
        } catch (e) {
            console.warn("Caelestia: CavaProvider unavailable, visualiser disabled:", e);
        }
    }

    Connections {
        function onValuesChanged(): void {
            root.refreshNodes();
        }

        target: Pipewire.nodes
    }

    // Always track the current defaults so volume/mute bind even if the lists
    // momentarily lag behind the default node.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.streams].filter(n => n)
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

}
