import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

StyledRect {
    id: root

    required property PopoutState popouts
    property var model: popouts.dockModel

    property MprisPlayer player: {
        if (!model) return null;
        return Players.list.find(p => p.identity.toLowerCase().includes(model.appClass.toLowerCase()) || (model.id && p.identity.toLowerCase().includes(model.id.toLowerCase().replace(".desktop", "")))) || null;
    }
    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.dock) ? GlobalConfig.bar.previewScales.dock : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.dock) ? GlobalConfig.bar.previewFontScales.dock : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)
    readonly property int previewWidth: Math.round(Tokens.sizes.bar.windowPreviewSize * scaleOffset)

    radius: Tokens.rounding.medium
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    implicitWidth: mainLayout.implicitWidth + Tokens.padding.medium * scaleOffset * 2
    implicitHeight: mainLayout.implicitHeight + Tokens.padding.medium * scaleOffset * 2
    
    // Explicit sizing for popout positioning calculations
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.medium * scaleOffset
        spacing: Tokens.spacing.small

        // Fallback for pinned apps with no active windows
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium
            visible: !root.model || !root.model.toplevels || root.model.toplevels.length === 0

            IconImage {
                asynchronous: true
                Layout.alignment: Qt.AlignVCenter
                implicitSize: fallbackText.implicitHeight
                source: root.model ? Icons.getAppIcon(root.model.iconName, "image-missing") : ""
            }

            StyledText {
                id: fallbackText
                Layout.fillWidth: true
                text: root.model ? (root.model.entry ? root.model.entry.name : root.model.appClass) : ""
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                elide: Text.ElideRight
            }
        }

        // Active windows list
        Repeater {
            model: root.model && root.model.toplevels ? root.model.toplevels : []

            delegate: StyledRect {
                required property var modelData
                
                Layout.fillWidth: true
                Layout.minimumWidth: previewWidth || 200
                implicitHeight: itemLayout.implicitHeight + Tokens.padding.small * scaleOffset * 2
                
                radius: Tokens.rounding.small
                color: "transparent"
                
                StateLayer {
                    anchors.margins: -Tokens.padding.medium * scaleOffset / 2
                    anchors.leftMargin: -Tokens.padding.medium * scaleOffset
                    anchors.rightMargin: -Tokens.padding.medium * scaleOffset
                    radius: parent.radius
                    onClicked: {
                        if (modelData.address) {
                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                        }
                        root.popouts.hasCurrent = false;
                    }
                }

                RowLayout {
                    id: itemLayout
                    anchors.fill: parent
                    spacing: Tokens.spacing.medium

                    IconImage {
                        asynchronous: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: titleText.implicitHeight
                        source: root.model ? Icons.getAppIcon(root.model.iconName, "image-missing") : ""
                    }

                    StyledText {
                        id: titleText
                        Layout.fillWidth: true
                        text: modelData.title || ""
                        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }


                    // Close button
                    StyledRect {
                        implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                        implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                        radius: Tokens.rounding.small
                        color: Colours.tPalette.m3surfaceVariant

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            onClicked: {
                                if (modelData.address) {
                                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${modelData.address}" })` : `closewindow address:0x${modelData.address}`);
                                }
                                root.popouts.hasCurrent = false;
                            }
                        }

                        MaterialIcon {
                            id: closeIcon
                            anchors.centerIn: parent
                            text: "close"
                            fontStyle.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                        }
                    }
                }
            }
        }

        // Media controls separator
        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colours.tPalette.m3surfaceVariant
            visible: !!root.player
        }

        // Media controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.medium
            visible: !!root.player

            Item {
                implicitWidth: prevIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                implicitHeight: prevIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                visible: root.player ? root.player.canGoPrevious : false

                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.small
                    onClicked: root.player.previous()
                }

                MaterialIcon {
                    id: prevIcon
                    anchors.centerIn: parent
                    text: "skip_previous"
                    fontStyle.pointSize: Tokens.font.body.large.pointSize * root.fontScale
                }
            }

            Item {
                implicitWidth: playIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                implicitHeight: playIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                visible: root.player ? root.player.canTogglePlaying : false

                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.small
                    onClicked: root.player.togglePlaying()
                }

                MaterialIcon {
                    id: playIcon
                    anchors.centerIn: parent
                    text: (root.player && root.player.isPlaying) ? "pause" : "play_arrow"
                    fontStyle.pointSize: Tokens.font.body.large.pointSize * root.fontScale
                }
            }

            Item {
                implicitWidth: nextIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                implicitHeight: nextIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                visible: root.player ? root.player.canGoNext : false

                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.small
                    onClicked: root.player.next()
                }

                MaterialIcon {
                    id: nextIcon
                    anchors.centerIn: parent
                    text: "skip_next"
                    fontStyle.pointSize: Tokens.font.body.large.pointSize * root.fontScale
                }
            }
        }
    }
}
