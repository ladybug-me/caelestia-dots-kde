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

Item {
    id: root

    required property ShellScreen screenData

    // How many columns fit given the grid width
    readonly property int iconCols: grid.count > 0
        ? Math.min(grid.count, Math.floor(grid.width / grid.cellWidth))
        : 0
    // How many rows are occupied
    readonly property int iconRows: iconCols > 0
        ? Math.ceil(grid.count / iconCols)
        : 0

    anchors.fill: parent
    visible: GlobalConfig.forScreen(screenData.name).background.enabled && GlobalConfig.forScreen(screenData.name).background.wallpaperEnabled && GlobalConfig.forScreen(screenData.name).background.desktopIconsEnabled

    GridView {
        id: grid
        anchors.fill: parent
        anchors.margins: Tokens.padding.large * 2

        cellWidth: 100
        cellHeight: 120
        clip: true
        interactive: false

        model: FolderListModel {
            id: folderModel
            folder: "file://" + Quickshell.env("HOME") + "/Desktop"
            showDirsFirst: true
            nameFilters: ["*"]
        }

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight

            required property string fileName
            required property string filePath
            required property bool fileIsDir

            required property string fileSuffix

            property string path: filePath

            function getIconName(isDir, suffix) {
                if (isDir) return "folder";
                const ext = suffix.toLowerCase();
                const imageExts = ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp"];
                const videoExts = ["mp4", "mkv", "webm", "avi", "mov"];
                const archiveExts = ["zip", "tar", "gz", "rar", "7z"];
                const audioExts = ["mp3", "wav", "flac", "ogg"];
                const codeExts = ["qml", "js", "html", "css", "py", "sh", "cpp", "c", "h", "json"];
                
                if (ext === "pdf") return "application-pdf";
                if (ext === "desktop") return "application-x-executable";
                if (imageExts.includes(ext)) return "image-x-generic";
                if (videoExts.includes(ext)) return "video-x-generic";
                if (archiveExts.includes(ext)) return "package-x-generic";
                if (audioExts.includes(ext)) return "audio-x-generic";
                if (codeExts.includes(ext)) return "text-x-script";
                
                return "text-x-generic";
            }

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
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.small

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Image {
                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            source: "image://icon/" + getIconName(fileIsDir, fileSuffix)
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: fileName
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        style: Text.Outline
                        styleColor: Colours.palette.m3surface
                    }
                }
            }
        }
    }
}
