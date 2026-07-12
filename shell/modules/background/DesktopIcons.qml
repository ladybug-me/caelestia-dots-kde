pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import Qt.labs.folderlistmodel

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled && GlobalConfig.forScreen(s.name).background.wallpaperEnabled && GlobalConfig.forScreen(s.name).background.desktopIconsEnabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        // How many columns fit given the grid width
        readonly property int iconCols: grid.count > 0
            ? Math.min(grid.count, Math.floor(grid.width / grid.cellWidth))
            : 0
        // How many rows are occupied
        readonly property int iconRows: iconCols > 0
            ? Math.ceil(grid.count / iconCols)
            : 0

        screen: modelData
        name: "desktopicons"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        surfaceFormat.opaque: false
        color: "transparent"

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        // Sparse mask: only the rectangle occupied by actual icon cells.
        // Empty desktop areas around and below the icons are fully click-through.
        mask: iconMask

        Region {
            id: iconMask
            x: grid.x
            y: grid.y
            width: win.iconCols * grid.cellWidth
            height: win.iconRows * grid.cellHeight
        }

        GridView {
            id: grid
            anchors.fill: parent
            anchors.margins: Tokens.padding.large * 2

            cellWidth: 100
            cellHeight: 120
            interactive: false
            flow: GridView.FlowLeftToRight

            model: FolderListModel {
                folder: "file://" + Quickshell.env("HOME") + "/Desktop"
                nameFilters: ["*"]
                showDirs: true
                showDotAndDotDot: false
            }

            delegate: Item {
                width: grid.cellWidth
                height: grid.cellHeight

                required property string fileName
                required property string filePath
                required property bool fileIsDir

                property string path: filePath

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        Quickshell.execDetached(["xdg-open", path]);
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Colours.palette.m3onSurface
                        opacity: mouseArea.containsMouse ? 0.12 : 0
                        radius: Tokens.rounding.medium

                        Behavior on opacity {
                            NumberAnimation { duration: 100 }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: fileIsDir ? "folder" : "description"
                            fontStyle: Tokens.font.icon.extraLarge
                            color: Colours.palette.m3onSurface
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            text: fileName
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3onSurface
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
