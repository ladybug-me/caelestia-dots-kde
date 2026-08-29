pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import Quickshell

StyledRect {
    id: root

    required property string titleText
    required property string versionText
    required property string descriptionText
    property string iconText: "extension"

    default property Component actionComponent

    property bool isExpanded: false
    property string mediaUrl: ""



    // Helper for video
    function isVideo(url) {
        if (!url) return false;
        let lower = url.toString().toLowerCase();
        return lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv");
    }

    width: ListView.view ? ListView.view.width : parent.width
    implicitHeight: contentColumn.implicitHeight + Tokens.padding.large * 2
    
    radius: Tokens.rounding.large
    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, root.isExpanded ? 3 : 1)

    Behavior on color { CAnim {} }

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        topLeftRadius: parent.radius
        topRightRadius: parent.radius
        bottomLeftRadius: parent.radius
        bottomRightRadius: parent.radius

        onClicked: root.isExpanded = !root.isExpanded
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        // --- Header Row ---
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
                    text: root.iconText
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                    grade: 25
                    fill: 1
                }
            }

            // Title & Version row + description
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall
                    
                    StyledText {
                        text: root.titleText
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurface
                        elide: Text.ElideRight
                    }
                    
                    StyledRect {
                        color: Qt.lighter(Colours.palette.m3surfaceVariant, 1.5)
                        radius: Tokens.rounding.small
                        implicitWidth: versionBadge.implicitWidth + Tokens.padding.small * 2
                        implicitHeight: versionBadge.implicitHeight + Tokens.padding.extraSmall
                        Layout.alignment: Qt.AlignVCenter
                        
                        StyledText {
                            id: versionBadge
                            anchors.centerIn: parent
                            text: "v" + root.versionText
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                    Item { Layout.fillWidth: true } // spacer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.descriptionText
                    font: Tokens.font.label.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    wrapMode: root.isExpanded ? Text.Wrap : Text.NoWrap
                    maximumLineCount: root.isExpanded ? 10 : 1
                }
            }

            // Action Item Loader
            Loader {
                active: !!root.actionComponent
                sourceComponent: root.actionComponent
                Layout.alignment: Qt.AlignVCenter
            }

            MaterialIcon {
                text: root.isExpanded ? "expand_less" : "expand_more"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // --- Expanded Content ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.large
            visible: root.isExpanded
            opacity: root.isExpanded ? 1 : 0
            
            Behavior on opacity { CAnim { duration: 250 } }
            
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                visible: !!root.mediaUrl
                clip: true

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    color: Colours.palette.m3surface
                }

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraSmall
                    source: root.mediaUrl
                    visible: !root.isVideo(root.mediaUrl)
                    fillMode: Image.PreserveAspectCrop
                    playing: visible && root.isExpanded
                }

                VideoOutput {
                    id: vidOut
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraSmall
                    visible: root.isVideo(root.mediaUrl)
                    fillMode: VideoOutput.PreserveAspectCrop
                }
                AudioOutput {
                    id: aOut
                    muted: true
                }
                MediaPlayer {
                    id: mediaPlay
                    videoOutput: vidOut
                    audioOutput: aOut
                    source: root.mediaUrl
                    loops: MediaPlayer.Infinite
                    
                    onSourceChanged: {
                        if (root.isVideo(root.mediaUrl) && root.isExpanded) play()
                        else pause()
                    }
                }
            }
        }
    }
    
    // Automatically play/pause media when expanded
    onIsExpandedChanged: {
        if (isExpanded && isVideo(mediaUrl)) {
            mediaPlay.play()
        } else if (!isExpanded && isVideo(mediaUrl)) {
            mediaPlay.pause()
        }
    }
}
