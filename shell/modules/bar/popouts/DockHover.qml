import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services
import qs.utils

StyledRect {
    id: root

    required property PopoutState popouts
    property var model: popouts.dockModel

    property MprisPlayer player: {
        if (!model) return null;
        for (const player of Players.list) {
            const identity = player.identity.toLowerCase();
            if (identity.includes(model.appClass.toLowerCase()) || (model.id && identity.includes(model.id.toLowerCase().replace(".desktop", ""))))
                return player;
        }
        return null;
    }
    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.dock) ? GlobalConfig.bar.previewScales.dock : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.dock) ? GlobalConfig.bar.previewFontScales.dock : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)
    readonly property int previewWidth: Math.round(Tokens.sizes.bar.windowPreviewSize * scaleOffset)
    readonly property int previewColumns: root.model && root.model.toplevels && root.model.toplevels.length > 1 ? 2 : 1
    readonly property int previewTileWidth: Math.round(previewWidth || 220)
    readonly property int previewTileHeight: Math.round(previewTileWidth * 9 / 16)

    function focusWindow(address) {
        if (!address)
            return;
        if (typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.windowList) {
            KWinActiveWindowBridge.focusWindow(address);
        } else {
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${address}" })` : `focuswindow address:0x${address}`);
        }
    }

    function closeWindow(address) {
        if (!address)
            return;
        if (typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.windowList) {
            KWinActiveWindowBridge.closeWindow(address);
        } else {
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${address}" })` : `closewindow address:0x${address}`);
        }
    }

    function screenForWindow(windowData) {
        if (windowData && windowData.screen) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i].name === windowData.screen)
                    return Quickshell.screens[i];
            }
        }
        if (root.popouts && root.popouts.screen)
            return root.popouts.screen;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function sourceRectForWindow(windowData) {
        const screen = screenForWindow(windowData);
        if (!screen || !windowData)
            return Qt.rect(0, 0, 1, 1);

        const x = Math.max(0, Math.round((windowData.x ?? 0) - (screen.x ?? 0)));
        const y = Math.max(0, Math.round((windowData.y ?? 0) - (screen.y ?? 0)));
        const width = Math.max(1, Math.round(windowData.width ?? 1));
        const height = Math.max(1, Math.round(windowData.height ?? 1));
        return Qt.rect(x, y, width, height);
    }

    function previewCaptureSource(windowData) {
        return screenForWindow(windowData);
    }

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
        StyledRect {
            implicitWidth: fallbackLayout.implicitWidth + Tokens.padding.small * scaleOffset * 2
            implicitHeight: fallbackLayout.implicitHeight + Tokens.padding.small * scaleOffset * 2
            visible: !root.model || !root.model.toplevels || root.model.toplevels.length === 0
            radius: Tokens.rounding.small
            color: "transparent"

            StateLayer {
                anchors.margins: -Tokens.padding.medium * scaleOffset / 2
                anchors.leftMargin: -Tokens.padding.medium * scaleOffset
                anchors.rightMargin: -Tokens.padding.medium * scaleOffset
                radius: parent.radius
                onClicked: {
                    if (root.model && root.model.entry) {
                        const subCmd = root.model.entry.runInTerminal
                            ? [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...root.model.entry.command]
                            : root.model.entry.command;
                        const finalCmd = GlobalConfig.services.useSystemd ? ["app2unit", "--", ...subCmd] : subCmd;
                        Quickshell.execDetached({
                            command: finalCmd,
                            workingDirectory: root.model.entry.workingDirectory
                        });
                    }
                    root.popouts.hasCurrent = false;
                }
            }

            RowLayout {
                id: fallbackLayout
                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                IconImage {
                    asynchronous: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitSize: fallbackText.implicitHeight
                    source: root.model ? Icons.getAppIcon(root.model.iconName, "image-missing") : ""
                }

                StyledText {
                    id: fallbackText
                    text: root.model ? (root.model.entry ? root.model.entry.name : root.model.appClass) : ""
                    font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                    elide: Text.ElideRight
                }
            }
        }

        // Active windows grid
        GridLayout {
            Layout.fillWidth: true
            columns: root.previewColumns
            columnSpacing: Tokens.spacing.small * scaleOffset
            rowSpacing: Tokens.spacing.small * scaleOffset

            Repeater {
                model: root.model && root.model.toplevels ? root.model.toplevels : []

                delegate: StyledRect {
                    required property var modelData

                    Layout.preferredWidth: root.previewTileWidth
                    Layout.preferredHeight: root.previewTileHeight + titleBox.implicitHeight
                    implicitWidth: root.previewTileWidth
                    implicitHeight: root.previewTileHeight + titleBox.implicitHeight

                    radius: Tokens.rounding.small
                    color: Colours.tPalette.m3surfaceVariant
                    clip: true

                    StateLayer {
                        anchors.fill: parent
                        radius: parent.radius
                        onClicked: root.focusWindow(modelData.address)
                    }

                    Item {
                        id: previewArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: root.previewTileHeight
                        clip: true

                        ScreencopyView {
                            id: previewCopy
                            anchors.fill: parent
                            captureSource: root.previewCaptureSource(modelData)
                            live: true
                            smooth: true
                            sourceRect: root.sourceRectForWindow(modelData)
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Tokens.spacing.large
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
                            }
                        }

                        StyledRect {
                            id: closeChip
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                            implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * scaleOffset * 2
                            radius: Tokens.rounding.small
                            color: Colours.tPalette.m3surfaceContainerHighest

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered)
                                        root.closeWindow(modelData.address);
                                }
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                onClicked: root.closeWindow(modelData.address)
                            }

                            MaterialIcon {
                                id: closeIcon
                                anchors.centerIn: parent
                                text: "close"
                                fontStyle.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
                            }
                        }
                    }

                    StyledRect {
                        id: titleBox
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitHeight: titleRow.implicitHeight + Tokens.padding.small * scaleOffset * 2
                        radius: 0
                        color: Colours.tPalette.m3surfaceContainer

                        RowLayout {
                            id: titleRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Tokens.padding.small * scaleOffset
                            anchors.rightMargin: Tokens.padding.small * scaleOffset
                            spacing: Tokens.spacing.small

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
