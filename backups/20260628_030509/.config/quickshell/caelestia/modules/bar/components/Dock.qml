pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight

    required property var bar

    property int modelUpdateTrigger: 0

    property var launchingApps: ({})

    ListModel { id: dockModel }

    function saveNewOrder(): void {
        const newArr = [];
        const newFavs = [];
        
        for (let i = 0; i < root.currentOrder.length; ++i) {
            const mData = root.currentOrder[i];
            if (!mData) continue;
            
            if (mData.isPinned) {
                newFavs.push(mData.id);
            }
            newArr.push(mData);
        }
        
        // Only update if arrays are different length or different order
        const currentFavs = GlobalConfig.launcher.favouriteApps || [];
        let changed = currentFavs.length !== newFavs.length;
        if (!changed) {
            for (let i = 0; i < newFavs.length; i++) {
                if (currentFavs[i] !== newFavs[i]) {
                    changed = true;
                    break;
                }
            }
        }
        
        if (changed) {
            GlobalConfig.launcher.favouriteApps = newFavs;
        }

        root.modelDataArray = newArr;
    }

    readonly property int padding: Tokens.padding.medium
    readonly property int spacing: Tokens.spacing.small

    anchors.fill: parent

    StyledRect {
        id: container

        color: root.modelDataArray.length > 0 ? Colours.tPalette.m3surfaceContainer : "transparent"
        radius: Tokens.rounding.full

        implicitWidth: bar.isHorizontal ? layout.implicitWidth + padding * 2 : Tokens.sizes.bar.innerWidth
        implicitHeight: bar.isHorizontal ? Tokens.sizes.bar.innerWidth : layout.implicitHeight + padding * 2
        
        property real itemSize: Tokens.sizes.bar.innerWidth * 0.8
        property int maxHorizontalItems: Math.floor((root.width - padding * 2 - itemSize * 0.5) / (itemSize + spacing))
        property real maxHorizontalSize: maxHorizontalItems >= 1 ? ((maxHorizontalItems + 0.5) * itemSize + maxHorizontalItems * spacing + padding * 2) : root.width
        
        property int maxVerticalItems: Math.floor((root.height - padding * 2 - itemSize * 0.5) / (itemSize + spacing))
        property real maxVerticalSize: maxVerticalItems >= 1 ? ((maxVerticalItems + 0.5) * itemSize + maxVerticalItems * spacing + padding * 2) : root.height

        width: bar.isHorizontal ? (implicitWidth > root.width + 1 ? maxHorizontalSize : implicitWidth) : Math.min(implicitWidth, root.width)
        height: !bar.isHorizontal ? (implicitHeight > root.height + 1 ? maxVerticalSize : implicitHeight) : Math.min(implicitHeight, root.height)

        property bool monitorCenter: Config.bar.dock.monitorCenter ?? true

        HoverHandler {
            id: dockHover
        }

        // Minimum guaranteed gap (px) between the dock container and any adjacent
        // bar element on either side. Uses bar.vPadding so it matches the outer
        // padding the first/last bar items receive, plus one spacing step.
        readonly property real _minGap: bar.vPadding + Tokens.spacing.medium

        // Dock slot's left/top edge in bar (GridLayout) coordinate space.
        // GridLayout sets root.parent.x after layout; Connections ensures we get
        // the post-layout value even if the reactive binding evaluates too early.
        property real _slotX: root.parent ? root.parent.x : 0
        property real _slotY: root.parent ? root.parent.y : 0

        // Dynamic bounds to prevent overlapping non-spacer siblings
        property real _minBoundLeft: 0
        property real _maxBoundRight: bar.width
        property real _minBoundTop: 0
        property real _maxBoundBottom: bar.height

        function _updateBounds() {
            if (!root.parent || !bar.children) return;
            const children = bar.children;
            let dockIdx = -1;
            for (let i = 0; i < children.length; i++) {
                if (children[i] === root.parent) {
                    dockIdx = i;
                    break;
                }
            }
            if (dockIdx === -1) return;

            const minG = bar.vPadding;
            let minTop = minG;
            let minLeft = minG;
            let maxBottom = bar.height - minG;
            let maxRight = bar.width - minG;

            const idealAbsX = bar.isHorizontal ? (bar.width / 2) : 0;
            const idealAbsY = !bar.isHorizontal ? (bar.height / 2) : 0;

            for (let i = 0; i < children.length; i++) {
                if (i === dockIdx) continue;
                const child = children[i];
                if (child.visible && child.width > 0 && child.height > 0 && child.sourceComponent) {
                    const itemW = (child.item && child.item.implicitWidth > 0) ? child.item.implicitWidth : child.width;
                    const itemH = (child.item && child.item.implicitHeight > 0) ? child.item.implicitHeight : child.height;

                    if (bar.isHorizontal) {
                        const childRight = child.x + itemW;
                        const childLeft = child.x;
                        
                        if (childLeft < idealAbsX && childRight > idealAbsX) {
                            // Sibling overlaps the screen center. Resolve using layout order.
                            if (i < dockIdx) {
                                minLeft = Math.max(minLeft, childRight + Tokens.spacing.medium);
                            } else {
                                maxRight = Math.min(maxRight, childLeft - Tokens.spacing.medium);
                            }
                        } else if (childRight <= idealAbsX) {
                            // Sibling is strictly to the left of center
                            minLeft = Math.max(minLeft, childRight + Tokens.spacing.medium);
                        } else {
                            // Sibling is strictly to the right of center
                            maxRight = Math.min(maxRight, childLeft - Tokens.spacing.medium);
                        }
                    } else {
                        const childBottom = child.y + itemH;
                        const childTop = child.y;
                        
                        if (childTop < idealAbsY && childBottom > idealAbsY) {
                            if (i < dockIdx) {
                                minTop = Math.max(minTop, childBottom + Tokens.spacing.medium);
                            } else {
                                maxBottom = Math.min(maxBottom, childTop - Tokens.spacing.medium);
                            }
                        } else if (childBottom <= idealAbsY) {
                            minTop = Math.max(minTop, childBottom + Tokens.spacing.medium);
                        } else {
                            maxBottom = Math.min(maxBottom, childTop - Tokens.spacing.medium);
                        }
                    }
                }
            }

            _minBoundTop = minTop;
            _maxBoundBottom = maxBottom;
            _minBoundLeft = minLeft;
            _maxBoundRight = maxRight;
        }

        Connections {
            target: root.parent
            function onXChanged() { container._slotX = root.parent ? root.parent.x : 0; Qt.callLater(container._updateBounds) }
            function onYChanged() { container._slotY = root.parent ? root.parent.y : 0; Qt.callLater(container._updateBounds) }
        }
        Connections {
            target: bar
            function onWidthChanged()  { Qt.callLater(() => { container._slotX = root.parent ? root.parent.x : 0; container._updateBounds() }) }
            function onHeightChanged() { Qt.callLater(() => { container._slotY = root.parent ? root.parent.y : 0; container._updateBounds() }) }
        }

        // Physical screen centre expressed in dock-slot-local coordinates.
        readonly property real _centerInSlot: bar.isHorizontal
            ? (bar.width  / 2 - _slotX)
            : (bar.height / 2 - _slotY)

        // Centre container at physical screen centre.
        // Priority order (highest to lowest):
        //   1. dynamic bounds — dock must NEVER overlap adjacent non-spacer widgets
        //   2. ideal    — dock is centred at physical screen centre
        // The container can overflow its GridLayout slot into adjacent spacers to
        // reach screen centre; if it grows large, both sides expand from centre
        // until one hits the dynamic bound, then only the other side keeps growing.
        x: {
            if (!bar.isHorizontal || !monitorCenter) return (root.parent ? root.parent.width : root.width) / 2 - width / 2;
            const ideal = _centerInSlot - width / 2;
            // Convert bar-coord bounds to slot-local coords
            const minX = _minBoundLeft - _slotX;
            const maxX = _maxBoundRight - _slotX - width;
            return Math.max(minX, Math.min(ideal, maxX));
        }
        y: {
            if (bar.isHorizontal || !monitorCenter) return (root.parent ? root.parent.height : root.height) / 2 - height / 2;
            const ideal = _centerInSlot - height / 2;
            const minY = _minBoundTop - _slotY;
            const maxY = _maxBoundBottom - _slotY - height;
            return Math.max(minY, Math.min(ideal, maxY));
        }

        property var _appsValues: DesktopEntries.applications.values
        on_AppsValuesChanged: root.rebuildModel()

        Behavior on implicitWidth {
            enabled: bar.isHorizontal

            Anim { type: Anim.DefaultSpatial }
        }

        Behavior on implicitHeight {
            enabled: !bar.isHorizontal

            Anim { type: Anim.DefaultSpatial }
        }

        Item {
            id: layout
            
            anchors.centerIn: parent
            implicitWidth: listView.contentWidth
            implicitHeight: listView.contentHeight

            ListView {
                id: listView

                anchors.centerIn: parent
                width: bar.isHorizontal ? Math.min(contentWidth, container.width - padding * 2) : Tokens.sizes.bar.innerWidth * 0.8
                height: bar.isHorizontal ? Tokens.sizes.bar.innerWidth * 0.8 : Math.min(contentHeight, container.height - padding * 2)
                orientation: bar.isHorizontal ? ListView.Horizontal : ListView.Vertical
                spacing: root.spacing
                interactive: bar.isHorizontal ? contentWidth > width + 1 : contentHeight > height + 1
                clip: true

                add: Transition {
                    NumberAnimation { property: "scale"; from: 0; to: 1; duration: 250; easing.type: Easing.OutBack }
                }
                remove: Transition {
                    NumberAnimation { property: "scale"; from: 1; to: 0; duration: 250; easing.type: Easing.InBack }
                }

                move: Transition {
                    NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
                }
                moveDisplaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
                }
                
                model: DelegateModel {
                    id: visualModel

                    model: dockModel
                    delegate: dockDelegate
                }
            }

            StyledScrollBar {
                flickable: listView
                orientation: Qt.Horizontal
                size: listView.visibleArea.widthRatio
                position: listView.visibleArea.xPosition
                shouldBeActive: dockHover.hovered || listView.moving
                anchors.left: listView.left
                anchors.right: listView.right
                anchors.bottom: listView.bottom
                anchors.bottomMargin: -root.padding + 2
                visible: bar.isHorizontal && listView.contentWidth > listView.width + 1
            }

            StyledScrollBar {
                flickable: listView
                orientation: Qt.Vertical
                size: listView.visibleArea.heightRatio
                position: listView.visibleArea.yPosition
                shouldBeActive: dockHover.hovered || listView.moving
                anchors.top: listView.top
                anchors.bottom: listView.bottom
                anchors.right: listView.right
                anchors.rightMargin: -root.padding + 2
                visible: !bar.isHorizontal && listView.contentHeight > listView.height + 1
            }
        }

        Component {
            id: dockDelegate

            Item {
                id: delegateContainer

                width: Tokens.sizes.bar.innerWidth * 0.8
                height: Tokens.sizes.bar.innerWidth * 0.8
                implicitWidth: width
                implicitHeight: height

                property var modelData: root.modelDataArray[index]

                required property int index

                DropArea {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    onEntered: drag => {
                        const from = drag.source.delegateIndex;
                        const to = delegateContainer.index;
                        if (from !== undefined && to !== undefined && from !== to) {
                            dockModel.move(from, to, 1);
                            const movedItem = root.currentOrder.splice(from, 1)[0];
                            root.currentOrder.splice(to, 0, movedItem);
                        }
                    }
                    onDropped: drag => {
                        root.saveNewOrder();
                    }
                }

                Item {
                    id: delegateItem

                    width: delegateContainer.width
                    height: delegateContainer.height

                    property int delegateIndex: delegateContainer.index

                    Drag.active: dragArea.held
                    Drag.source: delegateItem
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    StateLayer {
                        id: stateLayer

                        anchors.fill: parent
                        radius: Tokens.rounding.medium

                        color: delegateItem.isActive ? Colours.palette.m3onSurface : "transparent"
                        opacity: delegateItem.isActive ? 0.1 : 0

                        acceptedButtons: Qt.NoButton

                        onEntered: {
                            if (bar.popouts.hasCurrent && bar.popouts.currentName === "dockcontext") return;
                            bar.popouts.currentName = "dockhover";
                            bar.popouts.currentCenter = bar.isHorizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                            bar.popouts.dockModel = modelData;
                            bar.popouts.hasCurrent = true;
                        }
                    }

                    MouseArea {
                        id: dragArea

                        property bool held: false

                        anchors.fill: parent
                        drag.target: held ? delegateItem : null
                        drag.axis: bar.isHorizontal ? Drag.XAxis : Drag.YAxis
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        
                        onPressed: mouse => {
                            held = true;
                            stateLayer.press(mouse.x, mouse.y);
                        }
                        
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (modelData.isPinned) {
                                    bounceAnim.start();
                                }
                                
                                if (modelData.toplevels.length > 0) {
                                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.toplevels[0].address}" })` : `focuswindow address:0x${modelData.toplevels[0].address}`);
                                } else if (modelData.entry) {
                                    // Mark as launching
                                    let newLaunching = Object.assign({}, root.launchingApps);
                                    newLaunching[modelData.appClass || modelData.id] = true;
                                    root.launchingApps = newLaunching;
                                    
                                    const subCmd = modelData.entry.runInTerminal
                                        ? [...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...modelData.entry.command]
                                        : modelData.entry.command;
                                    const finalCmd = GlobalConfig.services.useSystemd ? ["app2unit", "--", ...subCmd] : subCmd;
                                    Quickshell.execDetached({
                                        command: finalCmd,
                                        workingDirectory: modelData.entry.workingDirectory
                                    });
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                bar.popouts.currentName = "dockcontext";
                                bar.popouts.currentCenter = bar.isHorizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                                bar.popouts.dockModel = modelData;
                                bar.popouts.hasCurrent = true;
                            }
                        }
                        
                        onReleased: {
                            held = false;
                            delegateItem.x = 0;
                            delegateItem.y = 0;
                            root.saveNewOrder();
                        }
                    }

                    states: [
                        State {
                            when: dragArea.held

                            ParentChange {
                                target: delegateItem
                                parent: listView
                            }
                            PropertyChanges {
                                target: delegateItem
                                opacity: 0.8
                                z: 999
                            }
                        }
                    ]

                    property bool isActive: {
                        const dummy = root.modelUpdateTrigger;
                        for (const top of modelData.toplevels) {
                            if (top.focused) return true;
                        }
                        return false;
                    }

                    property bool hasWindows: {
                        const dummy = root.modelUpdateTrigger;
                        return modelData.toplevels.length > 0;
                    }



                    IconImage {
                        id: icon

                        anchors.centerIn: parent
                        implicitSize: Math.round(((delegateItem.width || 0) * 0.7) / 2) * 2 || 0
                        source: {
                            if (modelData.entry && modelData.entry.icon) {
                                return Quickshell.iconPath(modelData.entry.icon, "image-missing");
                            }
                            return Quickshell.iconPath(modelData.iconName, "image-missing");
                        }
                        asynchronous: true
                        visible: !(Config.bar.dock.recolourIcons ?? false)
                        
                        SequentialAnimation {
                            id: bounceAnim

                            NumberAnimation { target: delegateItem; property: "scale"; to: 0.7; duration: 100; easing.type: Easing.OutQuad }
                            NumberAnimation { target: delegateItem; property: "scale"; to: 1.0; duration: 400; easing.type: Easing.OutElastic }
                        }
                    }

                    ColouredIcon {
                        anchors.fill: icon
                        source: icon.source
                        colour: Colours.palette.m3secondary
                        layer.enabled: true
                        visible: Config.bar.dock.recolourIcons ?? false
                    }

                    Loader {
                        anchors.fill: icon
                        active: root.launchingApps[modelData.appClass || modelData.id] || false
                        sourceComponent: CircularIndicator {
                            running: true
                            strokeWidth: 2
                        }
                    }

                    ListView {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 0
                        spacing: 2
                        orientation: ListView.Horizontal
                        interactive: false
                        
                        height: 2
                        width: contentWidth
                        
                        remove: Transition {
                            NumberAnimation { property: "scale"; from: 1; to: 0; duration: 250; easing.type: Easing.InBack }
                            NumberAnimation { property: "y"; from: 0; to: -15; duration: 250; easing.type: Easing.InBack }
                        }
                        addDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
                        }
                        removeDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutCubic }
                        }
                        
                        model: {
                            const dummy = root.modelUpdateTrigger;
                            return Math.min(2, modelData.toplevels.length);
                        }
                        
                        delegate: Rectangle {
                            required property int index

                            width: (index === 0 && delegateItem.isActive) ? 16 : 2
    
                                height: 2
    
                                radius: 1
    
                                color: delegateItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface
    
                                scale: 0
                                y: -15
                                Component.onCompleted: {
                                    scale = 1;
                                    y = 0;
                                }

                                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 250 } }
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                            }
                        }
                }
            }
        }
    }

    function handleHover(relPos: real, isHorizontal: bool): void {
        // Don't close dock context menu
        if (bar.popouts.hasCurrent && bar.popouts.currentName === "dockcontext") return;

        const itemSize = Tokens.sizes.bar.innerWidth * 0.8;
        const itemWidthWithSpacing = itemSize + spacing;
        const adjustedPos = isHorizontal ? relPos - container.x - padding : relPos - container.y - padding;
        
        // Only close if cursor is completely outside dock bounds
        if (adjustedPos < 0 || adjustedPos >= modelDataArray.length * itemWidthWithSpacing) {
            bar.popouts.hasCurrent = false;
            return;
        }
        
        const index = Math.floor(adjustedPos / itemWidthWithSpacing);
        
        if (index >= 0 && index < modelDataArray.length) {
            bar.popouts.currentName = "dockhover";
            const centerOffset = index * itemWidthWithSpacing + itemSize / 2;
            const absoluteCenter = isHorizontal 
                ? container.mapToItem(null, padding + centerOffset, 0).x 
                : container.mapToItem(null, 0, padding + centerOffset).y;
            
            bar.popouts.currentCenter = absoluteCenter;
            bar.popouts.dockModel = modelDataArray[index];
            bar.popouts.hasCurrent = true;
        }
    }

    property var modelDataArray: []

    property var currentOrder: []

    onModelDataArrayChanged: currentOrder = [...modelDataArray]

    function rebuildModel(): void {
        const apps = [];

        const pinnedIds = GlobalConfig.launcher.favouriteApps || [];
        
        for (const pid of pinnedIds) {
            for (const entry of DesktopEntries.applications.values) {
                if (Strings.testRegexList([pid], entry.id)) {
                    if (!apps.some(a => a.id === entry.id)) {
                        apps.push({
                            id: entry.id,
                            isPinned: true,
                            entry: entry,
                            toplevels: [],
                            appClass: entry.id.replace(".desktop", ""),
                            iconName: entry.id
                        });
                    }
                }
            }
        }
        
        for (const toplevel of HyprlandData.windowList) {
            const ipc = toplevel;
            if (!ipc) continue;
            const appClass = ipc.class || ipc.initialClass;
            if (!appClass) continue;
            
            let found = false;
            for (const app of apps) {
                const isToplevelSteamGame = appClass.toLowerCase().startsWith("steam_app_");
                
                if (isToplevelSteamGame) {
                    if (app.appClass.toLowerCase() === appClass.toLowerCase()) {
                        app.toplevels.push(toplevel);
                        found = true;
                        break;
                    }
                } else {
                    const isAppSteamGame = app.id.toLowerCase().startsWith("steam_app_") || app.appClass.toLowerCase().startsWith("steam_app_");
                    if (isAppSteamGame) continue;

                    const baseId = app.id.toLowerCase().replace(".desktop", "");
                    if (app.appClass.toLowerCase() === appClass.toLowerCase() || 
                        app.id.toLowerCase().includes(appClass.toLowerCase()) || 
                        appClass.toLowerCase().includes(baseId)) {
                        app.toplevels.push(toplevel);
                        found = true;
                        break;
                    }
                }
            }
            
            if (!found) {
                const isToplevelSteamGame = appClass.toLowerCase().startsWith("steam_app_");
                let entry = null;
                let iconName = appClass;
                
                if (isToplevelSteamGame) {
                    const appId = appClass.substring(10);
                    iconName = `steam_icon_${appId}`;
                    entry = DesktopEntries.applications.values.find(e => e.id.toLowerCase() === `steam_app_${appId}.desktop` || e.id.toLowerCase() === `steam-${appId}.desktop`) || null;
                } else {
                    entry = DesktopEntries.heuristicLookup(appClass) || null;
                    if (!entry) {
                        entry = DesktopEntries.applications.values.find(e => {
                            const eBase = e.id.toLowerCase().replace(".desktop", "");
                            return e.id.toLowerCase().includes(appClass.toLowerCase()) || appClass.toLowerCase().includes(eBase);
                        }) || null;
                    }
                    iconName = entry ? entry.id : appClass;
                }

                apps.push({
                    id: appClass,
                    isPinned: false,
                    entry: entry,
                    toplevels: [toplevel],
                    appClass: appClass,
                    iconName: iconName
                });
            }
        }
        
        let newLaunching = Object.assign({}, root.launchingApps);
        let launchingChanged = false;

        for (const app of apps) {
            if (app.toplevels.length > 0) {
                if (newLaunching[app.appClass]) {
                    delete newLaunching[app.appClass];
                    launchingChanged = true;
                }
                if (newLaunching[app.id]) {
                    delete newLaunching[app.id];
                    launchingChanged = true;
                }
            }
        }
        
        if (launchingChanged) {
            root.launchingApps = newLaunching;
        }

        let changed = false;
        if (apps.length !== dockModel.count) {
            changed = true;
        } else {
            for (let i = 0; i < apps.length; i++) {
                if (apps[i].id !== dockModel.get(i).appId) {
                    changed = true;
                    break;
                }
            }
        }
        
        if (changed) {
            for (let i = dockModel.count - 1; i >= 0; i--) {
                let found = false;
                for (let j = 0; j < apps.length; j++) {
                    if (apps[j].id === dockModel.get(i).appId) { found = true; break; }
                }
                if (!found) {
                    dockModel.remove(i);
                }
            }
            
            for (let i = 0; i < apps.length; i++) {
                let found = false;
                for (let j = 0; j < dockModel.count; j++) {
                    if (dockModel.get(j).appId === apps[i].id) { found = true; break; }
                }
                if (!found) {
                    dockModel.append({ appId: apps[i].id });
                }
            }
            
            for (let i = 0; i < apps.length; i++) {
                let currentId = apps[i].id;
                if (dockModel.get(i).appId !== currentId) {
                    let foundIdx = -1;
                    for (let j = i + 1; j < dockModel.count; j++) {
                        if (dockModel.get(j).appId === currentId) { foundIdx = j; break; }
                    }
                    if (foundIdx !== -1) {
                        dockModel.move(foundIdx, i, 1);
                    }
                }
            }
        }
        
        root.modelDataArray = apps;
        root.modelUpdateTrigger += 1;
    }

    property var _toplevels: HyprlandData.windowList

    on_ToplevelsChanged: {
        root.rebuildModel()
        delayedRebuildTimer.restart()
    }

    Timer {
        id: delayedRebuildTimer

        interval: 100
        repeat: false
        onTriggered: root.rebuildModel()
    }

    property var activeTop: Hyprland.activeToplevel

    onActiveTopChanged: {
        root.rebuildModel()
        delayedRebuildTimer.restart()
    }

    Connections {
        target: GlobalConfig.launcher

        function onFavouriteAppsChanged(): void {
            root.rebuildModel();
        }
    }

    Component.onCompleted: root.rebuildModel()
}
