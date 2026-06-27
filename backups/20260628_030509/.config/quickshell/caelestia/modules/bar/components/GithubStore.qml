pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property var days: []
    property int total: 0
    property string username: ""
    property string lastError: ""
    property bool available: false
}
