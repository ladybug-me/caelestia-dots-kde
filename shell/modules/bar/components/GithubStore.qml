pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property var days: []
    property int total: 0
    property string username: ""
    property string lastError: ""
    // True when no personal access token is stored. A configuration state the UI
    // reports, distinct from a fetch that failed.
    property bool tokenMissing: false
    // Set once the user has been told the token is missing, so every bar on every
    // screen does not repeat the notice.
    property bool tokenNoticeShown: false
    property bool available: false

    signal refresh()
}
