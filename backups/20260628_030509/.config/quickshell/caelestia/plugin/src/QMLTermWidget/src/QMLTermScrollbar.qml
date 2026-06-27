import QtQuick 2.0
import QMLTermWidget 2.0

Item {
    property QMLTermWidget terminal

    property int value: terminal.scrollbarCurrentValue
    property int minimum: terminal.scrollbarMinimum
    property int maximum: terminal.scrollbarMaximum
    property int lines: terminal.lines
    property int totalLines: lines + maximum

    anchors.right: terminal.right

    opacity: 0.0

    height: terminal.height * (lines / (totalLines - minimum))
    y: (terminal.height / (totalLines)) * (value - minimum)

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    function showScrollbar() {
        opacity = 1.0;
        hideTimer.restart();
    }

    Connections {
        target: terminal
        onScrollbarValueChanged: showScrollbar()
    }

    Timer {
        id: hideTimer
        onTriggered: parent.opacity = 0;
    }
}
