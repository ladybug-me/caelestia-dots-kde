pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Toggle & rearrange")
    isSubPage: true
    scrollable: false

    readonly property var componentMeta: {
        "logo": { icon: "rocket_launch", name: qsTr("Logo") },
        "workspaces": { icon: "workspaces", name: qsTr("Workspaces") },
        "github": { icon: "commit", name: qsTr("Github") },
        "spacer": { icon: "space_bar", name: qsTr("Spacer") },
        "activeWindow": { icon: "dock_to_right", name: qsTr("Active window") },
        "tray": { icon: "expand_more", name: qsTr("System tray") },
        "clock": { icon: "schedule", name: qsTr("Clock") },
        "statusIcons": { icon: "wifi", name: qsTr("Status icons") },
        "dock": { icon: "apps", name: qsTr("Dock") },
        "power": { icon: "power_settings_new", name: qsTr("Power menu") }
    }

    property bool isGlobalDragging: false
    property string globalDragSourceList: ""
    property int globalDragSourceIndex: -1
    property string globalDragHoveredList: ""

    function load() {
        let entries = Config.bar.entries;
        activeModel.clear();
        libraryModel.clear();

        let activeCounts = {};
        for (let i = 0; i < entries.length; i++) {
            let entry = entries[i];
            activeCounts[entry.id] = (activeCounts[entry.id] || 0) + 1;
            if (entry.enabled) {
                activeModel.append({ "compId": entry.id, "isPlaceholder": false });
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

    function save() {
        let newEntries = [];
        let oldEntries = JSON.parse(JSON.stringify(Config.bar.entries));
        
        let spacerQueue = [];
        for (let j = 0; j < oldEntries.length; j++) {
            if (oldEntries[j] && oldEntries[j].id === "spacer") {
                spacerQueue.push(oldEntries[j].size !== undefined ? oldEntries[j].size : undefined);
            }
        }
        
        for (let i = 0; i < activeModel.count; i++) {
            if (!activeModel.get(i).isPlaceholder) {
                let compId = activeModel.get(i).compId;
                
                if (compId === "spacer") {
                    let size = spacerQueue.length > 0 ? spacerQueue.shift() : undefined;
                    newEntries.push({ id: "spacer", enabled: true, size: size });
                } else {
                    let foundIndex = -1;
                    for (let j = 0; j < oldEntries.length; j++) {
                        if (oldEntries[j] && oldEntries[j].id === compId) {
                            foundIndex = j;
                            break;
                        }
                    }
                    if (foundIndex !== -1) {
                        let entry = oldEntries[foundIndex];
                        entry.enabled = true;
                        newEntries.push(entry);
                        oldEntries[foundIndex] = null;
                    } else {
                        newEntries.push({ id: compId, enabled: true });
                    }
                }
            }
        }
        GlobalConfig.bar.entries = newEntries;
    }

    Component.onCompleted: load()

    RowLayout {
        ListModel { id: activeModel }
        ListModel { id: libraryModel }

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        // Left Side: Active Components
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: Tokens.spacing.medium

            Text {
                text: qsTr("Active components")
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            Text {
                text: qsTr("Drag to rearrange or disable")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colours.palette.m3surfaceContainer
                radius: Tokens.rounding.large

                DropArea {
                    anchors.fill: parent
                    keys: ["component"]
                    onEntered: drag => {
                        let sourceItem = drag.source;
                        if (!sourceItem) return;
                        
                        root.globalDragHoveredList = "active";
                        
                        if (sourceItem.sourceList === "library") {
                            let hasPlaceholder = false;
                            for (let i = 0; i < activeModel.count; i++) {
                                if (activeModel.get(i).isPlaceholder) hasPlaceholder = true;
                            }
                            if (!hasPlaceholder) {
                                activeModel.append({ compId: sourceItem.compId, isPlaceholder: true });
                            }
                        }
                    }
                }

                ListView {
                    id: activeList
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    orientation: ListView.Vertical
                    spacing: Tokens.spacing.small
                    model: activeModel
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
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                ColumnLayout {
                    spacing: 0
                    
                    Text {
                        text: qsTr("Library")
                        font: Tokens.font.title.small
                        color: Colours.palette.m3onSurface
                    }

                    Text {
                        text: qsTr("Disabled components")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                Item { Layout.fillWidth: true }

                IconTextButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "add"
                    text: qsTr("Add spacer")
                    onClicked: {
                        libraryModel.append({ compId: "spacer", isPlaceholder: false });
                        save();
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"

                DropArea {
                    anchors.fill: parent
                    keys: ["component"]
                    onEntered: drag => {
                        let sourceItem = drag.source;
                        if (!sourceItem) return;
                        
                        root.globalDragHoveredList = "library";
                        
                        if (sourceItem.sourceList === "active") {
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
            
            property string sourceList: ListView.view === activeList ? "active" : "library"
            
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
                    let targetModel = sourceList === "active" ? activeModel : libraryModel;
                    
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
                color: isDraggingThis ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 2) : (sourceList === "active" ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer)
                radius: Tokens.rounding.medium
                border.color: isDraggingThis ? Colours.palette.m3outline : (sourceList === "library" ? Colours.palette.m3outlineVariant : "transparent")
                border.width: isDraggingThis ? 2 : (sourceList === "library" ? 1 : 0)
                opacity: isPlaceholder ? 0.2 : 1.0

                MouseArea {
                    id: activeDragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    drag.target: isPlaceholder ? null : activeDelegate
                    drag.axis: Drag.XAndYAxis
                    
                    onPressed: {
                        if (isPlaceholder) return;
                        root.isGlobalDragging = true;
                        root.globalDragSourceList = sourceList;
                        root.globalDragSourceIndex = index;
                        root.globalDragHoveredList = sourceList;
                    }
                    
                    onReleased: {
                        if (isPlaceholder) return;
                        
                        let finalHovered = root.globalDragHoveredList;
                        root.isGlobalDragging = false;
                        
                        if (finalHovered !== sourceList && finalHovered !== "") {
                            let targetModel = finalHovered === "active" ? activeModel : libraryModel;
                            let sourceModel = sourceList === "active" ? activeModel : libraryModel;
                            
                            let pIndex = -1;
                            for (let i = 0; i < targetModel.count; i++) {
                                if (targetModel.get(i).isPlaceholder) { pIndex = i; break; }
                            }
                            
                            if (pIndex !== -1) {
                                targetModel.remove(pIndex);
                                targetModel.insert(pIndex, { compId: compId, isPlaceholder: false });
                                sourceModel.remove(root.globalDragSourceIndex);
                            }
                        }
                        
                        for (let i = libraryModel.count - 1; i >= 0; i--) {
                            if (libraryModel.get(i).isPlaceholder) libraryModel.remove(i);
                        }
                        for (let i = activeModel.count - 1; i >= 0; i--) {
                            if (activeModel.get(i).isPlaceholder) activeModel.remove(i);
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
                        color: sourceList === "active" ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    }
                    
                    Text {
                        Layout.fillWidth: true
                        text: componentMeta[compId]?.name ?? compId
                        font: Tokens.font.body.small
                        color: sourceList === "active" ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    }

                    CustomSpinBox {
                        visible: compId === "spacer" && !isPlaceholder && sourceList === "active"
                        min: 1
                        max: 9999
                        step: 10
                        value: {
                            if (sourceList !== "active" || isPlaceholder) return undefined;
                            let spacerIndex = 0;
                            for (let i = 0; i < delegateWrapper.index; i++) {
                                if (activeModel.get(i).compId === "spacer") spacerIndex++;
                            }
                            
                            let configSpacerIndex = 0;
                            let entries = Config.bar.entries;
                            for (let i = 0; i < entries.length; i++) {
                                if (entries[i].id === "spacer") {
                                    if (configSpacerIndex === spacerIndex) {
                                        return entries[i].size !== undefined ? entries[i].size : undefined;
                                    }
                                    configSpacerIndex++;
                                }
                            }
                            return undefined;
                        }
                        onValueModified: v => {
                            if (sourceList !== "active") return;
                            let spacerIndex = 0;
                            for (let i = 0; i < delegateWrapper.index; i++) {
                                if (activeModel.get(i).compId === "spacer") spacerIndex++;
                            }
                            
                            let entries = JSON.parse(JSON.stringify(Config.bar.entries));
                            let configSpacerIndex = 0;
                            for (let i = 0; i < entries.length; i++) {
                                if (entries[i].id === "spacer") {
                                    if (configSpacerIndex === spacerIndex) {
                                        entries[i].size = v;
                                        GlobalConfig.bar.entries = entries;
                                        return;
                                    }
                                    configSpacerIndex++;
                                }
                            }
                        }
                    }

                    IconButton {
                        icon: "close"
                        visible: compId === "spacer"
                        type: IconButton.Text
                        font: Tokens.font.icon.small
                        padding: Tokens.padding.extraSmall
                        inactiveColour: Colours.tPalette.m3surfaceContainerHigh
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        onClicked: {
                            if (sourceList === "active") {
                                activeModel.remove(delegateWrapper.index);
                            } else {
                                libraryModel.remove(delegateWrapper.index);
                            }
                            save();
                        }
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
