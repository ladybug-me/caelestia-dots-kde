pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common
import api 1.0

PageBase {
    id: root

    title: qsTr("Plugins")

    property int currentTab: 0 // 0 = Installed, 1 = Store

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
                visible: bundledRepeater.count > 0
            }
            Repeater {
                id: bundledRepeater
                model: CaelestiaApi.plugins.available
                delegate: ToggleRow {
                    Layout.fillWidth: true
                    visible: source === "bundled"
                    first: index === 0
                    last: index === (bundledRepeater.count - 1)
                    
                    text: name
                    subtext: "v" + version + " • " + description
                    
                    checked: enabled
                    onToggled: {
                        PluginLoader.setPluginEnabled(id || name, checked);
                    }
                }
            }

            SectionHeader {
                text: qsTr("User Installed")
                visible: userRepeater.count > 0
            }
            Repeater {
                id: userRepeater
                model: CaelestiaApi.plugins.available
                delegate: ConnectedRect {
                    Layout.fillWidth: true
                    visible: source === "user"
                    first: index === 0
                    last: index === (userRepeater.count - 1)
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
                                text: name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "v" + version + " • " + description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }

                        StyledSwitch {
                            checked: enabled
                            onCheckedChanged: {
                                PluginLoader.setPluginEnabled(id || name, checked);
                            }
                        }
                        
                        IconButton {
                            icon: "delete"
                            type: IconButton.Tonal
                            onClicked: {
                                CaelestiaApi.plugins.store.removePlugin(id || name);
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
                    Layout.fillWidth: true
                    first: index === 0
                    last: index === (storeRepeater.count - 1)
                    implicitHeight: storeRow.implicitHeight + storeRow.anchors.margins * 2
                    
                    property bool isInstalled: {
                        let installed = false;
                        for (let i = 0; i < CaelestiaApi.plugins.available.count; i++) {
                            if (CaelestiaApi.plugins.available.get(i).id === model.id) {
                                installed = true;
                                break;
                            }
                        }
                        return installed;
                    }

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
                                text: name
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                            }
                            StyledText {
                                text: "v" + version + " • " + description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        
                        TextButton {
                            text: isInstalled ? qsTr("Installed") : qsTr("Install")
                            enabled: !isInstalled && !CaelestiaApi.plugins.store.installing
                            onClicked: {
                                CaelestiaApi.plugins.store.installPlugin(model.id, model.path);
                            }
                        }
                    }
                }
            }
        }
    }
}
