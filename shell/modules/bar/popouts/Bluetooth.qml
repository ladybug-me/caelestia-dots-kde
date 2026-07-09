pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal

    readonly property real masterScale: !isNaN(GlobalConfig.bar.previewScale) ? GlobalConfig.bar.previewScale : 1.0
    readonly property real elementOffset: GlobalConfig.bar.perElementPreviewScale ? (!isNaN(GlobalConfig.bar.previewScales.bluetooth) ? GlobalConfig.bar.previewScales.bluetooth : 0.0) : 0.0
    readonly property real barScaleOffset: GlobalConfig.bar.previewScaleWithBar ? (!isNaN(GlobalConfig.bar.scale) ? GlobalConfig.bar.scale : 1.0) : 1.0
    readonly property real scaleOffset: Math.max(0.1, (masterScale + elementOffset) * barScaleOffset)
    readonly property real elementFontOffset: GlobalConfig.bar.perElementFontScale ? (!isNaN(GlobalConfig.bar.previewFontScales.bluetooth) ? GlobalConfig.bar.previewFontScales.bluetooth : 0.0) : 0.0
    readonly property real fontScale: Math.max(0.1, scaleOffset + (!isNaN(GlobalConfig.bar.fontScaleOffset) ? GlobalConfig.bar.fontScaleOffset : 0.0) + elementFontOffset)

    width: Math.max(300 * scaleOffset, _isSidebarOpen ? (Tokens.sizes.sidebar.width * scaleOffset) - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.small * scaleOffset

    StyledText {
        Layout.topMargin: Tokens.padding.medium * root.scaleOffset
        Layout.leftMargin: Tokens.padding.small * root.scaleOffset
        text: qsTr("Bluetooth")
        font.weight: 500
        font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2 * root.scaleOffset
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2 * root.scaleOffset
        radius: Tokens.rounding.medium * root.scaleOffset
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: cardLayout

            width: parent.width - Tokens.padding.medium * 2 * root.scaleOffset
            x: Tokens.padding.medium * root.scaleOffset
            y: Tokens.padding.medium * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

    Toggle {
        label: qsTr("Enabled")
        checked: Bluetooth.defaultAdapter?.enabled ?? false // qmllint disable unresolved-type
        toggle.onToggled: {
            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
            if (adapter)
                adapter.enabled = checked;
        }
    }

    Toggle {
        label: qsTr("Discovering")
        checked: Bluetooth.defaultAdapter?.discovering ?? false // qmllint disable unresolved-type
        toggle.onToggled: {
            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
            if (adapter)
                adapter.discovering = checked;
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.small * root.scaleOffset
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        text: {
            const devices = Bluetooth.devices.values; // qmllint disable unresolved-type
            let available = qsTr("%1 device%2 available").arg(devices.length).arg(devices.length === 1 ? "" : "s");
            const connected = devices.filter(d => d.connected).length;
            if (connected > 0)
                available += qsTr(" (%1 connected)").arg(connected);
            return available;
        }
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
    }

    Repeater {
        model: ScriptModel {
            values: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)).slice(0, 5) // qmllint disable unresolved-type
        }

        RowLayout {
            id: device

            required property BluetoothDevice modelData
            readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting // qmllint disable unresolved-type

            Layout.fillWidth: true
            Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
            spacing: Tokens.spacing.small * root.scaleOffset

            opacity: 0
            scale: 0.7

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {}
            }

            MaterialIcon {
                text: Icons.getBluetoothIcon(device.modelData.icon)
                fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
            }

            StyledText {
                Layout.leftMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.rightMargin: Tokens.spacing.extraSmall * root.scaleOffset
                Layout.fillWidth: true
                text: device.modelData.name
                elide: Text.ElideRight
                font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
            }

            RowLayout {
                visible: device.modelData.state === BluetoothDeviceState.Connected  // qmllint disable unresolved-type
                spacing: Tokens.spacing.extraSmall * root.scaleOffset

                MaterialIcon {
                    text: device.modelData.batteryAvailable ? Icons.getBatteryIcon(device.modelData.battery) : "battery_alert"
                    color: device.modelData.batteryAvailable && device.modelData.battery < 0.2 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                }

                StyledText {
                    visible: device.modelData.batteryAvailable // qmllint disable unresolved-type
                    text: device.modelData.batteryAvailable ? qsTr("%1%").arg(Math.round(device.modelData.battery * 100)) : "" // qmllint disable unresolved-type
                    font.pointSize: Tokens.font.body.small.pointSize * root.fontScale
                    color: device.modelData.batteryAvailable && device.modelData.battery < 0.2 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                }
            }

            StyledRect {
                id: connectBtn

                implicitWidth: implicitHeight
                implicitHeight: connectIcon.implicitHeight + Tokens.padding.extraSmall * root.scaleOffset

                radius: Tokens.rounding.full * root.scaleOffset
                color: Qt.alpha(Colours.palette.m3primary, device.modelData.state === BluetoothDeviceState.Connected ? 1 : 0) // qmllint disable unresolved-type

                CircularIndicator {
                    anchors.fill: parent
                    running: device.loading
                }

                StateLayer {
                    color: device.modelData.state === BluetoothDeviceState.Connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface // qmllint disable unresolved-type
                    disabled: device.loading
                    onClicked: device.modelData.connected = !device.modelData.connected
                }

                MaterialIcon {
                    id: connectIcon

                    anchors.centerIn: parent
                    animate: true
                    text: device.modelData.connected ? "link_off" : "link"
                    color: device.modelData.state === BluetoothDeviceState.Connected ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface // qmllint disable unresolved-type
                    fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale

                    opacity: device.loading ? 0 : 1

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }
            }

            Loader {
                visible: status === Loader.Ready
                asynchronous: true
                active: device.modelData.bonded
                sourceComponent: Item {
                    implicitWidth: connectBtn.implicitWidth
                    implicitHeight: connectBtn.implicitHeight

                    StateLayer {
                        radius: Tokens.rounding.full * root.scaleOffset
                        onClicked: device.modelData.forget()
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "delete"
                        fontStyle.pointSize: Tokens.font.icon.medium.pointSize * root.fontScale
                    }
                }
            }
        }
    }

        }
    }

    IconTextButton {
        Layout.fillWidth: true
        inactiveColour: Colours.palette.m3primaryContainer
        inactiveOnColour: Colours.palette.m3onPrimaryContainer
        verticalPadding: Tokens.padding.small * root.scaleOffset
        text: qsTr("Open settings")
        icon: "settings"

        onClicked: root.popouts.detachRequested("bluetooth")
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Tokens.padding.extraSmall * root.scaleOffset
        spacing: Tokens.spacing.medium * root.scaleOffset

        StyledText {
            Layout.fillWidth: true
            text: parent.label
            font.pointSize: Tokens.font.body.medium.pointSize * root.fontScale
        }

        StyledSwitch {
            id: toggle
        }
    }
}
