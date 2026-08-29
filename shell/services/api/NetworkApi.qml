import "../" as Services
import QtQuick
import Caelestia as Backend

QtObject {
    readonly property var manager: Backend.NmQt
    readonly property var requests: Backend.Requests
    readonly property var usage: Services.NetworkUsage
    readonly property var vpn: Services.VPN
}
