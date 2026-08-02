import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Internal
import qs.components.containers
import qs.services
import qs.utils

StyledWindow {
    id: root

    required property ShellScreen modelData
    property int shimejiCount: 1
    readonly property alias shimejiScreen: root.modelData
    readonly property bool windowHidesShimeji: {
        let isHidden = false;
        if (typeof KWinActiveWindowBridge !== "undefined" && KWinActiveWindowBridge.activeWindow) {
            isHidden = KWinActiveWindowBridge.activeWindow.fullscreen || KWinActiveWindowBridge.activeWindow.maximized;
            if (isHidden && !GlobalConfig.forScreen(modelData.name).shimeji.hideOnAllMonitors) {
                isHidden = KWinActiveWindowBridge.activeOutputName === modelData.name;
            }
        } else {
            // Use Object.values() to safely iterate the monitors cache object
            if (GlobalConfig.forScreen(modelData.name).shimeji.hideOnAllMonitors) {
                isHidden = Object.values(Hypr.monitors).some(m => !(m.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true));
            } else {
                isHidden = !(Hypr.monitorFor(modelData)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true);
            }
        }
        return isHidden;
    }
    readonly property var drawerVisibilities: Visibilities.screens.get(Hypr.monitorFor(modelData)) ?? Visibilities.screens.get(modelData.name)
    readonly property bool shouldBeVisible: !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableShimeji) && (!GlobalConfig.forScreen(modelData.name).shimeji.autoHide || !windowHidesShimeji)
    property var extractedPaths: []
    property Process extractor: Process {
        running: false
        command: ["unzip", "-o"]
        workingDirectory: "/tmp"
    }
    readonly property real borderThickness: modelData ? Config.border.thickness : 0
    readonly property var barWrapper: (() => {
        let name = root.screen ? root.screen.name : undefined;
        let bar = name ? Visibilities.bars.get(name) : undefined;
        return bar;
    })()
    readonly property real floorOffset: Config.bar.position === "bottom" ? (barWrapper ? barWrapper.exclusiveZone : 0) : 0

    function getImgPath(): string {
        if (!modelData)
            return "";
        let path = Paths.absolutePath(String(Config.shimeji.path));
        if (!path)
            return "";

        if (path.endsWith(".zip")) {
            const extractDir = path.replace(".zip", "/");
            if (!extractor.running && !extractedPaths.includes(path)) {
                extractedPaths.push(path);
                extractor.arguments = ["-o", "-d", extractDir, path];
                extractor.running = true;
            }
            return extractDir;
        }

        return path.replace(/\/?$/, "/");
    }
    screen: modelData
    visible: shouldBeVisible
    name: "shimeji"
    isDesktopWidget: true
    surfaceFormat.opaque: false
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    Component.onCompleted: {
        Qt.callLater(() => {
            extractor.running = false;
        });
    }
    mask: Region {
        regions: {
            var arr = [];
            for (var i = 0; i < spriteRegions.count; i++) {
                if (spriteRegions.objectAt(i)) arr.push(spriteRegions.objectAt(i));
            }
            return arr;
        }
    }

    Item {
        id: spriteContainer

        anchors.fill: parent

        Repeater {
            id: spriteRepeater

            model: root.shimejiCount > 0 ? root.shimejiCount : 1

            ShimejiSprite {
                screenSize: Qt.size(shimejiScreen.width, shimejiScreen.height)
                borderThickness: root.borderThickness
                floorOffset: root.floorOffset
                imgPath: root.getImgPath()
            }
        }
    }
    Instantiator {
        id: spriteRegions

        model: spriteRepeater.count

        Region {
            item: spriteRepeater.itemAt(index)
        }
    }
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
