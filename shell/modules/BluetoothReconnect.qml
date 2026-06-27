import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config

Scope {
    id: root

    // Keep track of addresses we have already attempted to reconnect in this session
    property var attemptedDevices: ({})

    // Monitor the adapter status, devices list, and config list
    readonly property bool adapterEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property var devicesList: Bluetooth.devices.values
    readonly property var autoReconnectList: GlobalConfig.services.bluetoothAutoReconnectDevices

    function checkAndReconnect() {
        if (!adapterEnabled)
            return;

        const list = autoReconnectList;
        if (!list || list.length === 0)
            return;

        for (let i = 0; i < devicesList.length; i++) {
            const device = devicesList[i];
            if (!device || !device.address)
                continue;

            if (list.indexOf(device.address) !== -1) {
                if (!attemptedDevices[device.address]) {
                    // Mark as attempted before calling connect to prevent multiple calls
                    attemptedDevices[device.address] = true;

                    if (device.state === BluetoothDeviceState.Disconnected) { // qmllint disable unresolved-type
                        console.log("[BluetoothReconnect] Reconnecting device on startup:", device.name, device.address);
                        device.connected = true;
                    }
                }
            }
        }
    }

    onDevicesListChanged: checkAndReconnect()
    onAdapterEnabledChanged: checkAndReconnect()
    onAutoReconnectListChanged: checkAndReconnect()

    Component.onCompleted: checkAndReconnect()
}
