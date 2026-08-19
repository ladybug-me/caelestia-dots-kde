pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia // Required for CUtils
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
    property bool hasAnimated: false
    
    function isVideo(url) {
        if (!url) return false;
        let lower = url.toLowerCase();
        return lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov");
    }

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
            
            Item {
                id: homeRoot
                
                // Calculate centered block bounds
                readonly property real startupBlockHeight: 90.38 + Tokens.spacing.large + titleText.implicitHeight
                readonly property real startupBlockY: (homeRoot.height - startupBlockHeight) / 2 - 40
                
                property bool isAnimatingState: false
                
                anchors.fill: parent
                
                state: root.hasAnimated ? "loaded" : "startup"
                
                Timer {
                    id: startupTimer
                    interval: 2300
                    running: !root.hasAnimated
                    onTriggered: {
                        homeRoot.isAnimatingState = true
                        root.hasAnimated = true
                        homeRoot.state = "loaded"
                        finishAnimTimer.start()
                    }
                }
                
                Timer {
                    id: finishAnimTimer
                    interval: 850 // slightly longer than the 800ms animation
                    onTriggered: homeRoot.isAnimatingState = false
                }
                
                
                Item {
                    id: logoItem
                    width: 128
                    height: 90.38
                    transformOrigin: Item.TopLeft
                    x: homeRoot.state === "startup" ? (homeRoot.width - width) / 2 : (homeRoot.width - (64 + Tokens.spacing.medium + titleText.implicitWidth)) / 2
                    y: homeRoot.state === "startup" ? homeRoot.startupBlockY : (46 - 45.19) / 2
                    scale: homeRoot.state === "startup" ? 1.0 : 64 / 128
                    
                    AnimatedLogo {
                        id: logoAnim
                        anchors.fill: parent
                    }
                }

                StyledText {
                    id: titleText
                    text: "What's New in Caelestia"
                    font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                    color: Colours.palette.m3onSurface
                    x: homeRoot.state === "startup" ? (homeRoot.width - implicitWidth) / 2 : logoItem.x + 64 + Tokens.spacing.medium
                    y: homeRoot.state === "startup" ? homeRoot.startupBlockY + 90.38 + Tokens.spacing.large : (46 - implicitHeight) / 2
                }
                StyledText {
                    id: startupVersionText
                    text: CUtils.version ? "v" + CUtils.version : ""
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    color: Colours.palette.m3onSurfaceVariant
                    x: homeRoot.state === "startup" ? (homeRoot.width - implicitWidth) / 2 : titleText.x
                    y: titleText.y + titleText.implicitHeight
                    
                    opacity: homeRoot.state === "startup" ? 1 : 0
                }
                
                // Features List
                ListView {
                    id: featuresList
                    anchors.top: parent.top
                    anchors.topMargin: 46 + Tokens.spacing.large
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    
                    opacity: homeRoot.state === "startup" ? 0 : 1
                    clip: true
                    spacing: Tokens.spacing.medium
                    model: root.unseenFeatures
                    
                    Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                    
                    footer: Item {
                        width: featuresList.width
                        height: 64 + Tokens.spacing.large
                        
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.max(0, featuresList.height - featuresList.contentHeight) + (parent.height - implicitHeight) / 2
                            text: CUtils.version ? "v" + CUtils.version : ""
                            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                    
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
                                        text: (feature && feature.icon) ? feature.icon : (feature && root.isVideo(feature.media_url) ? "videocam" : "new_releases")
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
                
                Item {
                    id: fabContainer
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.large
                    width: 56
                    height: 56
                    
                    opacity: homeRoot.state === "startup" ? 0 : 1
                    
                    Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                    
                    StyledRect {
                        id: markAllBtn
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        
                        opacity: markAllMouse.pressed ? 0.85 : (markAllMouse.containsMouse ? 0.95 : 1.0)
                        scale: markAllMouse.pressed ? 0.95 : (markAllMouse.containsMouse ? 1.05 : 1.0)
                        
                        Behavior on opacity { CAnim { duration: 150 } }
                        Behavior on scale { CAnim { duration: 150 } }
                        
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "done_all"
                            color: Colours.palette.m3onPrimary
                            fontStyle: Tokens.font.icon.builders.large.weight(Font.Medium).build()
                        }
                        
                        MouseArea {
                            id: markAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let script = "for id in " + root.unseenFeatures.map(f => f.id).join(" ") + "; do echo \"$id\" >> ~/.local/share/caelestia/state/seen_features.txt; done"
                                writeStateProcess.command = ["bash", "-c", script]
                                writeStateProcess.running = true
                                root.unseenFeatures = []
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: featurePage
            
            Item {
                property var featureData
                property int currentIndex: -1
                property bool hasMedia: featureData && !!featureData.media_url
                
                ColumnLayout {
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
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                    
                    StyledRect {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Tokens.rounding.full
                        color: gotItLayer.containsMouse ? Colours.palette.m3surfaceVariant : "transparent"
                        
                        Behavior on color { CAnim {} }
                        
                        StateLayer {
                            id: gotItLayer
                            anchors.fill: parent
                            topLeftRadius: parent.radius
                            topRightRadius: parent.radius
                            bottomLeftRadius: parent.radius
                            bottomRightRadius: parent.radius
                            
                            onClicked: {
                                let currentId = featureData.id
                                writeStateProcess.command = ["bash", "-c", "echo '" + currentId + "' >> ~/.local/share/caelestia/state/seen_features.txt"]
                                writeStateProcess.running = true
                                
                                stackView.pop()
                                
                                let newUnseen = root.unseenFeatures.filter(f => f.id !== currentId)
                                root.unseenFeatures = newUnseen
                            }
                        }
                        
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "check"
                            color: Colours.palette.m3onSurface
                            fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                        }
                    }
                }
                
                // Expanded Content
                ScrollView {
                    id: expandedScrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    clip: true
                    
                    ColumnLayout {
                        width: expandedScrollView.availableWidth
                        spacing: Tokens.spacing.large
                        
                        // Media Container
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 280
                            visible: hasMedia
                        
                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: Colours.palette.m3surface
                            opacity: 0.5
                            visible: {
                                if (!featureData) return false;
                                if (featureData.media_transparent) return false;
                                if (featureData.media_url) {
                                    let url = featureData.media_url.toLowerCase();
                                    if (url.endsWith(".png") || url.endsWith(".svg") || url.endsWith(".gif")) {
                                        return false;
                                    }
                                }
                                return true;
                            }
                        }
                        
                        AnimatedImage {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            source: hasMedia ? Qt.resolvedUrl("../../assets/welcome/" + featureData.media_url) : ""
                            visible: hasMedia && !root.isVideo(featureData.media_url)
                            fillMode: Image.PreserveAspectFit
                            playing: visible
                        }
                        
                        VideoOutput {
                            id: vidOut
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            visible: hasMedia && root.isVideo(featureData.media_url)
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
                                if (hasMedia && root.isVideo(featureData.media_url)) {
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
                        horizontalAlignment: Text.AlignHCenter
                    }
                    } // End of inner ColumnLayout
                } // End of ScrollView
            } // End of outer ColumnLayout
        } // End of root Item
    } // End of Component
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
                    
                    let seen = seenText.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                    
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
