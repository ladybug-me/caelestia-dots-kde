pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import Quickshell
import Quickshell.Widgets
import org.kde.pipewire as Pipewire
import qs.utils

import Caelestia.Layouts

Item {
    id: root

    property var cardItems: []
    property var activeInfoClient: null
    property var panels: null
    
    signal requestWindowInfo(var client)
    signal requestClose()

    readonly property int activeWsId: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.activeId : 1

    function syncPage() {
        if (typeof KWinWorkspaceState === "undefined") return;
        for (let i = 0; i < KWinWorkspaceState.workspaces.length; ++i) {
            const wId = KWinWorkspaceState.workspaces[i].index;
            if (wId === activeWsId) {
                listView.currentIndex = i;
                break;
            }
        }
    }

    onActiveWsIdChanged: syncPage()
    Component.onCompleted: syncPage()

    property bool isDragging: false
    
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
        highlightMoveDuration: 250
        boundsBehavior: Flickable.StopAtBounds
        
        onCountChanged: root.syncPage()
        
        onCurrentIndexChanged: {
            if (typeof KWinWorkspaceState !== "undefined" && KWinWorkspaceState.workspaces.length > currentIndex) {
                const wId = KWinWorkspaceState.workspaces[currentIndex].index;
                if (KWinWorkspaceState.activeId !== wId) {
                    KWinWorkspaceState.switchTo(wId);
                }
            }
        }
        
        model: typeof KWinWorkspaceState !== "undefined" ? KWinWorkspaceState.workspaces.length : 1
        
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

        delegate: Item {
            id: page
            width: listView.width
            height: listView.height

            TapHandler {
                onTapped: root.requestClose()
            }

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
            
            Component.onCompleted: {
                console.log("WindowGrid Page initialized. wsId:", wsId, "windows found:", wsWindows.length, "Total windows globally:", typeof KWinActiveWindowBridge !== "undefined" ? KWinActiveWindowBridge.windowList.length : -1);
            }
            onWsWindowsChanged: {
                console.log("WindowGrid Page updated. wsId:", wsId, "windows found:", wsWindows.length);
            }

            Item {
                id: gridItem
                anchors.fill: parent
                
                property var windowLayout: LayoutGnome.calculateLayout(page.wsWindows, width, height, Tokens.spacing.large, Tokens.spacing.large)
                
                // Behaviors for smooth resizing of the whole container if needed (though it fills parent)
                
                Repeater {
                    model: page.wsWindows
                    
                    delegate: StyledRect {
                        id: activeWin
                        required property var modelData
                        
                        readonly property string clientAddress: modelData.address
                        readonly property string wsId: page.wsId
                            
                            Drag.active: dragHandler.active
                            Drag.source: activeWin
                            Drag.hotSpot: dragHandler.centroid.position
                            
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
                                        if (typeof KWinWorkspaceState === "undefined" || typeof KWinActiveWindowBridge === "undefined") return;
                                        const targetWsId = KWinWorkspaceState.workspaces[listView.currentIndex].index;
                                        if (targetWsId !== page.wsId) {
                                            activeWin.visible = false;
                                            KWinActiveWindowBridge.setWindowDesktop(clientAddress, targetWsId);
                                        }
                                    }
                                }
                            }
                            
                            readonly property var layoutProps: gridItem.windowLayout && gridItem.windowLayout[modelData.address] ? gridItem.windowLayout[modelData.address] : { x: 0, y: 0, width: 200, height: 150 }
                            
                            x: dragHandler.active ? x : layoutProps.x
                            y: dragHandler.active ? y : layoutProps.y
                            
                            Behavior on x { enabled: !dragHandler.active && root.opacity > 0.5; NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            Behavior on y { enabled: !dragHandler.active && root.opacity > 0.5; NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            
                            readonly property int cardWidth: layoutProps.width
                            readonly property int thumbHeight: layoutProps.height
                            
                            readonly property real windowAspect: {
                                const w = modelData.width;
                                const h = modelData.height;
                                return (w > 0 && h > 0) ? (w / h) : (16.0 / 10.0);
                            }
                            
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
                                    Layout.preferredWidth: activeWin.cardWidth
                                    Layout.preferredHeight: activeWin.thumbHeight
                                    color: Colours.tPalette.m3surfaceContainerHighest
                                    radius: Tokens.rounding.large
                                    
                                    property var streamRequest: null
                                    
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
                                    
                                    Connections {
                                        target: root
                                        function onOpacityChanged() {
                                            thumb.updateStream();
                                        }
                                        function onActiveInfoClientChanged() {
                                            thumb.updateStream();
                                        }
                                    }
                                    
                                    Component.onCompleted: updateStream()
                                    
                                    Component.onDestruction: {
                                        if (streamRequest && modelData.address) {
                                            ScreencastManager.releaseStream(modelData.address);
                                        }
                                    }
                                    
                                    readonly property int screencastSerial: streamRequest ? streamRequest.objectSerial : 0
                                    
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
                                }
                                
                                StyledText {
                                    id: titleText
                                    Layout.preferredWidth: activeWin.cardWidth
                                    text: modelData.title || ""
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
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
            count: listView.count
            currentIndex: listView.currentIndex
            onWorkspaceSelected: index => listView.currentIndex = index
            onWorkspaceReselected: root.requestClose()
        }
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
