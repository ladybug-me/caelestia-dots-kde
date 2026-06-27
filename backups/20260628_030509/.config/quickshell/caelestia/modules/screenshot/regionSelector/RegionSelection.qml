import ".."
import "../../../components/controls"
import qs.services
import qs.utils
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: root
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "quickshell:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Modes
    // TODO: Ask: sidebar AI
    enum SnipAction { Copy, Edit, Search, CharRecognition, Record, RecordWithSound } 
    enum SelectionMode { RectCorners, Circle }
    enum Phase { Select, Post }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    property var phase: RegionSelection.Phase.Select
    signal dismiss()

    // Styles
    property string screenshotDir: "/tmp/caelestia-screenshot"
    property color overlayColor: Qt.rgba("#000000".r, "#000000".g, "#000000".b, 1.0 - 0.4)
    property color brightText: true ? Colours.palette.m3onSurface : Colours.palette.m3surface
    property color brightSecondary: true ? Colours.palette.m3secondary : Colours.palette.m3onSecondary
    property color brightTertiary: true ? Colours.palette.m3tertiary : Qt.lighter(Colours.palette.m3primary)
    property color selectionBorderColor: brightSecondary
    property color selectionFillColor: "#33ffffff"
    property color windowBorderColor: brightSecondary
    property color windowFillColor: Qt.rgba(windowBorderColor.r, windowBorderColor.g, windowBorderColor.b, 1.0 - 0.85)
    property color imageBorderColor: brightTertiary
    property color imageFillColor: Qt.rgba(imageBorderColor.r, imageBorderColor.g, imageBorderColor.b, 1.0 - 0.85)
    property color onBorderColor: "#ff000000"
    property real targetRegionOpacity: 0.6
    property bool contentRegionOpacity: false

    // Vars for indicators
    readonly property var windows: Hypr.toplevels.values.sort((a, b) => {
        // Sort floating=true windows before others
        if (a.floating === b.floating) return 0;
        return a.floating ? -1 : 1;
    })
    readonly property var layers: ({})
    readonly property real falsePositivePreventionRatio: 0.5

    // Screen & interaction vars
    readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property real monitorScale: (hyprlandMonitor && hyprlandMonitor.scale > 0) ? hyprlandMonitor.scale : (screen.devicePixelRatio || 1.0)
    readonly property real monitorOffsetX: hyprlandMonitor ? (hyprlandMonitor.x || 0) : 0
    readonly property real monitorOffsetY: hyprlandMonitor ? (hyprlandMonitor.y || 0) : 0
    property int activeWorkspaceId: hyprlandMonitor && hyprlandMonitor.activeWorkspace ? hyprlandMonitor.activeWorkspace.id : 0
    property string screenshotPath: `${root.screenshotDir}/image-${screen.name}`
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property real dragDiffX: 0
    property real dragDiffY: 0
    property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)
    property bool dragging: false
    property var points: []
    property var mouseButton: null
    property var imageRegions: []
    readonly property var windowRegions: RegionFunctions.filterWindowRegionsByLayers(
        root.windows.filter(w => w.workspace.id === root.activeWorkspaceId || root.activeWorkspaceId === 0),
        root.layerRegions
    ).map(window => {
        return {
            at: [window.at[0] - root.monitorOffsetX, window.at[1] - root.monitorOffsetY],
            size: [window.size[0], window.size[1]],
            class: window.class,
            title: window.title,
        }
    })
    readonly property var layerRegions: {
        const layersOfThisMonitor = root.layers[root.hyprlandMonitor.name]
        const topLayers = layersOfThisMonitor ? layersOfThisMonitor.levels["2"] : undefined
        if (!topLayers) return [];
        const nonBarTopLayers = topLayers
            .filter(layer => !(layer.namespace.includes(":bar") || layer.namespace.includes(":verticalBar") || layer.namespace.includes(":dock")))
            .map(layer => {
            return {
                at: [layer.x, layer.y],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }
        })
        const offsetAdjustedLayers = nonBarTopLayers.map(layer => {
            return {
                at: [layer.at[0] - root.monitorOffsetX, layer.at[1] - root.monitorOffsetY],
                size: layer.size,
                namespace: layer.namespace,
            }
        });
        return offsetAdjustedLayers;
    }

    // Config
    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    property bool enableWindowRegions: true && !isCircleSelection
    property bool enableLayerRegions: true && !isCircleSelection
    property bool enableContentRegions: false

    // Target
    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0
    function targetedRegionValid() {
        return (root.targetedRegionX >= 0 && root.targetedRegionY >= 0)
    }
    function setRegionToTargeted() {
        const padding = 0; // Make borders not cut off n stuff
        root.regionX = root.targetedRegionX - padding;
        root.regionY = root.targetedRegionY - padding;
        root.regionWidth = root.targetedRegionWidth + padding * 2;
        root.regionHeight = root.targetedRegionHeight + padding * 2;
    }

    function updateTargetedRegion(x, y) {
        // Image regions
        const clickedRegion = root.imageRegions.find(region => {
            return region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        });
        if (clickedRegion) {
            root.targetedRegionX = clickedRegion.at[0];
            root.targetedRegionY = clickedRegion.at[1];
            root.targetedRegionWidth = clickedRegion.size[0];
            root.targetedRegionHeight = clickedRegion.size[1];
            return;
        }

        // Layer regions
        const clickedLayer = root.layerRegions.find(region => {
            return region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        });
        if (clickedLayer) {
            root.targetedRegionX = clickedLayer.at[0];
            root.targetedRegionY = clickedLayer.at[1];
            root.targetedRegionWidth = clickedLayer.size[0];
            root.targetedRegionHeight = clickedLayer.size[1];
            return;
        }

        // Window regions
        const clickedWindow = root.windowRegions.find(region => {
            return region.at[0] <= x && x <= region.at[0] + region.size[0] && region.at[1] <= y && y <= region.at[1] + region.size[1];
        });
        if (clickedWindow) {
            root.targetedRegionX = clickedWindow.at[0];
            root.targetedRegionY = clickedWindow.at[1];
            root.targetedRegionWidth = clickedWindow.size[0];
            root.targetedRegionHeight = clickedWindow.size[1];
            return;
        }

        root.targetedRegionX = -1;
        root.targetedRegionY = -1;
        root.targetedRegionWidth = 0;
        root.targetedRegionHeight = 0;
    }

    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)
    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)

    // Screenshot stuff
    TempScreenshotProcess {
        id: screenshotProc
        running: true
        screen: root.screen
        screenshotDir: root.screenshotDir
        screenshotPath: root.screenshotPath
        onExited: (exitCode, exitStatus) => {
            if (root.enableContentRegions) imageDetectionProcess.running = true;
            root.preparationDone = !checkRecordingProc.running;
        }
    }
    property bool isRecording: root.action === RegionSelection.SnipAction.Record || root.action === RegionSelection.SnipAction.RecordWithSound
    property bool recordingShouldStop: false
    Process {
        id: checkRecordingProc
        running: isRecording
        command: ["pidof", "gpu-screen-recorder"]
        onExited: (exitCode, exitStatus) => {
            root.preparationDone = !screenshotProc.running
            root.recordingShouldStop = (exitCode === 0);
        }
    }
    property bool preparationDone: false
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        if (root.isRecording && root.recordingShouldStop) {
            Quickshell.execDetached(["caelestia-record"]);
            root.dismiss();
            return;
        }
        root.visible = true;
    }

    Process {
        id: imageDetectionProcess
        command: ["bash", "-c", `${"~/.config/caelestia/scripts"}/images/find-regions-venv.sh ` 
            + `--hyprctl ` 
            + `--image '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' ` 
            + `--max-width ${Math.round(root.screen.width * root.falsePositivePreventionRatio)} ` 
            + `--max-height ${Math.round(root.screen.height * root.falsePositivePreventionRatio)} `]
        stdout: StdioCollector {
            id: imageDimensionCollector
            onStreamFinished: {
                imageRegions = RegionFunctions.filterImageRegions(
                    JSON.parse(imageDimensionCollector.text),
                    root.windowRegions
                );
            }
        }
    }

    function getScreenshotAction() {
        switch(root.action) {
            case RegionSelection.SnipAction.Copy:
                return ScreenshotAction.Action.Copy;
            case RegionSelection.SnipAction.Edit:
                return ScreenshotAction.Action.Edit;
            case RegionSelection.SnipAction.Search:
                return ScreenshotAction.Action.Search;
            case RegionSelection.SnipAction.CharRecognition:
                return ScreenshotAction.Action.CharRecognition;
            case RegionSelection.SnipAction.Record:
                return ScreenshotAction.Action.Record;
            case RegionSelection.SnipAction.RecordWithSound:
                return ScreenshotAction.Action.RecordWithSound;
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                root.dismiss();
                return;
        }
    }

    // Execution after selection
    function snip() {

        // Clamp region to screen bounds
        root.regionX = Math.max(0, Math.min(root.regionX, root.screen.width - root.regionWidth));
        root.regionY = Math.max(0, Math.min(root.regionY, root.screen.height - root.regionHeight));
        root.regionWidth = Math.max(0, Math.min(root.regionWidth, root.screen.width - root.regionX));
        root.regionHeight = Math.max(0, Math.min(root.regionHeight, root.screen.height - root.regionY));

        // Adjust action
        if (root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Edit) {
            root.action = root.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }
        
        const screenshotDir = "" !== "" ? //
            "" : "";
        var screenshotAction = root.getScreenshotAction();
        const command = ScreenshotAction.getCommand(
            (root.regionX + root.monitorOffsetX) * root.monitorScale, //
            (root.regionY + root.monitorOffsetY) * root.monitorScale, //
            root.regionWidth * root.monitorScale,// 
            root.regionHeight * root.monitorScale, //
            root.screenshotPath, //
            screenshotAction, //
            screenshotDir
        )
        Quickshell.execDetached(command);
        if (root.action == RegionSelection.SnipAction.Record || root.action == RegionSelection.SnipAction.RecordWithSound) {
            root.phase = RegionSelection.Phase.Post
            root.selectionMode = RegionSelection.SelectionMode.RectCorners
        } else {
            root.dismiss();
        }
    }

    // Only clickable in Selection phase
    mask: Region {
        item: switch(root.phase) {
            case RegionSelection.Phase.Select: return mouseArea;
            case RegionSelection.Phase.Post: return null;
        }
    }

    ScreencopyView { // For freezing
        anchors.fill: parent
        live: false
        captureSource: root.screen
        visible: root.phase === RegionSelection.Phase.Select

        focus: root.visible
        Keys.onPressed: (event) => { // Esc to close
            if (event.key === Qt.Key_Escape) {
                root.dismiss();
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: root.draggedAway ? Qt.ArrowCursor : Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        // Controls
        onPressed: (mouse) => {
            root.dragStartX = mouse.x;
            root.dragStartY = mouse.y;
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragging = true;
            root.mouseButton = mouse.button;
        }
        onReleased: (mouse) => {
            root.dragging = false;
            // Detect if it was a click -> Try to select targeted region
            if (root.draggingX === root.dragStartX && root.draggingY === root.dragStartY) {
                if (root.targetedRegionValid()) {
                    root.setRegionToTargeted();
                }
            }
            // Circle dragging?
            else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                const padding = 0 + 2 / 2;
                const dragPoints = (root.points.length > 0) ? root.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                const maxX = Math.max(...dragPoints.map(p => p.x));
                const minX = Math.min(...dragPoints.map(p => p.x));
                const maxY = Math.max(...dragPoints.map(p => p.y));
                const minY = Math.min(...dragPoints.map(p => p.y));
                root.regionX = minX - padding;
                root.regionY = minY - padding;
                root.regionWidth = maxX - minX + padding * 2;
                root.regionHeight = maxY - minY + padding * 2;
            }
            root.snip();
        }
        onPositionChanged: (mouse) => {
            root.updateTargetedRegion(mouse.x, mouse.y);
            if (!root.dragging) return;
            root.draggingX = mouse.x;
            root.draggingY = mouse.y;
            root.dragDiffX = mouse.x - root.dragStartX;
            root.dragDiffY = mouse.y - root.dragStartY;
            root.points.push({ x: mouse.x, y: mouse.y });
        }
        
        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.RectCorners
            sourceComponent: RectCornersSelectionDetails {
                regionX: root.regionX
                regionY: root.regionY
                regionWidth: root.regionWidth
                regionHeight: root.regionHeight
                mouseX: mouseArea.mouseX
                mouseY: mouseArea.mouseY
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                breathingBorderOnly: root.phase === RegionSelection.Phase.Post
            }
        }

        Loader {
            z: 2
            anchors.fill: parent
            active: root.selectionMode === RegionSelection.SelectionMode.Circle
            sourceComponent: CircleSelectionDetails {
                color: root.selectionBorderColor
                overlayColor: root.overlayColor
                points: root.points
            }
        }

        // The thing to the bottom-right with an icon
        CursorGuide {
            z: 9999
            visible: root.phase === RegionSelection.Phase.Select
            x: root.dragging ? root.regionX + root.regionWidth : mouseArea.mouseX
            y: root.dragging ? root.regionY + root.regionHeight : mouseArea.mouseY
            action: root.action
            selectionMode: root.selectionMode
        }

        // Window regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableWindowRegions) {
                        return root.windowRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 2
                required property var modelData
                clientDimensions: modelData
                showIcon: true
                targeted: !root.draggedAway && //
                    (root.targetedRegionX === modelData.at[0]  //
                    && root.targetedRegionY === modelData.at[1] //
                    && root.targetedRegionWidth === modelData.size[0] //
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: root.windowBorderColor
                fillColor: targeted ? root.windowFillColor : "transparent"
                text: `${modelData.class}`
                radius: 12
            }
        }

        // Layer regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableLayerRegions) {
                        return root.layerRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 3
                required property var modelData
                clientDimensions: modelData
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0] 
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                borderColor: root.windowBorderColor
                fillColor: targeted ? root.windowFillColor : "transparent"
                text: `${modelData.namespace}`
                radius: 12
            }
        }

        // Content regions
        Repeater {
            model: ScriptModel {
                values: {
                    if (root.phase === RegionSelection.Phase.Select && root.enableContentRegions) {
                        return root.imageRegions
                    } else {
                        return []
                    }
                }
            }
            delegate: TargetRegion {
                z: 4
                required property var modelData
                clientDimensions: modelData
                targeted: !root.draggedAway &&
                    (root.targetedRegionX === modelData.at[0] 
                    && root.targetedRegionY === modelData.at[1]
                    && root.targetedRegionWidth === modelData.size[0]
                    && root.targetedRegionHeight === modelData.size[1])

                opacity: root.draggedAway ? 0 : root.contentRegionOpacity
                borderColor: root.imageBorderColor
                fillColor: targeted ? root.imageFillColor : "transparent"
                text: qsTr("Content region")
            }
        }

        // Controls
        Row {
            id: regionSelectionControls
            z: 10
            visible: root.phase === RegionSelection.Phase.Select
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: -height
            }
            opacity: 0
            Connections {
                target: root
                function onVisibleChanged() {
                    if (!visible) return;
                    regionSelectionControls.anchors.bottomMargin = 8;
                    regionSelectionControls.opacity = 1;
                }
            }
            Behavior on opacity {
                animation: NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }
            Behavior on anchors.bottomMargin {
                animation: NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
            }
            spacing: 6

            OptionsToolbar {
                Synchronizer on action {
                    property alias source: root.action
                }
                Synchronizer on selectionMode {
                    property alias source: root.selectionMode
                }
                onDismiss: root.dismiss();
            }
            // Confirm snip button — appears after a region is drawn
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.regionConfirmPending
                icon: "check"
                onClicked: root.snip();
                Tooltip {
                    target: parent
                    text: qsTr("Snip selected region (Enter)")
                }
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                onClicked: {
                    if (root.regionConfirmPending) {
                        // Reset selection — let user redraw
                        root.regionConfirmPending = false;
                        root.regionWidth = 0;
                        root.regionHeight = 0;
                    } else {
                        root.dismiss();
                    }
                }
                Tooltip {
                    target: parent
                    text: root.regionConfirmPending ? qsTr("Clear selection") : qsTr("Close")
                }
            }
        }
        
    }
}
