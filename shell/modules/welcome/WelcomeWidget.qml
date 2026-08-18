pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia.Config
import Caelestia.Blobs // Required for BlobGroup and BlobInvertedRect
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common

FloatingWindow {
    id: root

    property var features: []
    property var unseenFeatures: []
    property int currentIndex: 0
    property var currentFeature: unseenFeatures.length > 0 ? unseenFeatures[currentIndex] : null
    property bool loaded: false

    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false
    title: qsTr("What's New in Caelestia")

    visible: loaded && unseenFeatures.length > 0

    implicitWidth: 640
    implicitHeight: 480

    BackgroundEffect.blurRegion: Region {
        Region { x: -10; y: -10; width: 1; height: 1 } // Prevent full-window blur fallback when disabled
        Region { item: (GlobalConfig.appearance.transparency.enabled && GlobalConfig.appearance.blur) ? container : null }
    }

    Item {
        id: container
        anchors.fill: parent

        BlobGroup {
            id: blobGroup
            smoothing: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerLow
        }

        BlobInvertedRect {
            anchors.fill: parent
            group: blobGroup
            opacity: Colours.tPalette.m3surfaceContainerLow.a
            radius: Tokens.rounding.large
            borderLeft: Tokens.padding.medium
            borderRight: Tokens.padding.medium
            borderTop: Tokens.padding.medium
            borderBottom: Tokens.padding.medium
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.large
            
            AnimatedLogo {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
            }

            StyledText {
                Layout.fillWidth: true
                text: "What's New in Caelestia"
                font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                color: Colours.palette.m3onSurface
                horizontalAlignment: Text.AlignHCenter
            }
            
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                
                Image {
                    anchors.centerIn: parent
                    source: (root.currentFeature && root.currentFeature.media_url) ? Qt.resolvedUrl("../../assets/" + root.currentFeature.media_url) : ""
                    visible: root.currentFeature && root.currentFeature.media_url !== ""
                    fillMode: Image.PreserveAspectFit
                    width: parent.width
                    height: parent.height
                }
            }
            
            Column {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium
                
                StyledText {
                    width: parent.width
                    text: root.currentFeature ? root.currentFeature.title : ""
                    font: Tokens.font.title.builders.medium.weight(Font.Medium).build()
                    color: Colours.palette.m3onSurface
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                
                StyledText {
                    width: parent.width
                    text: root.currentFeature ? root.currentFeature.description : ""
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
            
            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                width: 120
                height: 40
                radius: Tokens.rounding.medium
                color: Colours.palette.m3primary
                
                StyledText {
                    anchors.centerIn: parent
                    text: root.currentIndex < root.unseenFeatures.length - 1 ? "Next" : "Got it!"
                    color: Colours.palette.m3onPrimary
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                }
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.currentIndex < root.unseenFeatures.length - 1) {
                            root.currentIndex++
                        } else {
                            let newIds = root.unseenFeatures.map(f => f.id).join("\n")
                            writeStateProcess.command = ["bash", "-c", "echo -e '" + newIds + "' >> ~/.local/share/caelestia/state/seen_features.txt"]
                            writeStateProcess.running = true
                            root.unseenFeatures = []
                        }
                    }
                }
            }
        }
    }

    Process {
        id: readProcess
        command: ["bash", "-c", "mkdir -p ~/.local/share/caelestia/state && touch ~/.local/share/caelestia/state/seen_features.txt && FEATURES_JSON=\"$(cat ~/.config/quickshell/caelestia/assets/features.json 2>/dev/null || echo '{}')\" && SEEN=\"$(cat ~/.local/share/caelestia/state/seen_features.txt)\" && echo \"$FEATURES_JSON\" && echo \"---SEEN---\" && echo \"$SEEN\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parts = text.split("---SEEN---")
                    let jsonText = parts[0].trim()
                    let seenText = parts[1] ? parts[1].trim() : ""
                    
                    let data = JSON.parse(jsonText)
                    let loadedFeatures = data.features || []
                    
                    let seen = seenText.split("\\n").map(s => s.trim()).filter(s => s.length > 0)
                    
                    root.features = loadedFeatures
                    root.unseenFeatures = loadedFeatures.filter(f => !seen.includes(f.id))
                    root.loaded = true
                } catch (e) {
                    console.error("WelcomeWidget parsing error: " + e)
                }
            }
        }
    }

    Process {
        id: writeStateProcess
        command: []
    }

    Component.onCompleted: {
        readProcess.running = true
    }
}
