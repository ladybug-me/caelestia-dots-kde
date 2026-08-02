pragma ComponentBehavior: Bound

import org.kde.pipewire as Pipewire
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
    readonly property int activeWsId: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.activeId : 1
    property bool ignoreNextSwitch: false
    property bool _initialized: false
    property bool isDragging: false

    signal requestWindowInfo(var client)
    signal requestClose()

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

        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        cacheBuffer: 100000 // Keep all pages instantiated to prevent drag-and-drop interruption
        interactive: !root.isDragging // Prevent ListView from stealing grab during drag
        preferredHighlightBegin: 0
        preferredHighlightEnd: 0
        highlightMoveDuration: root._initialized ? 250 : 0
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: Qt.callLater(root.syncPage)
        onCurrentIndexChanged: {
            if (root.ignoreNextSwitch) return;
            switchTimer.restart();
        }
        model: workspaceModel
        delegate: Item {
            id: page

            required property int index
            readonly property int wsId: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces[index].index : index + 1
            readonly property string wsName: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces[index].name : wsId.toString()
            readonly property var wsWindows: {
                const kwinList = typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList : null;
                let arr = [];
                if (kwinList) {
                    for (let i = 0; i < kwinList.length; ++i) {
                        const w = kwinList[i];
                        if (w.workspace && (w.workspace.id === wsId || w.workspace.index === wsId)) {
                            arr.push(w);
                        }
                    }
                }
                return arr;
            }

            width: listView.width
            height: listView.height
            Component.onCompleted: {
                console.log("WindowGrid Page initialized. wsId:", wsId, "windows found:", wsWindows.length, "Total windows globally:", typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList.length : -1);
            }
            onWsWindowsChanged: {
                console.log("WindowGrid Page updated. wsId:", wsId, "windows found:", wsWindows.length);
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
                            if (typeof KWinActiveWindowBridge !== "undefined") {
                                KWinActiveWindowBridge.setWindowDesktop(sourceItem.clientAddress, page.wsId);
                            } else {
                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.movetoworkspace({ workspace = "${page.wsId}", window = "address:0x${sourceItem.clientAddress}" })` : `movetoworkspace ${page.wsId},address:0x${sourceItem.clientAddress}`);
                            }
                        }
                        drop.accept();
                    }
                }
            }
            Item {
                id: gridItem

                property var windowLayout: Config.overview.layoutType === 0 ? LayoutKde.calculateLayout(page.wsWindows, width, height, Tokens.spacing.large, Tokens.spacing.large) : LayoutGnome.calculateLayout(page.wsWindows, width, height, Tokens.spacing.large, Tokens.spacing.large)

                anchors.fill: parent
                // Behaviors for smooth resizing of the whole container if needed (though it fills parent)

                Repeater {
                    model: page.wsWindows
                    delegate: StyledRect {
                        id: activeWin

                        required property var modelData
                        readonly property string clientAddress: modelData.address
                        readonly property int wsId: page.wsId
                            readonly property var layoutProps: gridItem.windowLayout && gridItem.windowLayout[modelData.address] ? gridItem.windowLayout[modelData.address] : { x: 0, y: 0, width: 200, height: 150 }
                            readonly property int cardWidth: layoutProps.width
                            readonly property int thumbHeight: layoutProps.height
                            readonly property real windowAspect: {
                                const w = modelData.width;
                                const h = modelData.height;
                                return (w > 0 && h > 0) ? (w / h) : (16.0 / 10.0);
                            }

                            x: dragHandler.active ? x : layoutProps.x
                            y: dragHandler.active ? y : layoutProps.y
                            implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2
                            implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
                            color: "transparent"
                            radius: Tokens.rounding.large
                            Component.onCompleted: {
                                root.cardItems = [...root.cardItems, activeWin];
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
                                            KWinActiveWindowBridge.setWindowDesktop(clientAddress, targetWsId);
                                        }
                                    }
                                }
                            }
                            Behavior on x { enabled: !dragHandler.active && root.opacity > 0.5; NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            Behavior on y { enabled: !dragHandler.active && root.opacity > 0.5; NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            HoverHandler { id: hover }
                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.large
                                onClicked: {
                                    if (modelData.address) {
                                        if (typeof KWinActiveWindowBridge !== "undefined") {
                                            KWinActiveWindowBridge.focusWindow(modelData.address);
                                        } else {
                                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                                        }
                                        if (typeof KWinWorkspaceState !== "undefined") {
                                            KWinWorkspaceState.switchTo(page.wsId);
                                        }
                                    }
                                    const v = typeof Visibilities !== "undefined" ? Visibilities.getForActive() : null;
                                    if (v) v.overview = false;
                                }
                            }
                            ColumnLayout {
                                id: cardLayout

                                anchors.centerIn: parent
                                spacing: Tokens.spacing.small

                                StyledClippingRect {
                                    id: thumb

                                    property var streamRequest: null
                                    readonly property int screencastSerial: streamRequest ? streamRequest.objectSerial : 0

                                    function updateStream() {
                                        const isStolen = root.activeInfoClient && root.activeInfoClient.address === modelData.address;
                                        if (root.opacity > 0 && modelData.address && !isStolen) {
                                            if (!streamRequest) {
                                                streamRequest = ScreencastManager.requestStream(modelData.address);
                                            }
                                        } else {
                                            if (streamRequest) {
                                                ScreencastManager.releaseStream(modelData.address);
                                                streamRequest = null;
                                            }
                                        }
                                    }

                                    color: Colours.tPalette.m3surfaceContainerHighest
                                    radius: Tokens.rounding.large
                                    Component.onCompleted: updateStream()
                                    Component.onDestruction: {
                                        if (streamRequest && modelData.address) {
                                            ScreencastManager.releaseStream(modelData.address);
                                        }
                                    }

                                    Connections {
                                        function onOpacityChanged() {
                                            thumb.updateStream();
                                        }
                                        function onActiveInfoClientChanged() {
                                            thumb.updateStream();
                                        }

                                        target: root
                                    }
                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: thumb.height * 0.5
                                        asynchronous: true
                                        visible: thumb.screencastSerial === 0
                                        source: modelData.iconName ? Icons.getAppIcon(modelData.iconName, "image-missing") : (modelData.class ? Icons.getAppIcon(modelData.class, "image-missing") : "")
                                    }
                                    Pipewire.PipeWireSourceItem {
                                        width: {
                                            const wAspect = activeWin.windowAspect;
                                            const containerAspect = thumb.width / Math.max(1, thumb.height);
                                            return (wAspect > containerAspect) ? thumb.width : thumb.height * wAspect;
                                        }
                                        height: {
                                            const wAspect = activeWin.windowAspect;
                                            const containerAspect = thumb.width / Math.max(1, thumb.height);
                                            return (wAspect > containerAspect) ? thumb.width / wAspect : thumb.height;
                                        }
                                        anchors.centerIn: parent
                                        visible: thumb.screencastSerial !== 0
                                        objectSerial: thumb.screencastSerial
                                    }
                                    RowLayout {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
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
                                                onClicked: root.requestWindowInfo(modelData)
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
                                                        if (typeof KWinActiveWindowBridge !== "undefined") {
                                                            KWinActiveWindowBridge.closeWindow(modelData.address);
                                                        } else {
                                                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${modelData.address}" })` : `closewindow address:0x${modelData.address}`);
                                                        }
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
                                    Layout.preferredWidth: activeWin.cardWidth
                                    Layout.preferredHeight: activeWin.thumbHeight
                                }
                                StyledText {
                                    id: titleText

                                    text: modelData.title || ""
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.preferredWidth: activeWin.cardWidth
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
                    if (KWinWorkspaceState.activeId !== wId) {
                        KWinWorkspaceState.switchTo(wId);
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
        }
    StyledRect {
        id: indicatorContainer

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: -(root.panels ? root.panels.bottomMargin : 0) + Tokens.padding.large
        implicitWidth: workspaceIndicator.implicitWidth + Tokens.padding.large * 2
        implicitHeight: workspaceIndicator.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

        WorkspaceIndicator {
            id: workspaceIndicator

            anchors.centerIn: parent
            maxWidth: Math.max(200, root.width - 100)
            count: listView.count
            currentIndex: listView.currentIndex
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
