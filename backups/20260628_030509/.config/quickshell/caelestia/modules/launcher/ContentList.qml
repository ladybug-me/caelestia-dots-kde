pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property var content
    required property DrawerVisibilities visibilities
    required property var panels
    required property real maxHeight
    required property StyledTextField search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}wallpaper `)
    onShowWallpapersChanged: {
        if (showWallpapers) {
            for (let category of Wallpapers.categories) {
                let walls = Wallpapers.grouped[category] || [];
                if (walls.some(w => w.path === Wallpapers.actualCurrent)) {
                    currentWallpaperTab = category;
                    break;
                }
            }
        }
    }
    readonly property bool showWindowSwitcher: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}windows `)
    readonly property bool showKeybinds: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}keybinds `)
    readonly property bool showAnimations: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}animations `)
    readonly property var currentList: showWallpapers ? wallpaperList.item : (showWindowSwitcher ? windowSwitcherList.item : (showAnimations ? animationsList.item : (showKeybinds ? keybindsList.item : appList.item)))

    property string currentWallpaperTab: "Main"

    readonly property var wallpaperTabs: {
        const res = [];
        for (let dir of Wallpapers.categories) {
            res.push({ id: dir, text: dir });
        }
        return res;
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    width: implicitWidth
    height: implicitHeight

    clip: true
    state: showAnimations ? "animations" : (showWindowSwitcher ? "windowSwitcher" : (showKeybinds ? "keybinds" : (showWallpapers ? "wallpapers" : "apps")))

    Behavior on state {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    onStateChanged: {
        if (state === "keybinds") {
            keybindsList.active = true;
        } else {
            keybindsList.active = false;
        }
        if (state === "animations") {
            animationsList.active = true;
        } else {
            animationsList.active = false;
        }
    }

    states: [
        State {
            name: "apps"

            PropertyChanges {
                target: root
                implicitWidth: root.Tokens.sizes.launcher.itemWidth
                implicitHeight: Math.min(root.maxHeight, appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight)
            }
            PropertyChanges {
                target: appList
                active: true
            }

        },
        State {
            name: "wallpapers"

            PropertyChanges {
                target: root
                implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, wallpaperList.implicitWidth)
                implicitHeight: root.Tokens.sizes.launcher.wallpaperHeight + 56 // Extra space for color buttons
            }
            PropertyChanges {
                target: wallpaperList
                active: true
            }
        },
        State {
            name: "windowSwitcher"

            PropertyChanges {
                target: root
                implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, windowSwitcherList.implicitWidth)
                implicitHeight: root.Tokens.sizes.launcher.windowSwitcherHeight
            }
            PropertyChanges {
                target: windowSwitcherList
                active: true
            }
        },
        State {
            name: "keybinds"

            PropertyChanges {
                target: root
                implicitWidth: root.Tokens.sizes.launcher.itemWidth
                implicitHeight: Math.min(root.maxHeight, root.Tokens.sizes.launcher.itemHeight * 7)
            }
            PropertyChanges {
                target: keybindsList
                active: true
            }

        },
        State {
            name: "animations"

            PropertyChanges {
                target: root
                implicitWidth: root.Tokens.sizes.launcher.itemWidth
                implicitHeight: Math.min(root.maxHeight, root.Tokens.sizes.launcher.itemHeight * 7)
            }
            PropertyChanges {
                target: animationsList
                active: true
            }

        }
    ]

    Timer {
        id: keybindsTimer

        interval: 50
        onTriggered: {
            if (state === "keybinds" && keybindsList.item) {
                keybindsList.item.refreshModel();
            }
        }
    }

    Loader {
        id: appList

        active: false

        anchors.fill: parent

        sourceComponent: AppList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Loader {
        id: wallpaperList

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.Tokens.sizes.launcher.wallpaperHeight

        sourceComponent: WallpaperList {
            search: root.search
            visibilities: root.visibilities
            panels: root.panels
            content: root.content
            contentList: root
        }
    }

    Item {
        id: wallpaperTabsWrapper

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.medium
        implicitWidth: Math.min(parent.width - Tokens.padding.large * 2, tabsRow.implicitWidth)
        implicitHeight: tabsRow.implicitHeight + indicator.implicitHeight + 5

        visible: root.state === "wallpapers"

        Flickable {
            id: tabsFlickable
            anchors.fill: parent
            contentWidth: tabsRow.implicitWidth
            contentHeight: parent.height
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            
            ScrollBar.horizontal: StyledScrollBar {
                flickable: tabsFlickable
                active: tabsFlickable.moving || tabsFlickable.dragging
            }

            Row {
                id: tabsRow
                spacing: Tokens.spacing.large

                Repeater {
                    id: tabsRepeater
                    model: root.wallpaperTabs

                    delegate: Item {
                        id: tab
                        required property var modelData
                        required property int index

                        readonly property bool current: root.currentWallpaperTab === tab.modelData.id

                        implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: label.implicitHeight + Tokens.padding.small * 2

                        CustomMouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            function onWheel(event: WheelEvent): void {
                                let idx = root.wallpaperTabs.findIndex(t => t.id === root.currentWallpaperTab);
                                if (event.angleDelta.y < 0 || event.angleDelta.x < 0)
                                    idx = Math.min(idx + 1, root.wallpaperTabs.length - 1);
                                else if (event.angleDelta.y > 0 || event.angleDelta.x > 0)
                                    idx = Math.max(idx - 1, 0);
                                
                                root.currentWallpaperTab = root.wallpaperTabs[idx].id;
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.medium
                                color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                onClicked: root.currentWallpaperTab = tab.modelData.id
                            }
                        }

                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            text: tab.modelData.text
                            color: tab.current ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.large
                        }
                    }
                }
            }

            Item {
                id: indicator

                anchors.top: tabsRow.bottom
                anchors.topMargin: 5

                property int currentIndex: Math.max(0, root.wallpaperTabs.findIndex(t => t.id === root.currentWallpaperTab))
                property Item currentTab: tabsRepeater.itemAt(currentIndex)

                implicitWidth: currentTab ? currentTab.implicitWidth : 0
                implicitHeight: 3
                x: currentTab ? tabsRow.x + currentTab.x : 0

                onCurrentIndexChanged: {
                    if (currentTab) {
                        const targetX = currentTab.x;
                        const targetWidth = currentTab.implicitWidth;
                        if (targetX < tabsFlickable.contentX)
                            tabsFlickable.contentX = targetX;
                        else if (targetX + targetWidth > tabsFlickable.contentX + tabsFlickable.width)
                            tabsFlickable.contentX = targetX + targetWidth - tabsFlickable.width;
                    }
                }

                clip: true

                StyledRect {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    implicitHeight: parent.implicitHeight * 2
                    color: Colours.palette.m3primary
                    radius: Tokens.rounding.full
                }

                Behavior on x {
                    Anim {}
                }
                Behavior on implicitWidth {
                    Anim {}
                }
            }
        }
    }

    Loader {
        id: windowSwitcherList

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: WindowSwitcherList {
            search: root.search
            visibilities: root.visibilities
            panels: root.panels
            content: root.content
        }
    }

    Loader {
        id: keybindsList

        active: false

        anchors.fill: parent

        sourceComponent: KeybindsList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Loader {
        id: animationsList

        active: false

        anchors.fill: parent

        sourceComponent: AnimationsList {
            search: root.search
            visibilities: root.visibilities
        }
    }

    Row {
        id: empty

        opacity: root.currentList?.count === 0 ? 1 : 0
        scale: root.currentList?.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: {
                if (root.state === "wallpapers")
                    return "wallpaper_slideshow";
                if (root.state === "keybinds")
                    return "keyboard";
                if (root.state === "animations")
                    return "animation";
                return "manage_search";
            }
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: {
                    if (root.state === "wallpapers")
                        return qsTr("No wallpapers found");
                    if (root.state === "keybinds")
                        return qsTr("No keybinds found");
                    if (root.state === "animations")
                        return qsTr("No animations found");
                    return qsTr("No results");
                }
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: {
                    if (root.state === "wallpapers")
                        return Wallpapers.list.length === 0 ? qsTr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir)) : qsTr("Try searching for something else");
                    if (root.state === "keybinds")
                        return qsTr("No keybinds match your search");
                    if (root.state === "animations")
                        return qsTr("Try adding .lua files to\n~/.config/caelestia/animations/");
                    return qsTr("Try searching for something else");
                }
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.visibilities.launcher

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: root.visibilities.launcher

        Anim {}
    }
}
