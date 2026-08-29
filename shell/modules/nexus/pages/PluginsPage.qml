pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.services.api
import Quickshell.Io


PageBase {
    id: root

    Item {
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        PluginSettingsPopup {
            id: settingsPopup
        }
    }

    // Count helpers since Repeater.count counts all items regardless of visibility
    readonly property int bundledCount: {
        let n = 0;
        for (let i = 0; i < CaelestiaApi.plugins.available.count; i++) {
            if (CaelestiaApi.plugins.available.get(i).source === "bundled") n++;
        }
        return n;
    }
    readonly property int userCount: {
        let n = 0;
        for (let i = 0; i < CaelestiaApi.plugins.available.count; i++) {
            if (CaelestiaApi.plugins.available.get(i).source === "user") n++;
        }
        return n;
    }
    property int currentTab: 0 // 0 = Installed, 1 = Store

    title: qsTr("Plugins")
    headerActions: [
        TextButton {
            text: qsTr("Refresh")
            type: TextButton.Tonal
            visible: root.currentTab === 1
            scale: pressed ? 0.95 : 1.0

            Behavior on scale {
                Anim { type: Anim.DefaultEffects }
            }

            onClicked: {
                PluginStore.fetchIndex();
            }
        },
        TextButton {
            text: qsTr("Restart Shell")
            type: TextButton.Filled
            //visible: PluginStore.restartRequired
            scale: pressed ? 0.95 : 1.0

            Behavior on scale {
                Anim { type: Anim.DefaultEffects }
            }

            onClicked: restartProcess.running = true

            Process {
                id: restartProcess

                command: ["bash", "-c", "nohup bash -c 'bash \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia/scripts/restart_shell.sh\"; sleep 1; caelestia shell nexus openPage 14 0' >/dev/null 2>&1 & disown"]
            }
        }
    ]

    Component.onCompleted: {
        if (PluginStore.storePlugins.count === 0) {
            PluginStore.fetchIndex();
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            ToggleButton {
                Layout.fillWidth: true
                explicitWidth: (root.cappedWidth - Tokens.spacing.medium) / 2
                label: qsTr("Installed")
                icon: "extension"
                toggled: root.currentTab === 0
                onClicked: root.currentTab = 0
            }

            ToggleButton {
                Layout.fillWidth: true
                explicitWidth: (root.cappedWidth - Tokens.spacing.medium) / 2
                label: qsTr("Store")
                icon: "store"
                toggled: root.currentTab === 1
                onClicked: root.currentTab = 1
            }
        }

        Item { Layout.preferredHeight: Tokens.spacing.large }

        // --- INSTALLED TAB ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.currentTab === 0
            spacing: Tokens.spacing.extraSmall / 2

            SectionHeader {
                first: true
                text: qsTr("Shell Plugins")
                visible: root.bundledCount > 0
            }
            Repeater {
                id: bundledRepeater

                model: CaelestiaApi.plugins.available
                delegate: ConnectedRect {
                    id: bundledDelegate

                    required property int index
                    required property string name
                    required property string version
                    required property string description
                    required property string source
                    required property string id
                    required property bool enabled
                    required property var settings

                    Layout.fillWidth: true
                    visible: bundledDelegate.source === "bundled"
                    first: bundledDelegate.index === 0
                    last: bundledDelegate.index === (bundledRepeater.count - 1)
                    implicitHeight: bundledRowLayout.implicitHeight + bundledRowLayout.anchors.margins * 2

                    RowLayout {
                        id: bundledRowLayout
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: bundledDelegate.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "v" + bundledDelegate.version + " • " + bundledDelegate.description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        StyledSwitch {
                            checked: bundledDelegate.enabled
                            onToggled: {
                                PluginLoader.setPluginEnabled(bundledDelegate.id || bundledDelegate.name, !bundledDelegate.enabled);
                            }
                        }
                        
                        IconButton {
                            icon: "settings"
                            type: IconButton.Tonal
                            visible: bundledDelegate.settings && bundledDelegate.settings.count > 0
                            onClicked: {
                                settingsPopup.pluginId = bundledDelegate.id || bundledDelegate.name;
                                settingsPopup.pluginName = bundledDelegate.name;
                                // Convert QQmlListModel to array if needed, but passing as is works for Repeater model
                                settingsPopup.settingsSchema = bundledDelegate.settings;
                                settingsPopup.open();
                            }
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("User Installed")
                visible: root.userCount > 0
                first: root.bundledCount === 0
            }
            Repeater {
                id: userRepeater

                model: CaelestiaApi.plugins.available
                delegate: ConnectedRect {
                    id: userDelegate

                    required property int index
                    required property string name
                    required property string version
                    required property string description
                    required property string source
                    required property string id
                    required property bool enabled
                    required property var settings

                    Layout.fillWidth: true
                    visible: userDelegate.source === "user"
                    first: userDelegate.index === 0
                    last: userDelegate.index === (userRepeater.count - 1)
                    implicitHeight: userRowLayout.implicitHeight + userRowLayout.anchors.margins * 2

                    RowLayout {
                        id: userRowLayout

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: userDelegate.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "v" + userDelegate.version + " • " + userDelegate.description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        StyledSwitch {
                            checked: userDelegate.enabled
                            onCheckedChanged: {
                                PluginLoader.setPluginEnabled(userDelegate.id || userDelegate.name, checked);
                            }
                        }

                        IconButton {
                            icon: "settings"
                            type: IconButton.Tonal
                            visible: userDelegate.settings && userDelegate.settings.count > 0
                            onClicked: {
                                settingsPopup.pluginId = userDelegate.id || userDelegate.name;
                                settingsPopup.pluginName = userDelegate.name;
                                settingsPopup.settingsSchema = userDelegate.settings;
                                settingsPopup.open();
                            }
                        }

                        IconButton {
                            icon: "delete"
                            type: IconButton.Tonal
                            onClicked: {
                                PluginStore.removePlugin(userDelegate.id || userDelegate.name);
                            }
                        }
                    }
                }
            }

            ConnectedRect {
                visible: CaelestiaApi.plugins.available.count === 0
                Layout.fillWidth: true
                first: true
                last: true
                implicitHeight: statusInst.implicitHeight + Tokens.padding.largeIncreased * 2

                RowLayout {
                    id: statusInst

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignTop
                        text: "extension_off"
                        fontStyle: Tokens.font.icon.large
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("No plugins installed")
                            font: Tokens.font.title.medium
                        }
                    }
                }
            }
        }

        // --- STORE TAB ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.currentTab === 1
            spacing: Tokens.spacing.extraSmall / 2

            ConnectedRect {
                visible: PluginStore.loading || PluginStore.installing || PluginStore.error
                Layout.fillWidth: true
                first: true
                last: storeRepeater.count === 0
                implicitHeight: storeStatusInst.implicitHeight + Tokens.padding.largeIncreased * 2

                RowLayout {
                    id: storeStatusInst

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignTop
                        text: PluginStore.error ? "error" : "downloading"
                        fontStyle: Tokens.font.icon.large
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: PluginStore.error ? PluginStore.errorMessage : (PluginStore.installing ? PluginStore.installProgress : qsTr("Loading store..."))
                            font: Tokens.font.title.medium
                        }
                    }
                }
            }

            SectionHeader {
                first: true
                text: qsTr("Available Plugins")
                visible: storeRepeater.count > 0 && !PluginStore.error
            }

            Repeater {
                id: storeRepeater

                model: PluginStore.storePlugins
                delegate: ConnectedRect {
                    id: storeDelegate

                    required property int index
                    required property string pluginId
                    required property string name
                    required property string version
                    required property string description
                    required property string path

                    // Direct bindings — re-evaluated automatically when PluginStore.installedPluginIds
                    // is reassigned (which happens on install/remove actions).
                    readonly property bool isInstalled: PluginStore.installedPluginIds.indexOf(storeDelegate.pluginId) !== -1
                    readonly property bool isUpdateAvailable: {
                        if (!isInstalled)
                            return false;
                        for (let i = 0; i < CaelestiaApi.plugins.available.count; i++) {
                            let p = CaelestiaApi.plugins.available.get(i);
                            if (p.id === storeDelegate.pluginId && p.version && storeDelegate.version) {
                                let v1 = storeDelegate.version.split('.');
                                let v2 = p.version.split('.');
                                for (let j = 0; j < Math.max(v1.length, v2.length); j++) {
                                    let n1 = parseInt(v1[j] || 0);
                                    let n2 = parseInt(v2[j] || 0);
                                    if (n1 > n2) return true;
                                    if (n1 < n2) break;
                                }
                            }
                        }
                        return false;
                    }

                    Layout.fillWidth: true
                    first: storeDelegate.index === 0
                    last: storeDelegate.index === (storeRepeater.count - 1)
                    implicitHeight: storeRow.implicitHeight + storeRow.anchors.margins * 2

                    RowLayout {
                        id: storeRow

                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: storeDelegate.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "v" + storeDelegate.version + " • " + storeDelegate.description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        TextButton {
                            text: storeDelegate.isUpdateAvailable ? qsTr("Update") : (storeDelegate.isInstalled ? qsTr("Installed") : qsTr("Install"))
                            enabled: (!storeDelegate.isInstalled || storeDelegate.isUpdateAvailable) && !PluginStore.installing
                            onClicked: {
                                PluginStore.installPlugin(storeDelegate.pluginId, storeDelegate.path);
                            }
                        }
                    }
                }
            }
        }
    }
}
