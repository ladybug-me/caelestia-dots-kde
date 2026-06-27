pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    property string searchQuery: ""
    property var currentResults: []
    property bool isLoading: false
    property var selectedWallpaper: null
    property bool detailPanelOpen: false
    property int selectedIndex: -1

    function selectWallpaper(index) {
        if (index >= 0 && index < root.currentResults.length) {
            root.selectedWallpaper = root.currentResults[index];
            root.selectedIndex = index;
            root.detailPanelOpen = true;
        }
    }

    function selectNext() {
        if (root.selectedIndex < root.currentResults.length - 1) {
            selectWallpaper(root.selectedIndex + 1);
        }
    }

    function selectPrev() {
        if (root.selectedIndex > 0) {
            selectWallpaper(root.selectedIndex - 1);
        }
    }

    anchors.fill: parent

    onDetailPanelOpenChanged: {
        if (!detailPanelOpen) {
            clearWallpaperTimer.restart();
        }
    }

    ClippingRectangle {
        id: mainClippingRect

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: 0
        anchors.rightMargin: Tokens.padding.medium

        radius: mainBorder.innerRadius
        color: "transparent"

        Loader {
            id: mainLoader

            anchors.fill: parent
            anchors.margins: Tokens.padding.large + Tokens.padding.medium
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.large

            asynchronous: true
            sourceComponent: mainContentComponent
        }
    }

    InnerBorder {
        id: mainBorder

        leftThickness: 0
        rightThickness: Tokens.padding.medium
    }

    Component {
        id: mainContentComponent

        StyledFlickable {
            id: mainFlickable

            flickableDirection: Flickable.VerticalFlick
            contentHeight: mainLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: mainFlickable
            }

            ColumnLayout {
                id: mainLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Tokens.spacing.medium

                RowLayout {
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallhaven")
                        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    CircularIndicator {
                        implicitSize: 20
                        visible: root.isLoading
                    }
                }

                // Search bar
                StyledRect {
                    Layout.fillWidth: true

                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Tokens.rounding.full

                    implicitHeight: searchField.implicitHeight + Tokens.padding.medium * 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "search"
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledTextField {
                            id: searchField

                            Layout.fillWidth: true
                            placeholderText: qsTr("Search wallpapers...")
                            onTextChanged: root.searchQuery = text

                            Keys.onReturnPressed: {
                                if (root.searchQuery.trim()) {
                                    root.isLoading = true;
                                    WallhavenSearcher.search(root.searchQuery);
                                }
                            }
                        }

                        IconButton {
                            icon: "north"
                            onClicked: {
                                if (root.searchQuery.trim()) {
                                    root.isLoading = true;
                                    WallhavenSearcher.searchRandom(root.searchQuery);
                                }
                            }
                        }

                        IconButton {
                            icon: "refresh"
                            onClicked: {
                                if (root.searchQuery.trim()) {
                                    root.isLoading = true;
                                    WallhavenSearcher.search(root.searchQuery);
                                }
                            }
                        }
                    }
                }

                // Results header with pagination
                RowLayout {
                    StyledText {
                        text: root.currentResults.length > 0 ? qsTr("Found %1 wallpapers (page %2 of %3)").arg(root.currentResults.length).arg(WallhavenSearcher.currentPage).arg(WallhavenSearcher.lastPage) : qsTr("No results")
                        font: Tokens.font.body.small
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        text: qsTr("Load more")
                        visible: WallhavenSearcher.currentPage < WallhavenSearcher.lastPage && !root.isLoading && root.currentResults.length > 0
                        onClicked: {
                            root.isLoading = true;
                            WallhavenSearcher.searchNextPage();
                        }
                    }
                }

                // Results grid
                GridView {
                    id: resultsGrid

                    Layout.fillWidth: true
                    implicitHeight: 400

                    cellWidth: 180
                    cellHeight: 140

                    model: root.currentResults
                    clip: true

                    populate: Transition {
                        SequentialAnimation {
                            PropertyAction {
                                property: "scale"
                                value: 0.8
                            }
                            PropertyAction {
                                property: "opacity"
                                value: 0
                            }
                            NumberAnimation {
                                properties: "scale,opacity"
                                from: 0.8
                                to: 1
                                duration: Tokens.anim.durations.expressiveDefaultEffects
                            }
                        }
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property real itemMargin: Tokens.spacing.small / 2

                        width: resultsGrid.cellWidth
                        height: resultsGrid.cellHeight

                        StateLayer {
                            onClicked: root.selectWallpaper(index)

                            anchors.fill: parent
                            anchors.leftMargin: itemMargin
                            anchors.rightMargin: itemMargin
                            anchors.topMargin: itemMargin
                            anchors.bottomMargin: itemMargin

                            radius: Tokens.rounding.medium

                            CachingImage {
                                anchors.fill: parent
                                source: modelData.thumbs?.large || modelData.thumbs?.small || ""
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                    }
                }
            }
        }
    }

    // Wallpaper detail panel with animation
    StyledRect {
        id: detailPanel

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        opacity: root.detailPanelOpen ? 1 : 0
        scale: root.detailPanelOpen ? 1 : 0.95
        clip: true
        enabled: root.detailPanelOpen

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true

                IconButton {
                    icon: "close"
                    onClicked: root.detailPanelOpen = false
                }

                Item {
                    Layout.fillWidth: true
                }

                TextButton {
                    text: qsTr("Download & Set")
                    onClicked: {
                        const wallpaper = root.selectedWallpaper;
                        if (wallpaper)
                            WallhavenSearcher.downloadWallpaper(wallpaper);
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent

                    IconButton {
                        icon: "chevron_left"
                        enabled: root.selectedIndex > 0
                        onClicked: root.selectPrev()
                    }

                    CachingImage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        anchors.margins: Tokens.padding.large
                        source: root.selectedWallpaper?.path || ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }

                    IconButton {
                        icon: "chevron_right"
                        enabled: root.selectedIndex < root.currentResults.length - 1
                        onClicked: root.selectNext()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: root.selectedWallpaper?.resolution || ""
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outline
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: "%1 / %2".arg(root.selectedIndex + 1).arg(root.currentResults.length)
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outline
                }
            }
        }
    }

    // Timer to clear selectedWallpaper after close animation
    Timer {
        id: clearWallpaperTimer

        interval: Tokens.anim.durations.expressiveDefaultEffects
        onTriggered: {
            if (!detailPanelOpen)
                root.selectedWallpaper = null;
        }
    }

    Connections {
        function onSearchComplete(results, meta) {
            if (WallhavenSearcher.currentPage > 1) {
                const merged = [...root.currentResults, ...results];
                root.currentResults = merged;
            } else {
                root.currentResults = results;
            }
            root.isLoading = false;
        }

        function onDownloadComplete(id, path) {
            console.log("Wallhaven: Wallpaper saved to", path);
            if (root.selectedWallpaper && root.selectedWallpaper.id === id) {
                Wallpapers.setWallpaper(path);
                root.detailPanelOpen = false;
            }
        }

        function onDownloadFailed(id, error) {
            root.isLoading = false;
            console.error("Wallhaven: Download failed", error);
        }

        target: WallhavenSearcher
    }
}
