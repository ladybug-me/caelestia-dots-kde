pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtMultimedia
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
    property int expandedIndex: -1
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

        StackView {
            id: stackView
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            initialItem: homePage
            
            // Add a clip so pushing/popping doesn't overflow rounded corners
            clip: true
        }

        Component {
            id: homePage
            
            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.large
                
                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium
                    
                    Item {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 34
                        
                        AnimatedLogo {
                            scale: 48 / 128
                            transformOrigin: Item.TopLeft
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "What's New in Caelestia"
                        font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                // Features List
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Tokens.spacing.medium
                    model: root.unseenFeatures
                    
                    delegate: StyledRect {
                        id: delegateRect
                        
                        required property int index
                        required property var modelData
                        
                        property var feature: modelData
                        property bool hasMedia: feature && !!feature.media_url
                        
                        width: ListView.view.width
                        height: contentColumn.implicitHeight + Tokens.padding.large * 2
                        
                        radius: Tokens.rounding.extraLarge
                        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                        
                        Behavior on color { CAnim {} }
                        
                        StateLayer {
                            id: stateLayer
                            anchors.fill: parent
                            topLeftRadius: parent.radius
                            topRightRadius: parent.radius
                            bottomLeftRadius: parent.radius
                            bottomRightRadius: parent.radius
                            
                            onClicked: {
                                stackView.push(featurePage, { featureData: feature, currentIndex: index })
                            }
                        }
                        
                        ColumnLayout {
                            id: contentColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.spacing.large
                            
                            // Header Row (Icon + Text + Chevron)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.medium
                                
                                // Circular Icon
                                StyledRect {
                                    Layout.preferredHeight: 48
                                    Layout.preferredWidth: 48
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3secondaryContainer
                                    
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: (feature && feature.icon) ? feature.icon : (feature && feature.media_type === "video" ? "videocam" : "new_releases")
                                        color: Colours.palette.m3onSecondaryContainer
                                        fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                                        grade: 25
                                        fill: 1
                                    }
                                }
                                
                                // Title & Description
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: feature ? feature.title : ""
                                        font: Tokens.font.body.medium
                                        color: Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }
                                    
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: feature ? feature.description : ""
                                        font: Tokens.font.label.small
                                        color: Colours.palette.m3onSurfaceVariant
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        maximumLineCount: 1
                                    }
                                }
                                
                                // Chevron right for drill down
                                MaterialIcon {
                                    text: "chevron_right"
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                                }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: featurePage
            
            ColumnLayout {
                property var featureData
                property int currentIndex: -1
                property bool hasMedia: featureData && !!featureData.media_url
                
                anchors.fill: parent
                spacing: Tokens.spacing.large
                
                // Header with Back Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium
                    
                    StyledRect {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Tokens.rounding.full
                        color: stateLayer.containsMouse ? Colours.palette.m3surfaceVariant : "transparent"
                        
                        Behavior on color { CAnim {} }
                        
                        StateLayer {
                            id: stateLayer
                            anchors.fill: parent
                            topLeftRadius: parent.radius
                            topRightRadius: parent.radius
                            bottomLeftRadius: parent.radius
                            bottomRightRadius: parent.radius
                            
                            onClicked: stackView.pop()
                        }
                        
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "arrow_back"
                            color: Colours.palette.m3onSurface
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                        }
                    }
                    
                    StyledText {
                        Layout.fillWidth: true
                        text: featureData ? featureData.title : ""
                        font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
                
                // Expanded Content
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing.medium
                    
                    // Media Container
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: hasMedia
                        
                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3surface
                            opacity: 0.5
                        }
                        
                        Image {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            source: hasMedia ? Qt.resolvedUrl("../../assets/welcome/" + featureData.media_url) : ""
                            visible: hasMedia && featureData.media_type !== "video"
                            fillMode: Image.PreserveAspectFit
                        }
                        
                        VideoOutput {
                            id: vidOut
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            visible: hasMedia && featureData.media_type === "video"
                            fillMode: VideoOutput.PreserveAspectFit
                        }
                        
                        AudioOutput {
                            id: aOut
                            muted: true
                        }
                        
                        MediaPlayer {
                            videoOutput: vidOut
                            audioOutput: aOut
                            source: hasMedia ? Qt.resolvedUrl("../../assets/welcome/" + featureData.media_url) : ""
                            loops: MediaPlayer.Infinite
                            
                            Component.onCompleted: {
                                if (hasMedia && featureData.media_type === "video") {
                                    play()
                                }
                            }
                        }
                    }
                    
                    // Description Full
                    StyledText {
                        Layout.fillWidth: true
                        text: featureData ? featureData.description : ""
                        font: Tokens.font.body.large
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                    
                    // Spacer
                    Item { Layout.fillHeight: true }
                    
                    // Got It Button
                    StyledRect {
                        Layout.alignment: Qt.AlignRight
                        width: 100
                        height: 36
                        radius: Tokens.rounding.medium
                        color: Colours.palette.m3primary
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: "Got it!"
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let currentId = featureData.id
                                writeStateProcess.command = ["bash", "-c", "echo '" + currentId + "' >> ~/.local/share/caelestia/state/seen_features.txt"]
                                writeStateProcess.running = true
                                
                                stackView.pop()
                                
                                let newUnseen = root.unseenFeatures.filter(f => f.id !== currentId)
                                root.unseenFeatures = newUnseen
                            }
                        }
                    }
                }
            }
        }
    } // End Container Item
    Process {
        id: readProcess
        command: ["bash", "-c", "mkdir -p ~/.local/share/caelestia/state && touch ~/.local/share/caelestia/state/seen_features.txt && FEATURES_JSON=\"$(cat ~/.config/quickshell/caelestia/assets/welcome/features.json 2>/dev/null || echo '{}')\" && SEEN=\"$(cat ~/.local/share/caelestia/state/seen_features.txt)\" && echo \"$FEATURES_JSON\" && echo \"---SEEN---\" && echo \"$SEEN\""]
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
