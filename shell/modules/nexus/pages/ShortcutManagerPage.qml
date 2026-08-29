pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Shortcuts")

    property var shellShortcuts: []

    property var appShortcuts: []

    property var workspaceShortcuts: []

    property var tilingShortcuts: []

    property string shortcutQuery

    function matchesShortcut(item: var): bool {
        const query = root.shortcutQuery.trim().toLowerCase();
        if (!query)
            return true;

        const searchable = [item.name, item.description, item.bind]
            .map(value => String(value ?? "").toLowerCase())
            .join(" ");
        return searchable.includes(query);
    }

    function updateLists() {
        let all = KeybindsModel.query("")
        let shell = []
        let apps = []
        let workspaces = []
        let tiling = []

        const shellRegex = /^(nexus|launcher|dashboard|showall|screenshot|googleLens|screenRecording|lock|session|sidebar|aiAssistant|utilities|emoji|clipboard|windowSwitcher.*|wallpaper|keybinds)$/
        const workspaceRegex = /^workspace.*$/
        const tilingRegex = /^krohnkite.*$/

        for (let i = 0; i < all.length; i++) {
            let item = all[i]
            if (!root.matchesShortcut(item))
                continue;
            if (item.name.match(shellRegex)) {
                shell.push(item)
            } else if (item.name.match(workspaceRegex)) {
                workspaces.push(item)
            } else if (item.name.match(tilingRegex)) {
                tiling.push(item)
            } else {
                apps.push(item)
            }
        }
        let sortByName = (a, b) => a.name.localeCompare(b.name, undefined, {numeric: true})
        shell.sort(sortByName)
        apps.sort(sortByName)
        workspaces.sort(sortByName)
        tiling.sort(sortByName)
        
        shellShortcuts = shell
        appShortcuts = apps
        workspaceShortcuts = workspaces
        tilingShortcuts = tiling
    }

    onShortcutQueryChanged: updateLists()

    function openCaptureDialog(name: string, currentKey: string, targetItem: var) {
        dialogLoader.active = true
        dialogLoader.item.shortcutName = name
        dialogLoader.item.currentKey = currentKey
        dialogLoader.item.targetItem = targetItem
        dialogLoader.item.open()
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Component.onCompleted: updateLists()

        Connections {
            target: KeybindsModel

            function onKeybindsChanged() {
                updateLists()
            }
        }

        Loader {
            id: dialogLoader

            active: false
            sourceComponent: KeyCaptureDialog {
                onConfirm: (name, newKey) => {
                    KeybindsModel.setKey(name, newKey)
                }
                onClear: (name) => {
                    KeybindsModel.setKey(name, "")
                }
                onUnblocked: {
                    dialogLoader.active = false
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: searchLayout.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.full
            color: Colours.tPalette.m3surfaceContainerLowest
            border.color: Colours.palette.m3outlineVariant

            RowLayout {
                id: searchLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "search"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.medium
                }

                StyledTextField {
                    id: searchField

                    Layout.fillWidth: true
                    placeholderText: qsTr("Search shortcuts")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                    onTextChanged: root.shortcutQuery = text
                }

                IconButton {
                    visible: searchField.text.length > 0
                    icon: "close"
                    font: Tokens.font.icon.medium
                    type: IconButton.Text
                    padding: Tokens.padding.extraSmall
                    isRound: true
                    onClicked: searchField.clear()
                }
            }
        }

        SectionHeader {
            first: true
            text: qsTr("Shell UI")
            visible: root.shellShortcuts.length > 0
        }

        Repeater {
            model: root.shellShortcuts
            delegate: ShortcutRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.shellShortcuts.length - 1
                actionName: modelData.name
                label: modelData.description
                keybind: modelData.bind
                isOverridden: modelData.isOverridden
                isShell: true

                onAddClicked: (target) => root.openCaptureDialog(modelData.name, modelData.bind, target)
                onKeybindEdited: (newKey) => KeybindsModel.setKey(modelData.name, newKey)
                onResetClicked: KeybindsModel.resetKey(modelData.name)
            }
        }

        SectionHeader {
            first: root.shellShortcuts.length === 0
            text: qsTr("Applications")
            visible: root.appShortcuts.length > 0
        }

        Repeater {
            model: root.appShortcuts
            delegate: ShortcutRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.appShortcuts.length - 1
                actionName: modelData.name
                label: modelData.description
                keybind: modelData.bind
                isOverridden: modelData.isOverridden

                onAddClicked: (target) => root.openCaptureDialog(modelData.name, modelData.bind, target)
                onKeybindEdited: (newKey) => KeybindsModel.setKey(modelData.name, newKey)
                onResetClicked: KeybindsModel.resetKey(modelData.name)
            }
        }

        SectionHeader {
            first: root.shellShortcuts.length === 0 && root.appShortcuts.length === 0
            text: qsTr("Workspaces")
            visible: root.workspaceShortcuts.length > 0
        }

        Repeater {
            model: root.workspaceShortcuts
            delegate: ShortcutRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.workspaceShortcuts.length - 1
                actionName: modelData.name
                label: modelData.description
                keybind: modelData.bind
                isOverridden: modelData.isOverridden

                onAddClicked: (target) => root.openCaptureDialog(modelData.name, modelData.bind, target)
                onKeybindEdited: (newKey) => KeybindsModel.setKey(modelData.name, newKey)
                onResetClicked: KeybindsModel.resetKey(modelData.name)
            }
        }

        SectionHeader {
            first: root.shellShortcuts.length === 0 && root.appShortcuts.length === 0 && root.workspaceShortcuts.length === 0
            text: qsTr("Window Tiling (Krohnkite)")
            visible: Config.general.krohnkiteEnabled && root.tilingShortcuts.length > 0
        }

        Repeater {
            model: Config.general.krohnkiteEnabled ? root.tilingShortcuts : []
            delegate: ShortcutRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === root.tilingShortcuts.length - 1
                actionName: modelData.name
                label: modelData.description
                keybind: modelData.bind
                isOverridden: modelData.isOverridden

                onAddClicked: (target) => root.openCaptureDialog(modelData.name, modelData.bind, target)
                onKeybindEdited: (newKey) => KeybindsModel.setKey(modelData.name, newKey)
                onResetClicked: KeybindsModel.resetKey(modelData.name)
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.large
            visible: root.shortcutQuery.length > 0
                     && root.shellShortcuts.length === 0
                     && root.appShortcuts.length === 0
                     && root.workspaceShortcuts.length === 0
                     && root.tilingShortcuts.length === 0
            text: qsTr("No shortcuts found")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
