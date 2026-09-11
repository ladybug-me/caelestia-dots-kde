pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Caelestia // Required for CUtils
import Caelestia.Config
import Caelestia.Blobs // Required for BlobGroup and BlobInvertedRect
import qs.components
import qs.components.misc
import qs.services
import qs.utils
import qs.modules.nexus.common

// The release notes window. It opens by itself at startup while there is
// anything the user has not acknowledged, and opens again on demand from the
// whatsnew shortcut or the launcher. Acknowledgement is recorded per entry,
// against the entry's revision, in the shell's state directory; opening an
// entry acknowledges it, closing the window does not.
FloatingWindow {
    id: root

    readonly property var entries: entriesModel.list
    readonly property var history: entriesModel.list.slice().sort((a, b) => b.revision - a.revision)
    readonly property int unreadCount: entriesModel.list.filter(entry => !root.acknowledged.includes(entry.revision)).length

    // Ids used by the pre-revision seen_features.txt. Delete once no user can
    // still have that file.
    readonly property var legacyEntryIds: ({
        "welcome_widget_intro#491": "welcome_intro",
        "update_indicator_9b5fa56": "update_indicator",
        "permanent_shell_#495": "permanent_shell",
        "text_recognition#512": "text_recognition",
        "window_region_selector#516": "window_region_selector",
        "plugin_system#546": "plugin_system",
        "lockscreen-greeter#600": "lockscreen_greeter",
        "greeter-addons#682": "greeter_addons"
    })

    property var acknowledged: []
    property var legacyIds: []
    property bool stateResolved: false
    property bool legacyResolved: false
    property bool resolved: false
    property bool loaded: false
    property bool shown: false
    property bool hasAnimated: false

    function isUnread(entry: var): bool {
        return !root.acknowledged.includes(entry.revision);
    }

    function isVideo(url: var): bool {
        if (!url) return false;
        const lower = String(url).toLowerCase();
        return lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov");
    }

    function acknowledge(revisions: var): void {
        const next = root.acknowledged.slice();
        for (const revision of revisions)
            if (!next.includes(revision))
                next.push(revision);
        if (next.length === root.acknowledged.length)
            return;
        root.acknowledged = next;
        root.saveState();
    }

    function acknowledgeAll(): void {
        root.acknowledge(root.entries.map(entry => entry.revision));
    }

    function openEntry(entry: var): void {
        root.acknowledge([entry.revision]);
        stackView.push(featurePage, { "featureData": entry });
    }

    function saveState(): void {
        stateFile.setText(JSON.stringify({
            "schemaVersion": 1,
            "acknowledged": root.acknowledged
        }));
    }

    // The old file recorded one seen id per line; translate the ids we still
    // know about into the revisions they became.
    function importLegacyIds(ids: var): var {
        const revisions = [];
        for (const legacyId of ids) {
            const entryId = root.legacyEntryIds[legacyId];
            if (!entryId)
                continue;
            const entry = root.entries.find(candidate => candidate.id === entryId);
            if (entry && !revisions.includes(entry.revision))
                revisions.push(entry.revision);
        }
        return revisions;
    }

    // The two state files load independently, and only once both are known can
    // the one-time import be decided.
    function resolveState(): void {
        if (root.resolved || !root.stateResolved || !root.legacyResolved)
            return;
        root.resolved = true;

        if (stateFile.missing)
            root.acknowledged = root.importLegacyIds(root.legacyIds);

        root.loaded = true;
        if (root.unreadCount > 0)
            root.reveal(true);
        else
            root.applyVisibility();
    }

    function reveal(animate: bool): void {
        if (!animate)
            root.hasAnimated = true;
        root.shown = true;
        root.applyVisibility();
    }

    function dismiss(): void {
        root.shown = false;
        root.applyVisibility();
    }

    function toggle(): void {
        if (root.visible)
            root.dismiss();
        else
            root.reveal(false);
    }

    function applyVisibility(): void {
        root.visible = root.loaded && root.shown;
    }

    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false
    title: qsTr("What's New in Caelestia")

    implicitWidth: 680 // Not to be changed
    implicitHeight: 480 // Text and image proportions were set according to these numbers
    minimumSize.width: 680
    minimumSize.height: 480

    onVisibleChanged: {
        // A window-manager close is a dismissal, not an acknowledgement.
        if (!root.visible && root.shown)
            root.shown = false;
    }

    BackgroundEffect.blurRegion: Region {
        Region { x: -10; y: -10; width: 1; height: 1 } // Prevent full-window blur fallback when disabled
        Region { item: (GlobalConfig.appearance.transparency.enabled && GlobalConfig.appearance.blur) ? container : null }
    }

    Entries {
        id: entriesModel
    }

    FileView {
        id: stateFile

        property bool missing: false

        printErrors: false
        path: `${Paths.state}/whatsnew.json`

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.acknowledged = Array.isArray(data.acknowledged) ? data.acknowledged : [];
            } catch (e) {
                console.warn("WhatsNewWindow: ignoring unreadable state: " + e);
                root.acknowledged = [];
            }
            root.stateResolved = true;
            root.resolveState();
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("WhatsNewWindow: could not read state: " + err);
            stateFile.missing = true;
            root.stateResolved = true;
            root.resolveState();
        }
    }

    FileView {
        id: legacyStateFile

        printErrors: false
        path: `${Paths.data}/state/seen_features.txt`

        onLoaded: {
            root.legacyIds = text().split("\n").map(line => line.trim()).filter(line => line.length > 0);
            root.legacyResolved = true;
            root.resolveState();
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("WhatsNewWindow: could not read the legacy seen list: " + err);
            root.legacyResolved = true;
            root.resolveState();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "whatsnew"
        description: qsTr("What's New")
        onPressed: root.toggle()
    }

    IpcHandler {
        function open(): void {
            root.reveal(false);
        }

        function toggle(): void {
            root.toggle();
        }

        target: "whatsnew"
    }

    Item {
        id: container

        anchors.fill: parent

        BlobGroup {
            id: blobGroup

            smoothing: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerLow
        }

        BlobInvertedRect {
            anchors.fill: parent
            group: blobGroup
            opacity: Colours.tPalette.m3surfaceContainerLow.a
            radius: Tokens.rounding.large
            borderLeft: Tokens.padding.medium
            borderRight: Tokens.padding.medium
            borderTop: Tokens.padding.medium
            borderBottom: Tokens.padding.medium
        }

        StackView {
            id: stackView

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            initialItem: homePage

            // Add a clip so pushing/popping doesn't overflow rounded corners
            clip: true
        }

        Component {
            id: homePage

            Item {
                id: homeRoot

                // Calculate centered block bounds
                readonly property real startupBlockHeight: 90.38 + Tokens.spacing.large + titleText.implicitHeight
                readonly property real startupBlockY: (homeRoot.height - startupBlockHeight) / 2 - 40

                function openCurrent(): void {
                    const entry = root.history[featuresList.currentIndex];
                    if (entry)
                        root.openEntry(entry);
                }

                anchors.fill: parent
                state: root.hasAnimated ? "loaded" : "startup"

                Keys.onEscapePressed: root.dismiss()

                Timer {
                    id: startupTimer

                    interval: 2300
                    running: root.shown && !root.hasAnimated

                    onTriggered: root.hasAnimated = true
                }

                Item {
                    id: logoItem

                    width: 128
                    height: 90.38
                    transformOrigin: Item.TopLeft
                    x: homeRoot.state === "startup" ? (homeRoot.width - width) / 2 : (homeRoot.width - (64 + Tokens.spacing.medium + titleText.implicitWidth)) / 2
                    y: homeRoot.state === "startup" ? homeRoot.startupBlockY : (46 - 45.19) / 2
                    scale: homeRoot.state === "startup" ? 1.0 : 64 / 128

                    AnimatedLogo {
                        id: logoAnim

                        anchors.fill: parent
                    }
                }

                StyledText {
                    id: titleText

                    text: qsTr("What's New in Caelestia")
                    font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                    color: Colours.palette.m3onSurface
                    x: homeRoot.state === "startup" ? (homeRoot.width - implicitWidth) / 2 : logoItem.x + 64 + Tokens.spacing.medium
                    y: homeRoot.state === "startup" ? homeRoot.startupBlockY + 90.38 + Tokens.spacing.large : (46 - implicitHeight) / 2
                }

                StyledText {
                    id: startupVersionText

                    text: CUtils.version ? "v" + CUtils.version : ""
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    color: Colours.palette.m3onSurfaceVariant
                    x: homeRoot.state === "startup" ? (homeRoot.width - implicitWidth) / 2 : titleText.x
                    y: titleText.y + titleText.implicitHeight

                    opacity: homeRoot.state === "startup" ? 1 : 0
                }

                // Every entry ever shipped, newest first, with the ones the user
                // has not opened marked as unread.
                ListView {
                    id: featuresList

                    anchors.top: parent.top
                    anchors.topMargin: 46 + Tokens.spacing.large
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    opacity: homeRoot.state === "startup" ? 0 : 1
                    clip: true
                    spacing: Tokens.spacing.medium
                    model: root.history
                    keyNavigationEnabled: true
                    currentIndex: -1
                    focus: stackView.depth === 1

                    onCurrentIndexChanged: {
                        if (featuresList.currentIndex >= 0)
                            featuresList.positionViewAtIndex(featuresList.currentIndex, ListView.Contain);
                    }

                    Keys.onReturnPressed: homeRoot.openCurrent()
                    Keys.onEnterPressed: homeRoot.openCurrent()

                    footer: Item {
                        width: featuresList.width
                        height: 64 + Tokens.spacing.large

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.max(0, featuresList.height - featuresList.contentHeight) + (parent.height - implicitHeight) / 2
                            text: CUtils.version ? "v" + CUtils.version : ""
                            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    delegate: StyledRect {
                        id: delegateRect

                        required property var modelData

                        property var feature: modelData
                        property bool hasMedia: feature && !!feature.mediaUrl

                        width: ListView.view.width
                        height: contentColumn.implicitHeight + Tokens.padding.large * 2
                        radius: Tokens.rounding.extraLarge
                        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                        border.width: (featuresList.activeFocus && ListView.isCurrentItem) ? 2 : 0
                        border.color: Colours.palette.m3primary

                        Behavior on color { CAnim {} }

                        StateLayer {
                            anchors.fill: parent
                            topLeftRadius: parent.radius
                            topRightRadius: parent.radius
                            bottomLeftRadius: parent.radius
                            bottomRightRadius: parent.radius

                            onClicked: root.openEntry(feature)
                        }

                        ColumnLayout {
                            id: contentColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Tokens.padding.large
                            spacing: Tokens.spacing.large

                            // Header Row (Icon + Text + Chevron)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.medium

                                // Circular Icon
                                StyledRect {
                                    Layout.preferredHeight: 48
                                    Layout.preferredWidth: 48
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3secondaryContainer

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        text: (feature && feature.icon) ? feature.icon : (feature && root.isVideo(feature.mediaUrl) ? "videocam" : "new_releases")
                                        color: Colours.palette.m3onSecondaryContainer
                                        fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                                        grade: 25
                                        fill: 1
                                    }

                                    // Unread marker
                                    StyledRect {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        width: 12
                                        height: 12
                                        radius: Tokens.rounding.full
                                        color: Colours.palette.m3primary
                                        visible: root.isUnread(feature)
                                    }
                                }

                                // Title & Description
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: feature ? feature.title : ""
                                        font: Tokens.font.body.large
                                        color: Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: feature ? feature.description : ""
                                        font: Tokens.font.body.small
                                        color: Colours.palette.m3onSurfaceVariant
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        maximumLineCount: 1
                                    }
                                }

                                // Chevron right for drill down
                                MaterialIcon {
                                    text: "chevron_right"
                                    color: Colours.palette.m3onSurfaceVariant
                                    fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                                }
                            }
                        }
                    }

                    Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
                }

                Item {
                    id: fabContainer

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Tokens.spacing.large
                    width: 56
                    height: 56
                    opacity: homeRoot.state === "startup" ? 0 : 1
                    visible: root.unreadCount > 0

                    Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

                    StyledRect {
                        id: markAllBtn

                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        opacity: markAllMouse.pressed ? 0.85 : (markAllMouse.containsMouse ? 0.95 : 1.0)
                        scale: markAllMouse.pressed ? 0.95 : ((markAllMouse.containsMouse || markAllMouse.activeFocus) ? 1.05 : 1.0)

                        Behavior on opacity { CAnim { duration: 150 } }
                        Behavior on scale { CAnim { duration: 150 } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "done_all"
                            color: Colours.palette.m3onPrimary
                            fontStyle: Tokens.font.icon.builders.large.weight(Font.Medium).build()
                        }

                        MouseArea {
                            id: markAllMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true

                            onClicked: root.acknowledgeAll()

                            Keys.onReturnPressed: root.acknowledgeAll()
                            Keys.onSpacePressed: root.acknowledgeAll()
                        }
                    }
                }
            }
        }

        Component {
            id: featurePage

            Item {
                property var featureData
                property bool hasMedia: featureData && !!featureData.mediaUrl

                focus: stackView.depth === 2

                Keys.onEscapePressed: stackView.pop()

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Tokens.spacing.large

                    // Header with Back Button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.medium

                        StyledRect {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: Tokens.rounding.full
                            color: backLayer.containsMouse ? Colours.palette.m3surfaceVariant : "transparent"

                            Behavior on color { CAnim {} }

                            StateLayer {
                                id: backLayer

                                anchors.fill: parent
                                topLeftRadius: parent.radius
                                topRightRadius: parent.radius
                                bottomLeftRadius: parent.radius
                                bottomRightRadius: parent.radius

                                onClicked: stackView.pop()
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "arrow_back"
                                color: Colours.palette.m3onSurface
                                fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: featureData ? featureData.title : ""
                            font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                            color: Colours.palette.m3onSurface
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        // Keeps the title centred against the back button
                        Item {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                        }
                    }

                    // Expanded Content
                    ScrollView {
                        id: expandedScrollView

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        clip: true

                        ColumnLayout {
                            width: expandedScrollView.availableWidth
                            spacing: Tokens.spacing.large

                            // Media Container
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 280
                                visible: hasMedia

                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3surface
                                    opacity: 0.5
                                    visible: {
                                        if (!featureData) return false;
                                        if (featureData.mediaTransparent) return false;
                                        if (featureData.mediaUrl) {
                                            const url = featureData.mediaUrl.toLowerCase();
                                            if (url.endsWith(".png") || url.endsWith(".svg") || url.endsWith(".gif"))
                                                return false;
                                        }
                                        return true;
                                    }
                                }

                                AnimatedImage {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.small
                                    source: hasMedia ? entriesModel.mediaSource(featureData) : ""
                                    visible: hasMedia && !root.isVideo(featureData.mediaUrl)
                                    fillMode: Image.PreserveAspectFit
                                    playing: visible
                                }

                                VideoOutput {
                                    id: vidOut

                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.small
                                    visible: hasMedia && root.isVideo(featureData.mediaUrl)
                                    fillMode: VideoOutput.PreserveAspectFit
                                }

                                AudioOutput {
                                    id: aOut

                                    muted: true
                                }

                                MediaPlayer {
                                    videoOutput: vidOut
                                    audioOutput: aOut
                                    source: hasMedia ? entriesModel.mediaSource(featureData) : ""
                                    loops: MediaPlayer.Infinite

                                    Component.onCompleted: {
                                        if (hasMedia && root.isVideo(featureData.mediaUrl))
                                            play();
                                    }
                                }
                            }

                            // Description Full
                            StyledText {
                                Layout.fillWidth: true
                                text: featureData ? featureData.description : ""
                                font: Tokens.font.body.large
                                color: Colours.palette.m3onSurfaceVariant
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
