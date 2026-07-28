pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Shortcuts")

    property var shellShortcuts: []
    property var appShortcuts: []
    property var workspaceShortcuts: []
    property var tilingShortcuts: []

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

        SectionHeader {
            first: true
            text: qsTr("Shell UI")
        }

        SectionHeader {
            text: qsTr("Hover the indicator to identify the affected app")
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
            text: qsTr("Applications")
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
            text: qsTr("Workspaces")
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
            text: qsTr("Window Tiling (Krohnkite)")
            visible: Config.general.krohnkiteEnabled
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
    }
}
