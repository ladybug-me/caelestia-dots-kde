import QtQuick
import QtMultimedia
import Quickshell

Item {
    id: root

    property var screenModel: null
    property bool isFirstInstance: false

    readonly property bool playing: BadApplePlayer.shouldPlay

    function play() {
        BadApplePlayer.play();
    }

    function stop() {
        BadApplePlayer.stop();
    }

    property Item videoOutput: loader.item ? loader.item.videoOutput : null

    Component.onCompleted: {
        root.isFirstInstance = (BadApplePlayer.firstInstance === null);
        BadApplePlayer.firstInstance = root;
    }

    Component.onDestruction: {
        if (BadApplePlayer.firstInstance === root) {
            BadApplePlayer.firstInstance = null;
        }
    }

    Loader {
        id: loader
        active: BadApplePlayer.shouldPlay
        anchors.fill: parent
        sourceComponent: Component {
            Item {
                property alias videoOutput: videoOutput

                MediaPlayer {
                    id: mediaPlayer
                    source: `${Quickshell.shellDir}/assets/badapple.mp4`
                    videoOutput: videoOutput
                    audioOutput: audioOut
                    Component.onCompleted: mediaPlayer.play()
                }

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.Stretch
                    layer.enabled: true
                }

                AudioOutput {
                    id: audioOut
                    muted: !root.isFirstInstance
                }
            }
        }
    }
}
