pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.bar.components as BarComponents
import qs.modules.nexus.common

PageBase {
    id: root

    title: I18n.tr("Toggle & rearrange")
    isSubPage: true
    scrollable: true

    readonly property var componentMeta: {
        "logo": { icon: "rocket_launch", name: I18n.tr("Logo") },
        "workspaces": { icon: "workspaces", name: I18n.tr("Workspaces") },
        "github": {
            icon: "commit",
            name: I18n.tr("GitHub"),
            available: BarComponents.GithubStore.available,
            unavailableText: I18n.tr("GitHub token not detected")
        },
        "activeWindow": { icon: "dock_to_right", name: I18n.tr("Active window") },
        "tray": { icon: "expand_more", name: I18n.tr("System tray") },
        "updateIndicator": { icon: "update", name: I18n.tr("Updates") },
        "clock": { icon: "schedule", name: I18n.tr("Clock") },
        "statusIcons": { icon: "wifi", name: I18n.tr("Status icons") },
        "kbLayoutIndicator": { icon: "keyboard", name: I18n.tr("Keyboard layout") },
        "notificationsIndicator": { icon: "notifications", name: I18n.tr("Notifications") },
        "perfCpu": { icon: "memory", name: I18n.tr("CPU"), available: Cpu.name.length > 0, unavailableText: I18n.tr("CPU sensor not detected") },
        "perfMemory": { icon: "memory_alt", name: I18n.tr("Memory"), available: Memory.total > 1, unavailableText: I18n.tr("Memory sensor not detected") },
        "perfStorage": { icon: "hard_disk", name: I18n.tr("Storage"), available: Storage.disks.length > 0, unavailableText: I18n.tr("Storage disks not detected") },
        "perfNetwork": { icon: "swap_vert", name: I18n.tr("Network") },
        "perfGpu": { icon: "desktop_windows", name: I18n.tr("GPU"), available: Gpu.type !== Gpu.None, unavailableText: I18n.tr("GPU not detected") },
        "perfBattery": { icon: "battery_full", name: I18n.tr("Battery"), available: UPower.displayDevice.isLaptopBattery, unavailableText: I18n.tr("Battery not detected") },
        "dock": { icon: "apps", name: I18n.tr("Dock") },
        "showDesktop": { icon: "keyboard_double_arrow_down", name: I18n.tr("Show Desktop") },
        "power": { icon: "power_settings_new", name: I18n.tr("Power menu") }
    }

    property bool isGlobalDragging: false

    property string globalDragSourceList: ""

    property int globalDragSourceIndex: -1

    property string globalDragHoveredList: ""

    readonly property real zonePadding: Tokens.padding.medium

    readonly property real emptyZoneHeight: 72

    function getModel(name) {
        if (name === "left") return leftModel;
        if (name === "middle") return middleModel;
        if (name === "right") return rightModel;
        if (name === "library") return libraryModel;
        return null;
    }

    function load() {
        let entries = Config.bar.entries;
        leftModel.clear();
        middleModel.clear();
        rightModel.clear();
        libraryModel.clear();

        let activeCounts = {};
        for (let i = 0; i < entries.length; i++) {
            let entry = entries[i];
            if (entry.id === "spacer") continue;
            
            activeCounts[entry.id] = (activeCounts[entry.id] || 0) + 1;
            
            if (entry.enabled) {
                let zone = entry.zone || "left";
                if (zone === "left") leftModel.append({ "compId": entry.id, "isPlaceholder": false });
                else if (zone === "middle") middleModel.append({ "compId": entry.id, "isPlaceholder": false });
                else if (zone === "right") rightModel.append({ "compId": entry.id, "isPlaceholder": false });
            } else {
                libraryModel.append({ "compId": entry.id, "isPlaceholder": false });
            }
        }

        for (let key in componentMeta) {
            if (!activeCounts[key]) {
                libraryModel.append({ "compId": key, "isPlaceholder": false });
            }
        }
    }

    function defaultEntries() {
        return [
            { id: "logo", enabled: true, zone: "left" },
            { id: "workspaces", enabled: true, zone: "left" },
            { id: "activeWindow", enabled: true, zone: "left" },
            { id: "dock", enabled: true, zone: "middle" },
            { id: "tray", enabled: true, zone: "right" },
            { id: "updateIndicator", enabled: true, zone: "right" },
            { id: "github", enabled: true, zone: "right" },
            { id: "clock", enabled: true, zone: "right" },
            { id: "statusIcons", enabled: true, zone: "right" },
            { id: "kbLayoutIndicator", enabled: false, zone: "right" },
            { id: "notificationsIndicator", enabled: false, zone: "right" },
            { id: "perfCpu", enabled: false, zone: "right" },
            { id: "perfMemory", enabled: false, zone: "right" },
            { id: "perfStorage", enabled: false, zone: "right" },
            { id: "perfNetwork", enabled: false, zone: "right" },
            { id: "perfGpu", enabled: false, zone: "right" },
            { id: "perfBattery", enabled: false, zone: "right" },
            { id: "showDesktop", enabled: true, zone: "right" },
            { id: "power", enabled: true, zone: "right" }
        ];
    }

    function resetToDefaults() {
        const entries = defaultEntries();
        GlobalConfig.bar.entries = entries;

        leftModel.clear();
        middleModel.clear();
        rightModel.clear();
        libraryModel.clear();

        for (const entry of entries) {
            if (!entry.enabled) {
                libraryModel.append({ compId: entry.id, isPlaceholder: false });
                continue;
            }

            const zone = entry.zone || "left";
            if (zone === "left")
                leftModel.append({ compId: entry.id, isPlaceholder: false });
            else if (zone === "middle")
                middleModel.append({ compId: entry.id, isPlaceholder: false });
            else
                rightModel.append({ compId: entry.id, isPlaceholder: false });
        }
    }

    function save() {
        let newEntries = [];
        
        for (let i = 0; i < leftModel.count; i++) {
            if (!leftModel.get(i).isPlaceholder) {
                newEntries.push({ id: leftModel.get(i).compId, enabled: true, zone: "left" });
            }
        }
        for (let i = 0; i < middleModel.count; i++) {
            if (!middleModel.get(i).isPlaceholder) {
                newEntries.push({ id: middleModel.get(i).compId, enabled: true, zone: "middle" });
            }
        }
        for (let i = 0; i < rightModel.count; i++) {
            if (!rightModel.get(i).isPlaceholder) {
                newEntries.push({ id: rightModel.get(i).compId, enabled: true, zone: "right" });
            }
        }
        for (let i = 0; i < libraryModel.count; i++) {
            if (!libraryModel.get(i).isPlaceholder) {
                newEntries.push({ id: libraryModel.get(i).compId, enabled: false, zone: "left" });
            }
        }
        
        GlobalConfig.bar.entries = newEntries;
    }

    Component.onCompleted: load()

    RowLayout {
        ListModel { id: leftModel }
        ListModel { id: middleModel }
        ListModel { id: rightModel }
        ListModel { id: libraryModel }

        anchors.fill: parent

        anchors.margins: Tokens.padding.large

        spacing: Tokens.spacing.large

        // Left Side: Active Components Zones
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spacing.medium

            Text {
                text: I18n.tr("Active components")
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            Text {
                text: I18n.tr("Drag to rearrange or disable")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
            
            // Left Zone
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Math.max(root.emptyZoneHeight, leftList.contentHeight + root.zonePadding * 2)
                color: Colours.palette.m3surfaceContainer
                radius: Tokens.rounding.large
                
                Text {
                    text: I18n.tr("Left Zone")
                    font: Tokens.font.label.large
                    color: Colours.palette.m3onSurfaceVariant
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.small
                    visible: leftModel.count === 0 || (leftModel.count === 1 && leftModel.get(0).isPlaceholder)
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["component"]
                    onEntered: drag => {
                        let sourceItem = drag.source;
                        if (!sourceItem) return;
                        root.globalDragHoveredList = "left";
                        
                        if (sourceItem.sourceList !== "left") {
                            let hasPlaceholder = false;
                            for (let i = 0; i < leftModel.count; i++) {
                                if (leftModel.get(i).isPlaceholder) hasPlaceholder = true;
                            }
                            if (!hasPlaceholder) {
                                leftModel.append({ compId: sourceItem.compId, isPlaceholder: true });
                            }
                        }
                    }
                }

                ListView {
                    id: leftList

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    orientation: ListView.Vertical
                    spacing: Tokens.spacing.small
                    model: leftModel
                    clip: true

                    move: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    delegate: root.panelDelegate
                }
            }
            
            // Middle Zone
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Math.max(root.emptyZoneHeight, middleList.contentHeight + root.zonePadding * 2)
                color: Colours.palette.m3surfaceContainer
                radius: Tokens.rounding.large
                
                Text {
                    text: I18n.tr("Middle Zone")
                    font: Tokens.font.label.large
                    color: Colours.palette.m3onSurfaceVariant
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.small
                    visible: middleModel.count === 0 || (middleModel.count === 1 && middleModel.get(0).isPlaceholder)
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["component"]
                    onEntered: drag => {
                        let sourceItem = drag.source;
                        if (!sourceItem) return;
                        root.globalDragHoveredList = "middle";
                        
                        if (sourceItem.sourceList !== "middle") {
                            let hasPlaceholder = false;
                            for (let i = 0; i < middleModel.count; i++) {
                                if (middleModel.get(i).isPlaceholder) hasPlaceholder = true;
                            }
                            if (!hasPlaceholder) {
                                middleModel.append({ compId: sourceItem.compId, isPlaceholder: true });
                            }
                        }
                    }
                }

                ListView {
                    id: middleList

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    orientation: ListView.Vertical
                    spacing: Tokens.spacing.small
                    model: middleModel
                    clip: true

                    move: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    delegate: root.panelDelegate
                }
            }
            
            // Right Zone
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Math.max(root.emptyZoneHeight, rightList.contentHeight + root.zonePadding * 2)
                color: Colours.palette.m3surfaceContainer
                radius: Tokens.rounding.large
                
                Text {
                    text: I18n.tr("Right Zone")
                    font: Tokens.font.label.large
                    color: Colours.palette.m3onSurfaceVariant
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.small
                    visible: rightModel.count === 0 || (rightModel.count === 1 && rightModel.get(0).isPlaceholder)
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["component"]
                    onEntered: drag => {
                        let sourceItem = drag.source;
                        if (!sourceItem) return;
                        root.globalDragHoveredList = "right";
                        
                        if (sourceItem.sourceList !== "right") {
                            let hasPlaceholder = false;
                            for (let i = 0; i < rightModel.count; i++) {
                                if (rightModel.get(i).isPlaceholder) hasPlaceholder = true;
                            }
                            if (!hasPlaceholder) {
                                rightModel.append({ compId: sourceItem.compId, isPlaceholder: true });
                            }
                        }
                    }
                }

                ListView {
                    id: rightList

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    orientation: ListView.Vertical
                    spacing: Tokens.spacing.small
                    model: rightModel
                    clip: true

                    move: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    delegate: root.panelDelegate
                }
            }
        }

        // Right Side: Library
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                ColumnLayout {
                    spacing: 0
                    
                    Text {
                        text: I18n.tr("Library")
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurface
                    }

                    Text {
                        text: I18n.tr("Disabled components")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                TextButton {
                    text: I18n.tr("RESET")
                    type: TextButton.Filled
                    ToolTip.text: I18n.tr("Restore the default taskbar component layout")
                    ToolTip.visible: hovered
                    onClicked: root.resetToDefaults()
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: Math.max(root.emptyZoneHeight, libList.contentHeight + root.zonePadding * 2)
                color: "transparent"
                
                Text {
                    text: I18n.tr("Empty")
                    font: Tokens.font.label.large
                    color: Colours.palette.m3onSurfaceVariant
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.small
                    visible: libraryModel.count === 0 || (libraryModel.count === 1 && libraryModel.get(0).isPlaceholder)
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["component"]
                    onEntered: drag => {
                        let sourceItem = drag.source;
                        if (!sourceItem) return;
                        
                        root.globalDragHoveredList = "library";
                        
                        if (sourceItem.sourceList !== "library") {
                            let hasPlaceholder = false;
                            for (let i = 0; i < libraryModel.count; i++) {
                                if (libraryModel.get(i).isPlaceholder) hasPlaceholder = true;
                            }
                            if (!hasPlaceholder) {
                                libraryModel.append({ compId: sourceItem.compId, isPlaceholder: true });
                            }
                        }
                    }
                }

                ListView {
                    id: libList

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    orientation: ListView.Vertical
                    spacing: Tokens.spacing.small
                    model: libraryModel
                    clip: true

                    move: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                    moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }

                    delegate: root.panelDelegate
                }
            }
        }
    }

    property Component panelDelegate: Component {
        
        Item {
            id: delegateWrapper

            required property int index
            required property string compId
            required property bool isPlaceholder
            readonly property bool isAvailable: (componentMeta[compId]?.available ?? true)
            
            property string sourceList: {
                if (ListView.view === leftList) return "left";
                if (ListView.view === middleList) return "middle";
                if (ListView.view === rightList) return "right";
                return "library";
            }
            
            width: ListView.view.width
            height: (root.isGlobalDragging && root.globalDragSourceList === sourceList && root.globalDragSourceIndex === index && root.globalDragHoveredList !== sourceList) ? 0 : 50
            visible: height > 0
            
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            
            property bool isDraggingThis: activeDragArea.drag.active

            z: isDraggingThis ? 100 : 1

            DropArea {
                anchors.fill: parent
                keys: ["component"]
                onEntered: drag => {
                    let sourceItem = drag.source;
                    if (!sourceItem) return;
                    
                    let from = -1;
                    let to = delegateWrapper.index;
                    let targetModel = root.getModel(sourceList);
                    
                    if (sourceItem.sourceList === sourceList) {
                        from = root.globalDragSourceIndex;
                    } else {
                        for (let i = 0; i < targetModel.count; i++) {
                            if (targetModel.get(i).isPlaceholder) { from = i; break; }
                        }
                    }
                    
                    if (from !== -1 && to !== -1 && from !== to) {
                        targetModel.move(from, to, 1);
                        if (sourceItem.sourceList === sourceList) {
                            root.globalDragSourceIndex = to;
                        }
                    }
                }
            }

            StyledRect {
                id: activeDelegate

                width: delegateWrapper.width
                height: 50
                color: isDraggingThis ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) : (sourceList !== "library" ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer)
                radius: Tokens.rounding.medium
                border.color: isDraggingThis ? Colours.palette.m3outline : (sourceList === "library" ? Colours.palette.m3outlineVariant : "transparent")
                border.width: isDraggingThis ? 2 : (sourceList === "library" ? 1 : 0)
                opacity: isPlaceholder ? 0.2 : (delegateWrapper.isAvailable ? 1.0 : 0.55)

                MouseArea {
                    id: activeDragArea

                    anchors.fill: parent
                    hoverEnabled: true
                    drag.target: isPlaceholder || !delegateWrapper.isAvailable ? null : activeDelegate
                    drag.axis: Drag.XAndYAxis
                    
                    onPressed: {
                        if (isPlaceholder || !delegateWrapper.isAvailable) return;
                        root.isGlobalDragging = true;
                        root.globalDragSourceList = sourceList;
                        root.globalDragSourceIndex = index;
                        root.globalDragHoveredList = sourceList;
                    }
                    
                    onReleased: {
                        if (isPlaceholder || !delegateWrapper.isAvailable) return;
                        
                        let finalHovered = root.globalDragHoveredList;
                        root.isGlobalDragging = false;
                        
                        let targetModel = root.getModel(finalHovered);
                        let sourceModel = root.getModel(sourceList);
                        
                        if (finalHovered !== sourceList && finalHovered !== "" && targetModel) {
                            let pIndex = -1;
                            for (let i = 0; i < targetModel.count; i++) {
                                if (targetModel.get(i).isPlaceholder) { pIndex = i; break; }
                            }
                            
                            let proceed = true;
                            
                            if (pIndex !== -1 && proceed) {
                                targetModel.remove(pIndex);
                                targetModel.insert(pIndex, { compId: compId, isPlaceholder: false });
                                sourceModel.remove(root.globalDragSourceIndex);
                            }
                        }
                        
                        for (let i = leftModel.count - 1; i >= 0; i--) {
                            if (leftModel.get(i).isPlaceholder) leftModel.remove(i);
                        }
                        for (let i = middleModel.count - 1; i >= 0; i--) {
                            if (middleModel.get(i).isPlaceholder) middleModel.remove(i);
                        }
                        for (let i = rightModel.count - 1; i >= 0; i--) {
                            if (rightModel.get(i).isPlaceholder) rightModel.remove(i);
                        }
                        for (let i = libraryModel.count - 1; i >= 0; i--) {
                            if (libraryModel.get(i).isPlaceholder) libraryModel.remove(i);
                        }
                        
                        activeDelegate.x = 0;
                        activeDelegate.y = 0;
                        save();
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    acceptedButtons: Qt.NoButton
                    color: Colours.palette.m3onSurface
                    opacity: activeDragArea.containsMouse && !isPlaceholder && !isDraggingThis ? 0.08 : 0

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.small
                    visible: !isPlaceholder
                    
                    MaterialIcon {
                        text: componentMeta[compId]?.icon ?? "widgets"
                        color: sourceList !== "library" ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: {
                            const base = componentMeta[compId]?.name ?? compId;
                            if (delegateWrapper.isAvailable)
                                return base;
                            const reason = componentMeta[compId]?.unavailableText ?? I18n.tr("Not detected");
                            return `${base} (${reason})`;
                        }
                        font: Tokens.font.body.small
                        color: sourceList !== "library" ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    }

                    MaterialIcon {
                        text: "drag_indicator"
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Drag.active: activeDragArea.drag.active
                Drag.source: delegateWrapper
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2
                Drag.keys: ["component"]

                states: State {
                    when: activeDragArea.drag.active

                    ParentChange { target: activeDelegate; parent: root.flickable.contentItem }
                    PropertyChanges { target: activeDelegate; scale: 1.05 }
                }
            }
        }
    }
}
