import "../singletons"
import QtQuick

Column {
    id: root

    spacing: -12

    property real centerScale: 0.90
    property date currentTime: new Date()
    readonly property var fontAxesHours: ({
            "wght": 500,
            "wdth": 30,
            "ROND": 25,
            "opsz": 224 * centerScale
        })
    readonly property var fontAxesMinutes: ({
            "wght": 500,
            "wdth": 30,
            "ROND": 25,
            "opsz": 224 * centerScale
        })
    readonly property var fontAxesDate: ({
            "wght": 500,
            "wdth": 30,
            "ROND": 25,
            "opsz": 7
        })

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    Row {
        id: timeRow

        height: Math.round(224 * root.centerScale)
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            id: hourText

            height: parent.height
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
            font.family: Theme.fontFamily
            font.variableAxes: root.fontAxesHours
            font.pixelSize: Math.round(224 * root.centerScale)
            color: Qt.lighter(Theme.mPrimary, 1.6)
            text: Qt.formatTime(root.currentTime, "hh")
        }

        Item {
            width: 5
            height: 1
        }

        Text {
            id: minuteText

            height: parent.height
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
            font.family: Theme.fontFamily
            font.variableAxes: root.fontAxesMinutes
            font.pixelSize: Math.round(224 * root.centerScale)
            color: Theme.mSecondary
            text: Qt.formatTime(root.currentTime, "mm")
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        renderType: Text.QtRendering
        text: (Qt.formatDateTime(root.currentTime, "dddd").toUpperCase() + " • " + Qt.formatDateTime(root.currentTime, "d MMM").toUpperCase())
        font.pixelSize: 24
        font.family: Theme.fontFamily
        font.variableAxes: root.fontAxesDate
        color: Theme.mPrimary
    }
}
