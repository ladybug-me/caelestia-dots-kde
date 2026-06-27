pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Components
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Select wallpaper")

    property color sortColor: "transparent"
    property var colorDistances: ({})
    property int sortVersion: 0
    property var wallpaperColors: ({})

    readonly property var sortColors: ["#e53935" // Red
        , "#1e88e5" // Blue
        , "#43a047" // Green
        , "#fdd835" // Yellow
        , "#8e24aa" // Purple
        , "#fb8c00"  // Orange
    ]

    function colorDistance(c1: color, c2: color): real {
        const dr = c1.r - c2.r;
        const dg = c1.g - c2.g;
        const db = c1.b - c2.b;
        return Math.sqrt(dr * dr + dg * dg + db * db);
    }

    function toggleSortColor(color: color) {
        if (root.sortColor === color) {
            root.sortColor = "transparent";
        } else {
            root.sortColor = color;
            root.analyzeColors();
        }
    }

    function analyzeColors() {
        const walls = Wallpapers.list;
        const baseDir = Paths.wallsdir;
        const newDistances = {};

        for (const w of walls) {
            if (w.parentDir === baseDir) {
                newDistances[w.path] = colorDistance(root.wallpaperColors[w.path] ?? "black", root.sortColor);
            }
        }

        root.colorDistances = newDistances;
        root.sortVersion++;
    }

    onSortColorChanged: {
        if (sortColor === "transparent") {
            wallpaperColors = ({});
            colorDistances = ({});
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        ButtonRow {
            Layout.bottomMargin: Tokens.spacing.medium
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "photo_library"
                text: qsTr("Browse")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: browseDialog.open()

                FileDialog {
                    id: browseDialog

                    title: qsTr("Select an image")
                    filterLabel: qsTr("Image files")
                    filters: Images.validImageExtensions
                    onAccepted: path => {
                        Wallpapers.setWallpaper(path);
                    }
                }
            }

            IconTextButton {
                icon: "shuffle"
                text: qsTr("Random")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                type: IconTextButton.Tonal
                onClicked: {
                    Wallpapers.setRandom();
                    root.nState.closeSubPage();
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Featured wallpapers")
            font: Tokens.font.title.small
        }

        GridLayout {
            property list<var> featuredList: [
                {
                    path: "assets/wallpapers/Gravitation.png",
                    name: "Gravitation",
                    author: "PixelKhaos"
                },
                {
                    path: "assets/wallpapers/CelestialTech.png",
                    name: "CelestialTech",
                    author: "DiM"
                },
                {
                    path: "assets/wallpapers/Material-Nebula.png",
                    name: "Material-Nebula",
                    author: "DiM"
                },
                {
                    path: "assets/wallpapers/Material-Wave.png",
                    name: "Material-Wave",
                    author: "Marv"
                },
                {
                    path: "assets/wallpapers/Minimal-Paper.png",
                    name: "Minimal-Paper",
                    author: "Forger"
                },
                {
                    path: "assets/wallpapers/silly-lestia.png",
                    name: "silly-lestia",
                    author: "DiM"
                }
            ]

            Layout.fillWidth: true

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: parent.featuredList

                WallItem {
                    required property var modelData

                    imgHeight: Math.round(width * 0.3)
                    radius: Tokens.rounding.extraLarge
                    source: Quickshell.shellPath(modelData.path)
                    text: modelData.name
                    fillLabel: false
                    onClicked: {
                        Wallpapers.setWallpaper(Quickshell.shellPath(modelData.path));
                    }
                }
            }
        }

        // Color sorting and type filtering
        RowLayout {
            Layout.topMargin: Tokens.spacing.medium
            Layout.fillWidth: true
            z: typeFilterBtn.expanded ? 1 : 0

            Item {
                Layout.fillWidth: true
            }

            Row {
                spacing: Tokens.spacing.medium

                // Red button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Tokens.rounding.full
                    color: "#e53935"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: parent.radius
                        color: "transparent"
                        border.width: root.sortColor === "#e53935" ? 3 : 0
                        border.color: Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleSortColor("#e53935")
                    }
                }

                // Blue button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Tokens.rounding.full
                    color: "#1e88e5"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: parent.radius
                        color: "transparent"
                        border.width: root.sortColor === "#1e88e5" ? 3 : 0
                        border.color: Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleSortColor("#1e88e5")
                    }
                }

                // Green button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Tokens.rounding.full
                    color: "#43a047"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: parent.radius
                        color: "transparent"
                        border.width: root.sortColor === "#43a047" ? 3 : 0
                        border.color: Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleSortColor("#43a047")
                    }
                }

                // Yellow button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Tokens.rounding.full
                    color: "#fdd835"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: parent.radius
                        color: "transparent"
                        border.width: root.sortColor === "#fdd835" ? 3 : 0
                        border.color: Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleSortColor("#fdd835")
                    }
                }

                // Purple button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Tokens.rounding.full
                    color: "#8e24aa"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: parent.radius
                        color: "transparent"
                        border.width: root.sortColor === "#8e24aa" ? 3 : 0
                        border.color: Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleSortColor("#8e24aa")
                    }
                }

                // Orange button
                Rectangle {
                    width: 36
                    height: 36
                    radius: Tokens.rounding.full
                    color: "#fb8c00"

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: parent.radius
                        color: "transparent"
                        border.width: root.sortColor === "#fb8c00" ? 3 : 0
                        border.color: Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.toggleSortColor("#fb8c00")
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            SplitButton {
                id: typeFilterBtn

                type: SplitButton.Tonal
                fallbackIcon: "collections"
                fallbackText: qsTr("All")
                minLeftWidth: 100

                menuItems: [
                    MenuItem {
                        property string filterValue: "all"
                        text: qsTr("All")
                        icon: "collections"
                        onClicked: {
                            if (root.nState) root.nState.wallpaperFilterType = "all"
                        }
                    },
                    MenuItem {
                        property string filterValue: "image"
                        text: qsTr("Images")
                        icon: "image"
                        onClicked: {
                            if (root.nState) root.nState.wallpaperFilterType = "image"
                        }
                    },
                    MenuItem {
                        property string filterValue: "gif"
                        text: qsTr("GIFs")
                        icon: "gif"
                        onClicked: {
                            if (root.nState) root.nState.wallpaperFilterType = "gif"
                        }
                    },
                    MenuItem {
                        property string filterValue: "video"
                        text: qsTr("Videos")
                        icon: "movie"
                        onClicked: {
                            if (root.nState) root.nState.wallpaperFilterType = "video"
                        }
                    }
                ]

                active: {
                    const f = root.nState ? root.nState.wallpaperFilterType : "all";
                    return menuItems.find(m => m.filterValue === f) ?? menuItems[0];
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.large
            text: qsTr("Local wallpapers")
            font: Tokens.font.title.small
        }

        GridLayout {
            Layout.fillWidth: true
            visible: localWalls.count > 0

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                id: localWalls

                model: {
                    const walls = Wallpapers.list;
                    const baseDir = Paths.wallsdir;
                    const categories = {};
                    const list = [];
                    const filter = root.nState ? root.nState.wallpaperFilterType : "all";

                    for (const w of walls) {
                        const isVid = Images.isVideo(w.name);
                        const isGif = w.name.toLowerCase().endsWith(".gif");
                        const isImg = Images.isValidImageByName(w.name) && !isGif;

                        let matches = false;
                        if (filter === "all") {
                            matches = true;
                        } else if (filter === "video" && isVid) {
                            matches = true;
                        } else if (filter === "gif" && isGif) {
                            matches = true;
                        } else if (filter === "image" && isImg) {
                            matches = true;
                        }

                        if (!matches)
                            continue;

                        if (w.parentDir !== baseDir) {
                            const category = Wallpapers.getCategoryFor(w);
                            if (category && (!(category in categories) || categories[category].name.localeCompare(w.name) > 0))
                                categories[category] = w;
                        } else {
                            list.push(w);
                        }
                    }

                    for (const cat in categories) {
                        list.push(categories[cat]);
                    }

                    // Sort by color distance if sortColor is set
                    if (root.sortColor !== "transparent") {
                        list.sort((a, b) => {
                            const distA = root.colorDistances[a.path] ?? 999999;
                            const distB = root.colorDistances[b.path] ?? 999999;
                            return distA - distB;
                        });
                    } else {
                        list.sort((a, b) => a.name.localeCompare(b.name));
                    }

                    while (list.length < Config.nexus.wallpapersPerRow)
                        list.push(null);
                    return list;
                }

                WallItem {
                    id: wallItem

                    required property FileSystemEntry modelData

                    // Empty placeholders for sizing
                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    source: String(modelData?.path ?? "")
                    text: {
                        if (!modelData)
                            return "";

                        if (modelData.parentDir !== Paths.wallsdir) {
                            const category = Wallpapers.getCategoryFor(modelData);
                            return category.slice(0, 1).toUpperCase() + category.slice(1);
                        }
                        return modelData.name;
                    }
                    onClicked: {
                        if (modelData.parentDir !== Paths.wallsdir) {
                            root.nState.selectedWallpaperCategory = Wallpapers.getCategoryFor(modelData);
                            root.nState.openSubPage(2); // Category page
                        } else {
                            Wallpapers.setWallpaper(modelData.path);
                        }
                    }

                    // Analyze color when image loads and sorting is active
                    onSourceChanged: {
                        if (root.sortColor !== "transparent" && modelData && modelData.parentDir === Paths.wallsdir) {
                            colorAnalyzer.source = modelData.path;
                        }
                    }

                    ImageAnalyser {
                        id: colorAnalyzer

                        rescaleSize: 64
                        onDominantColourChanged: {
                            if (modelData) {
                                root.wallpaperColors[modelData.path] = dominantColour;
                                // Update distance for this wallpaper
                                if (root.sortColor !== "transparent") {
                                    root.colorDistances[modelData.path] = root.colorDistance(dominantColour, root.sortColor);
                                    root.sortVersion++;
                                }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true

            asynchronous: true
            active: localWalls.count === 0
            visible: active

            sourceComponent: StyledRect {
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.extraLarge
                implicitHeight: noWallsLayout.implicitHeight + Tokens.padding.extraExtraLarge * 2

                ColumnLayout {
                    id: noWallsLayout

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No local wallpapers found")
                        color: Colours.palette.m3outline
                        font: Tokens.font.title.small
                    }
                }
            }
        }
    }
}
