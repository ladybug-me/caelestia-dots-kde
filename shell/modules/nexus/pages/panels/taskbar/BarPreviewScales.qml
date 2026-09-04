pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Per Element Scaling Offset")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            last: !Globalroot.nState.targetConfig.bar.perElementPreviewScale && !Globalroot.nState.targetConfig.bar.perElementFontScale
            text: qsTr("Enable per-element offsets")
            subtext: qsTr("Customize preview scale and font for each popout type")
            checked: Globalroot.nState.targetConfig.bar.perElementPreviewScale || Globalroot.nState.targetConfig.bar.perElementFontScale
            onToggled: {
                Globalroot.nState.targetConfig.bar.perElementPreviewScale = checked;
                Globalroot.nState.targetConfig.bar.perElementFontScale = checked;
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Globalroot.nState.targetConfig.bar.perElementPreviewScale || Globalroot.nState.targetConfig.bar.perElementFontScale
            spacing: Tokens.spacing.extraSmall / 2

            // Table Header
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.padding.medium
                Layout.bottomMargin: Tokens.padding.small
                Layout.leftMargin: Tokens.padding.largeIncreased
                Layout.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                TextButton {
                    text: qsTr("RESET ALL")
                    type: TextButton.Filled
                    ToolTip.text: qsTr("Reset all to 0")
                    ToolTip.visible: hovered
                    onClicked: {
                        const keys = ["activeWindow", "audio", "battery", "bluetooth", "dock", "github", "lockStatus", "network", "notifications", "peripheralBattery", "trayMenu", "wirelessPassword"];
                        for (let k of keys) {
                            Globalroot.nState.targetConfig.bar.previewScales[k] = 0.0;
                            Globalroot.nState.targetConfig.bar.previewFontScales[k] = 0.0;
                        }
                    }
                }

                Item { Layout.fillWidth: true } // Spacer to push headers to the right

                StyledText {
                    text: qsTr("Scale")
                    font: Tokens.font.label.large
                    Layout.preferredWidth: 156 // Matches CustomSpinBox width
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledText {
                    text: qsTr("Font")
                    font: Tokens.font.label.large
                    Layout.preferredWidth: 156 // Matches CustomSpinBox width
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            DoubleStepperRow {
                first: true
                last: false
                label: qsTr("Active window")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.activeWindow
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.activeWindow = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.activeWindow
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.activeWindow = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Audio")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.audio
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.audio = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.audio
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.audio = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Battery")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.battery
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.battery = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.battery
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.battery = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Bluetooth")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.bluetooth
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.bluetooth = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.bluetooth
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.bluetooth = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Dock")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.dock
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.dock = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.dock
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.dock = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("GitHub")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.github
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.github = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.github
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.github = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Lock status")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.lockStatus
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.lockStatus = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.lockStatus
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.lockStatus = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Network")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.network
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.network = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.network
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.network = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Notifications")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.notifications
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.notifications = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.notifications
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.notifications = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Peripheral battery")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.peripheralBattery
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.peripheralBattery = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.peripheralBattery
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.peripheralBattery = v
            }
            DoubleStepperRow {
                first: false
                last: false
                label: qsTr("Tray menu")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.trayMenu
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.trayMenu = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.trayMenu
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.trayMenu = v
            }
            DoubleStepperRow {
                first: false
                last: true
                label: qsTr("Wireless password")
                
                scaleValue: Globalroot.nState.targetConfig.bar.previewScales.wirelessPassword
                scaleFrom: -1.0; scaleTo: 1.0; scaleStepSize: 0.05
                onScaleMoved: v => Globalroot.nState.targetConfig.bar.previewScales.wirelessPassword = v
                
                fontValue: Globalroot.nState.targetConfig.bar.previewFontScales.wirelessPassword
                fontFrom: -1.0; fontTo: 1.0; fontStepSize: 0.05
                onFontMoved: v => Globalroot.nState.targetConfig.bar.previewFontScales.wirelessPassword = v
            }
        }
    }
}
