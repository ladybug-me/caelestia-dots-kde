pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Layouts
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    property var cardItems: []
    property var activeInfoClient: null
    property var panels: null
    /// The screen this overview belongs to. Everything below is scoped to it:
    /// KWin gives each output its own current desktop, and each window lives on
    /// one output, so an overview that ignores this shows the other monitor's
    /// desktop and the other monitor's windows.
    required property ShellScreen screen
    property var closingWindows: []
    property alias indicatorContainer: indicatorContainer
    readonly property real overviewBorderThickness: Math.min(width, height) * 0.15
    readonly property real indicatorSpace: indicatorContainer.height + Tokens.padding.large * 2
    readonly property real verticalOffset: indicatorSpace - overviewBorderThickness
    readonly property int activeWsId: {
        if (typeof KWinWorkspaceState === "undefined")
            return 1;
        // activeId comes from D-Bus, which exposes a single current desktop and
        // reports whichever output is focused. Per screen, only the tracker
        // knows.
        const perOutput = KWinWorkspaceState.activeByOutput[root.screen.name];
        if (perOutput > 0)
            return perOutput;
        return KWinWorkspaceState.activeId > 0 ? KWinWorkspaceState.activeId : 1;
    }
    property bool ignoreNextSwitch: false
    property bool _initialized: false
    property bool isDragging: false
    readonly property real hoverScale: 1.02
    property int selectedIndex: -1
    readonly property var currentWindows: {
        if (typeof KWinWorkspaceState === "undefined" || listView.currentIndex < 0)
            return [];
        const wsList = KWinWorkspaceState.workspaces;
        if (listView.currentIndex >= wsList.length)
            return [];
        const wsId = wsList[listView.currentIndex].index;
        // windowsForWorkspace already scopes to the workspace; the overview is
        // per-screen, so drop anything living on another output.
        return typeof KWinActiveWindowBridge !== "undefined"
            ? KWinActiveWindowBridge.windowsForWorkspace(wsId, false).filter(w => w.output === root.screen.name)
            : [];
    }

    signal requestWindowInfo(var client)
    signal requestClose()

    // Resolve an icon for a window card, mirroring the dock: prefer an icon
    // extracted from the window's own _NET_WM_ICON (apps with no desktop
    // entry, e.g. Steam games or Minecraft), then fall back to the themed
    // desktop-entry icon lookup the overview already used.
    function windowIconSource(client: var): string {
        if (!client)
            return "";
        const wp = WinIcons.paths[WinIcons.keyFor(client.class, client.pid ?? 0)];
        if (wp)
            return "file://" + wp;
        return client.iconName ? Icons.getAppIcon(client.iconName, "image-missing")
                               : (client.class ? Icons.getAppIcon(client.class, "image-missing") : "");
    }

    function cycleSelection(backwards: bool): void {
        const n = root.currentWindows.length;
        if (n === 0)
            return;
        if (backwards)
            root.selectedIndex = root.selectedIndex <= 0 ? n - 1 : root.selectedIndex - 1;
        else
            root.selectedIndex = root.selectedIndex >= n - 1 ? 0 : root.selectedIndex + 1;
    }
    function activateSelected(): void {
        const wins = root.currentWindows;
        if (root.selectedIndex < 0 || root.selectedIndex >= wins.length)
            return;
        const addr = wins[root.selectedIndex].address;
        if (!addr)
            return;
        if (typeof KWinActiveWindowBridge !== "undefined")
            KWinActiveWindowBridge.focusWindow(addr);
        if (typeof KWinWorkspaceState !== "undefined" && listView.currentIndex >= 0)
            KWinWorkspaceState.switchTo(KWinWorkspaceState.workspaces[listView.currentIndex].index, root.screen.name);
        root.requestClose();
    }
    function syncPage() {
        if (typeof KWinWorkspaceState === "undefined") return;
        for (let i = 0; i < KWinWorkspaceState.workspaces.length; ++i) {
            const wId = KWinWorkspaceState.workspaces[i].index;
            if (wId === activeWsId) {
                if (listView.currentIndex !== i) {
                    listView.currentIndex = i;
                    if (!root._initialized) listView.positionViewAtIndex(i, ListView.SnapPosition);
                }
                break;
            }
        }
        root.ignoreNextSwitch = false;
        ignoreTimer.stop();
        root._initialized = true;
    }

    onOpacityChanged: {
        if (opacity <= 0) {
            selectedIndex = -1;
        } else {
            if (Visibilities.preOverviewActiveWindowAddress !== "") {
                const targetAddress = Visibilities.preOverviewActiveWindowAddress;
                let foundIndex = -1;
                const wins = root.currentWindows;
                if (wins) {
                    for (let i = 0; i < wins.length; ++i) {
                        if (wins[i].address === targetAddress) {
                            foundIndex = i;
                            break;
                        }
                    }
                }
                root.selectedIndex = foundIndex; // -1 if not found
            } else {
                root.selectedIndex = -1;
            }
        }
    }
    onActiveWsIdChanged: Qt.callLater(syncPage)
    Component.onCompleted: {
        if (typeof KWinWorkspaceState !== "undefined") {
            const count = KWinWorkspaceState.workspaces.length;
            for (let i = 0; i < count; ++i) {
                workspaceModel.append({});
            }
        } else {
            workspaceModel.append({});
        }
        Qt.callLater(syncPage);
    }

    Connections {
        function onCycleOverview(backwards) {
            if (root.opacity > 0)
                root.cycleSelection(backwards);
        }

        target: Visibilities
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: root.opacity > 0
        onActivated: root.activateSelected()
    }
    Shortcut {
        sequences: {
            const s = ["Tab", "Right", "Down"];
            if (GlobalConfig.launcher.vimKeybinds) {
                s.push("Ctrl+J", "Ctrl+N");
            }
            return s;
        }
        enabled: root.opacity > 0
        onActivated: root.cycleSelection(false)
    }
    Shortcut {
        sequences: {
            const s = ["Shift+Tab", "Backtab", "Left", "Up"];
            if (GlobalConfig.launcher.vimKeybinds) {
                s.push("Ctrl+K", "Ctrl+P");
            }
            return s;
        }
        enabled: root.opacity > 0
        onActivated: root.cycleSelection(true)
    }
    ListModel {
        id: workspaceModel
    }
    Connections {
        function onWorkspacesChanged() {
            const newCount = KWinWorkspaceState.workspaces.length;
            while (workspaceModel.count < newCount) {
                workspaceModel.append({});
            }
            while (workspaceModel.count > newCount) {
                workspaceModel.remove(workspaceModel.count - 1);
            }
        }

        target: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState : null
    }
    ListView {
        id: listView

        property real rawSwipeOffset: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.swipeOffset : 0.0

        property real targetContentX: (currentIndex + rawSwipeOffset) * width

        anchors.fill: parent
        anchors.topMargin: -verticalOffset
        anchors.bottomMargin: verticalOffset
        orientation: ListView.Horizontal
        highlightRangeMode: ListView.NoHighlightRange
        cacheBuffer: 100000 // Keep all pages instantiated to prevent drag-and-drop interruption
        boundsBehavior: Flickable.StopAtBounds
        interactive: false // Disable native scroll to prevent fighting KWin swipe tracking
        contentX: root._initialized ? targetContentX : currentIndex * width
        model: workspaceModel

        onCountChanged: Qt.callLater(root.syncPage)
        onCurrentIndexChanged: {
            if (root.ignoreNextSwitch) return;
            switchTimer.restart();
        }

        delegate: Item {
            id: page

            required property int index
            readonly property int wsId: (typeof KWinWorkspaceState !== "undefined" && KWinWorkspaceState.workspaces && index < KWinWorkspaceState.workspaces.length) ? KWinWorkspaceState.workspaces[index].index : index + 1
            readonly property string wsName: (typeof KWinWorkspaceState !== "undefined" && KWinWorkspaceState.workspaces && index < KWinWorkspaceState.workspaces.length) ? KWinWorkspaceState.workspaces[index].name : wsId.toString()
            property var wsWindows: []
            readonly property var _winTrigger: typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList : null
            readonly property var _hyprTrigger: (typeof Hypr !== "undefined" && Hypr.toplevels) ? Hypr.toplevels.values : null

            function _updateWsWindows() {
                const kwinList = typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList : null;
                const hyprList = (typeof Hypr !== "undefined" && Hypr.toplevels) ? Hypr.toplevels.values : null;

                let arr = [];
                if (kwinList) {
                    arr = KWinActiveWindowBridge.windowsForWorkspace(wsId, false).filter(w => w.output === root.screen.name);
                } else if (hyprList) {
                    for (let i = 0; i < hyprList.length; ++i) {
                        const w = hyprList[i];
                        if (w.workspace && w.workspace.id === wsId) {
                            arr.push(w);
                        }
                    }
                }

                let changed = arr.length !== wsWindows.length;
                if (!changed) {
                    for (let i = 0; i < arr.length; ++i) {
                        if (arr[i].address !== wsWindows[i].address) {
                            changed = true;
                            break;
                        }
                    }
                }

                if (changed) {
                    wsWindows = arr;
                }
            }

            on_WinTriggerChanged: _updateWsWindows()
            on_HyprTriggerChanged: _updateWsWindows()
            onWsIdChanged: _updateWsWindows()

            width: listView.width
            height: listView.height
            Component.onCompleted: {
                _updateWsWindows();
                //console.log("WindowGrid Page initialized. wsId:", wsId, "windows found:", wsWindows.length, "Total windows globally:", typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList.length : -1);
            }
            onWsWindowsChanged: {
                //console.log("WindowGrid Page updated. wsId:", wsId, "windows found:", wsWindows.length);
            }

            TapHandler {
                onTapped: root.requestClose()
            }
            DropArea {
                anchors.fill: parent
                onDropped: drop => {
                    const sourceItem = drop.source;
                    if (sourceItem && sourceItem.clientAddress) {
                        if (sourceItem.wsId !== undefined && sourceItem.wsId !== page.wsId) {
                            sourceItem.visible = false;
                            const addr = sourceItem.clientAddress;
                            const targetId = page.wsId;
                            Qt.callLater(() => {
                                if (typeof KWinActiveWindowBridge !== "undefined") {
                                    KWinActiveWindowBridge.setWindowDesktop(addr, targetId);
                                } else {
                                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.movetoworkspace({ workspace = "${targetId}", window = "address:0x${addr}" })` : `movetoworkspace ${targetId},address:0x${addr}`);
                                }
                            });
                        }
                        drop.accept();
                    }
                }
            }
            Item {
                id: gridItem

                readonly property real hoverHeadroom: Math.ceil(Math.max(parent.width, parent.height) * (root.hoverScale - 1) / 2)
                property var windowLayout: Config.overview.layoutType === 0 ? LayoutKde.calculateLayout(page.wsWindows, width, height, Tokens.spacing.large, Tokens.spacing.large) : LayoutGnome.calculateLayout(page.wsWindows, width, height, Tokens.spacing.large, Tokens.spacing.large)

                anchors.fill: parent
                anchors.margins: (root.panels ? root.panels.overviewBorderThickness : Tokens.padding.extraLarge) + hoverHeadroom

                Repeater {
                    model: page.wsWindows
                    delegate: StyledRect {
                        id: activeWin

                        required property var modelData
                        required property int index
                        readonly property string clientAddress: modelData.address
                        readonly property int wsId: page.wsId
                            readonly property var layoutProps: gridItem.windowLayout && gridItem.windowLayout[modelData.address] ? gridItem.windowLayout[modelData.address] : { x: 0, y: 0, width: 200, height: 150 }
                            readonly property real windowAspect: {
                                const w = modelData.width;
                                const h = modelData.height;
                                return (w > 0 && h > 0) ? (w / h) : (16.0 / 10.0);
                            }
                            readonly property bool isSelected: page.index === listView.currentIndex && activeWin.index === root.selectedIndex && !root.activeInfoClient
                            readonly property bool showCaption: height > 96 && (hover.hovered || isSelected)

                            property bool closing: false
                            property url infoScreenshot: ""

                            x: dragHandler.active ? x : layoutProps.x
                            y: dragHandler.active ? y : layoutProps.y
                            width: layoutProps.width
                            height: layoutProps.height
                            color: Colours.palette.m3surfaceContainer
                            radius: Tokens.rounding.large
                            scale: closing ? 0 : (activeWin.isSelected && !dragHandler.active ? root.hoverScale : 1)
                            opacity: closing ? 0 : 1
                            border.width: activeWin.isSelected ? 2 : 0
                            border.color: Colours.palette.m3primary

                            Component.onCompleted: {
                                root.cardItems = [...root.cardItems, activeWin];
                                if (modelData && !DesktopEntries.heuristicLookup(modelData.iconName || modelData.class || "")) {
                                    WinIcons.request(modelData.class, modelData.title, modelData.pid ?? 0, modelData.address ? String(modelData.address) : "");
                                }
                            }
                            Component.onDestruction: {
                                root.cardItems = root.cardItems.filter(x => x !== activeWin);
                            }
                            states: [
                                State {
                                    when: dragHandler.active

                                    ParentChange {
                                        target: activeWin
                                        parent: root
                                    }
                                    PropertyChanges {
                                        target: activeWin
                                        opacity: 0.8
                                    }
                                }
                            ]

                            DragHandler {
                                id: dragHandler

                                onActiveChanged: {
                                    root.isDragging = active;
                                    if (!active) {
                                        let dropAction = activeWin.Drag.drop();
                                        if (dropAction !== Qt.IgnoreAction) {
                                            return; // Handled by DropArea
                                        }

                                        if (typeof KWinWorkspaceState === "undefined" || typeof KWinActiveWindowBridge === "undefined") return;
                                        const targetWsId = KWinWorkspaceState.workspaces[listView.currentIndex].index;
                                        if (targetWsId !== page.wsId) {
                                            activeWin.visible = false;
                                            const addr = clientAddress;
                                            Qt.callLater(() => {
                                                KWinActiveWindowBridge.setWindowDesktop(addr, targetWsId);
                                            });
                                        }
                                    }
                                }
                            }
                            Behavior on scale { Anim {} }
                            Behavior on opacity {
                                NumberAnimation {
                                    id: opacityAnim

                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Connections {
                                function onRunningChanged() {
                                    if (!opacityAnim.running && activeWin.closing) {
                                        if (typeof KWinActiveWindowBridge !== "undefined") {
                                            KWinActiveWindowBridge.closeWindow(modelData.address);
                                        } else {
                                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${modelData.address}" })` : `closewindow address:0x${modelData.address}`);
                                        }
                                    }
                                }

                                target: opacityAnim
                            }
                            Behavior on x { enabled: !dragHandler.active && root.opacity > 0.5; NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            Behavior on y { enabled: !dragHandler.active && root.opacity > 0.5; NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            HoverHandler {
                                id: hover

                                onHoveredChanged: {
                                    if (page.index === listView.currentIndex) {
                                        if (hovered) {
                                            root.selectedIndex = activeWin.index;
                                        } else if (root.selectedIndex === activeWin.index) {
                                            root.selectedIndex = -1;
                                        }
                                    }
                                }
                            }

                            Item {
                                id: cardLayout

                                anchors.fill: parent
                                anchors.margins: Tokens.padding.small

                                StyledClippingRect {
                                    id: thumb

                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: parent.height - (caption.opacity * (caption.implicitHeight + Tokens.padding.extraSmall * 2))
                                    color: Colours.tPalette.m3surfaceContainerHighest
                                    radius: Tokens.rounding.medium

                                    WindowPreview {
                                        // Only the page in view and its immediate
                                        // neighbours: a workspace three swipes away
                                        // is not worth a stream. The window shown in
                                        // the info panel is excluded too -- that
                                        // panel puts up its own frozen frame.
                                        active: root.opacity > 0 && Math.abs(page.index - listView.currentIndex) <= 1
                                            && !(root.activeInfoClient && root.activeInfoClient.address === modelData.address)
                                        address: modelData.address ?? ""
                                        width: {
                                            const wAspect = activeWin.windowAspect;
                                            const containerAspect = thumb.width / Math.max(1, thumb.height);
                                            return (wAspect > containerAspect) ? thumb.height * wAspect : thumb.width;
                                        }
                                        height: {
                                            const wAspect = activeWin.windowAspect;
                                            const containerAspect = thumb.width / Math.max(1, thumb.height);
                                            return (wAspect > containerAspect) ? thumb.height : thumb.width / wAspect;
                                        }
                                        anchors.centerIn: parent
                                        fallbackIcon: root.windowIconSource(modelData)
                                        sourceAspect: activeWin.windowAspect
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: activeWin.infoScreenshot
                                        visible: root.activeInfoClient && root.activeInfoClient.address === modelData.address && activeWin.infoScreenshot !== ""
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                }
                                RowLayout {
                                    id: caption

                                    spacing: Tokens.spacing.small
                                    opacity: activeWin.showCaption ? 1 : 0
                                    visible: opacity > 0.01
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: Tokens.padding.extraSmall
                                    anchors.rightMargin: Tokens.padding.extraSmall
                                    anchors.bottomMargin: Tokens.padding.extraSmall

                                    Behavior on opacity { Anim {} }

                                    IconImage {
                                        implicitSize: Math.round(titleText.implicitHeight * 1.1)
                                        asynchronous: true
                                        source: root.windowIconSource(modelData)
                                    }
                                    StyledText {
                                        id: titleText

                                        text: modelData.title || modelData.class || ""
                                        color: Colours.palette.m3primary
                                        font: Tokens.font.body.small
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Behavior on opacity { Anim {} }
                                }
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.large
                                stateOpacity: containsMouse || manualHoverOverride ? 0.02 : 0
                                onClicked: {
                                    if (modelData.address) {
                                        if (typeof KWinActiveWindowBridge !== "undefined") {
                                            KWinActiveWindowBridge.focusWindow(modelData.address);
                                        } else {
                                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                                        }
                                        if (typeof KWinWorkspaceState !== "undefined") {
                                            KWinWorkspaceState.switchTo(page.wsId, root.screen.name);
                                        }
                                    }
                                    if (typeof Visibilities !== "undefined")
                                        Visibilities.setOverview(false);
                                }
                            }

                            RowLayout {
                                anchors.top: cardLayout.top
                                anchors.right: cardLayout.right
                                anchors.margins: Tokens.padding.small
                                spacing: Tokens.spacing.small
                                opacity: hover.hovered ? 1 : 0
                                visible: opacity > 0.01

                                Behavior on opacity { Anim {} }
                                StyledRect {
                                    implicitWidth: infoIcon.implicitHeight + Tokens.padding.small * 2
                                    implicitHeight: infoIcon.implicitHeight + Tokens.padding.small * 2
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3secondaryContainer

                                    StateLayer {
                                        anchors.fill: parent
                                        radius: Tokens.rounding.small

                                        onClicked: {
                                            thumb.grabToImage(function(result) {
                                                activeWin.infoScreenshot = result.url;
                                                root.requestWindowInfo(modelData);
                                            });
                                        }
                                    }
                                    MaterialIcon {
                                        id: infoIcon

                                        anchors.centerIn: parent
                                        text: "chevron_right"
                                        color: Colours.palette.m3onSecondaryContainer
                                        fontStyle.pointSize: Tokens.font.body.medium.pointSize
                                    }
                                }
                                StyledRect {
                                    implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * 2
                                    implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3errorContainer

                                    StateLayer {
                                        anchors.fill: parent
                                        radius: Tokens.rounding.small
                                        onClicked: {
                                            if (modelData.address) {
                                                activeWin.closing = true;
                                                root.closingWindows = root.closingWindows.concat([modelData.address]);
                                            }
                                        }
                                    }
                                    MaterialIcon {
                                        id: closeIcon

                                        anchors.centerIn: parent
                                        text: "close"
                                        color: Colours.palette.m3onErrorContainer
                                        fontStyle.pointSize: Tokens.font.body.medium.pointSize
                                    }
                                }
                            }

                            Drag.active: dragHandler.active
                            Drag.source: activeWin
                            Drag.hotSpot: dragHandler.centroid.position
                        }
                    }
                }
            }

        Timer {
            id: switchTimer

            interval: 50
            onTriggered: {
                if (typeof KWinWorkspaceState !== "undefined" && KWinWorkspaceState.workspaces.length > listView.currentIndex) {
                    const wId = KWinWorkspaceState.workspaces[listView.currentIndex].index;
                    // Compared against this screen's desktop, not the global
                    // activeId: with per-output desktops the global one belongs
                    // to whichever screen is focused, so testing against it made
                    // this fire on the screen that had not moved and stay quiet
                    // on the one that had.
                    if (root.activeWsId !== wId) {
                        KWinWorkspaceState.switchTo(wId, root.screen.name);
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                if (!Config.bar.scrollActions.workspaces) return;

                if (event.angleDelta.y > 0 || event.angleDelta.x > 0) {
                    if (listView.currentIndex > 0) {
                        listView.currentIndex -= 1;
                    }
                } else if (event.angleDelta.y < 0 || event.angleDelta.x < 0) {
                    if (listView.currentIndex < listView.count - 1) {
                        listView.currentIndex += 1;
                    }
                }
            }
        }

        Behavior on contentX {
            enabled: root._initialized

            NumberAnimation {
                duration: rawSwipeOffset === 0.0 ? 300 : 0
                easing.type: rawSwipeOffset === 0.0 ? Easing.OutCubic : Easing.Linear
            }
        }
    }
    StyledRect {
        id: indicatorContainer

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin:Tokens.padding.large
        implicitWidth: workspaceIndicator.implicitWidth + Tokens.padding.large * 2
        implicitHeight: workspaceIndicator.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        WorkspaceIndicator {
            id: workspaceIndicator

            anchors.centerIn: parent
            maxWidth: Math.max(200, root.width - 100)
            screenName: root.screen.name
            count: listView.count
            currentIndex: listView.currentIndex
            closingWindows: root.closingWindows
            onWorkspaceSelected: index => {
                root.ignoreNextSwitch = false;
                listView.currentIndex = index;
            }
            onWorkspaceReselected: root.requestClose()
            onCreateWorkspaceRequest: {
                root.ignoreNextSwitch = true;
                if (typeof KWinWorkspaceState !== "undefined") {
                    KWinWorkspaceState.createWorkspace();
                } else if (typeof Hypr !== "undefined") {
                    Hypr.dispatch("workspace empty");
                }
                ignoreTimer.restart();
            }
        }
    }
    Timer {
        id: ignoreTimer

        interval: 500
        onTriggered: root.ignoreNextSwitch = false
    }
    Timer {
        id: edgeScrollCooldown

        interval: 1000
    }
    DropArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 100
        onEntered: {
            if (!edgeScrollCooldown.running && listView.currentIndex > 0) {
                listView.currentIndex -= 1;
                edgeScrollCooldown.start();
            }
        }
    }
    DropArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 100
        onEntered: {
            if (!edgeScrollCooldown.running && listView.currentIndex < listView.count - 1) {
                listView.currentIndex += 1;
                edgeScrollCooldown.start();
            }
        }
    }
    StyledRect {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Tokens.padding.large
        implicitWidth: prevIcon.implicitWidth + Tokens.padding.large * 2
        implicitHeight: prevIcon.implicitHeight + Tokens.padding.large * 2
        radius: height / 2
        color: Colours.tPalette.m3surfaceContainerHigh
        opacity: hoverPrev.hovered ? 1 : 0.6
        visible: listView.currentIndex > 0

        HoverHandler { id: hoverPrev }
        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            onClicked: listView.currentIndex -= 1
        }
        MaterialIcon {
            id: prevIcon

            anchors.centerIn: parent
            text: "chevron_left"
            color: Colours.palette.m3onSurface
            fontStyle.pointSize: Tokens.font.body.large.pointSize
        }
    }
    StyledRect {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Tokens.padding.large
        implicitWidth: nextIcon.implicitWidth + Tokens.padding.large * 2
        implicitHeight: nextIcon.implicitHeight + Tokens.padding.large * 2
        radius: height / 2
        color: Colours.tPalette.m3surfaceContainerHigh
        opacity: hoverNext.hovered ? 1 : 0.6
        visible: listView.currentIndex < listView.count - 1

        HoverHandler { id: hoverNext }
        StateLayer {
            anchors.fill: parent
            radius: parent.radius
            onClicked: listView.currentIndex += 1
        }
        MaterialIcon {
            id: nextIcon

            anchors.centerIn: parent
            text: "chevron_right"
            color: Colours.palette.m3onSurface
            fontStyle.pointSize: Tokens.font.body.large.pointSize
        }
    }
}
