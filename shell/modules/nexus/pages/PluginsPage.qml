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
        IconButton {
            icon: "refresh"
            font: Tokens.font.icon.medium
            type: IconButton.Tonal
            onClicked: {
                if (root.currentTab === 0) {
                    PluginLoader.reloadPlugins();
                } else {
                    CaelestiaApi.plugins.store.fetchIndex();
                }
            }
        }
    ]

    Component.onCompleted: {
        if (CaelestiaApi.plugins.store.storePlugins.count === 0) {
            CaelestiaApi.plugins.store.fetchIndex();
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
                label: qsTr("Installed")
                icon: "extension"
                toggled: root.currentTab === 0
                onClicked: root.currentTab = 0
            }

            ToggleButton {
                Layout.fillWidth: true
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
                                CaelestiaApi.plugins.store.removePlugin(userDelegate.id || userDelegate.name);
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
                visible: CaelestiaApi.plugins.store.loading || CaelestiaApi.plugins.store.installing || CaelestiaApi.plugins.store.error
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
                        text: CaelestiaApi.plugins.store.error ? "error" : "downloading"
                        fontStyle: Tokens.font.icon.large
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: CaelestiaApi.plugins.store.error ? CaelestiaApi.plugins.store.errorMessage : (CaelestiaApi.plugins.store.installing ? CaelestiaApi.plugins.store.installProgress : qsTr("Loading store..."))
                            font: Tokens.font.title.medium
                        }
                    }
                }
            }

            SectionHeader {
                first: true
                text: qsTr("Available Plugins")
                visible: storeRepeater.count > 0 && !CaelestiaApi.plugins.store.error
            }

            Repeater {
                id: storeRepeater

                model: CaelestiaApi.plugins.store.storePlugins
                delegate: ConnectedRect {
                    id: storeDelegate

                    required property int index
                    required property string name
                    required property string version
                    required property string description
                    required property string id
                    required property string path

                    property bool isInstalled: {
                        let installed = false;
                        for (let i = 0; i < CaelestiaApi.plugins.available.count; i++) {
                            if (CaelestiaApi.plugins.available.get(i).id === storeDelegate.id) {
                                installed = true;
                                break;
                            }
                        }
                        return installed;
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
                                text: storeDelegate.name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: "v" + storeDelegate.version + " • " + storeDelegate.description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        TextButton {
                            text: storeDelegate.isInstalled ? qsTr("Installed") : qsTr("Install")
                            enabled: !storeDelegate.isInstalled && !CaelestiaApi.plugins.store.installing
                            onClicked: {
                                CaelestiaApi.plugins.store.installPlugin(storeDelegate.id, storeDelegate.path);
                            }
                        }
                    }
                }
            }
        }
    }
}
