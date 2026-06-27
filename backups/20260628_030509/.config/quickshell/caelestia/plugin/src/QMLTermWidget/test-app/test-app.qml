import QtQuick 2.0
import QMLTermWidget 2.0
import QtQuick.Controls

Rectangle {
    width: 640
    height: 480

    Action{
        onTriggered: terminal.copyClipboard();
        shortcut: "Ctrl+Shift+C"
    }

    Action{
        onTriggered: terminal.pasteClipboard();
        shortcut: "Ctrl+Shift+V"
    }

    Action{
        onTriggered: searchButton.visible = !searchButton.visible
        shortcut: "Ctrl+F"
    }

    Action{
        onTriggered:{
            console.log('open new terminal window in:'+mainsession.currentDir)
        }
        shortcut: "Ctrl+Shift+T"
    }

    QMLTermWidget {
        id: terminal
        anchors.fill: parent
        font.family: "Monospace"
        font.pointSize: 12
        colorScheme: "cool-retro-term"
        session: QMLTermSession{
            id: mainsession
            initialWorkingDirectory: "$HOME"
            onMatchFound: {
                console.log("found at: %1 %2 %3 %4".arg(startColumn).arg(startLine).arg(endColumn).arg(endLine));
            }
            onNoMatchFound: {
                console.log("not found");
            }
        }
        onTerminalUsesMouseChanged: console.log(terminalUsesMouse);
        onTerminalSizeChanged: console.log(terminalSize);
        Component.onCompleted: mainsession.startShellProgram();

        QMLTermScrollbar {
            terminal: terminal
            width: 20
            Rectangle {
                opacity: 0.4
                anchors.margins: 5
                radius: width * 0.5
                anchors.fill: parent
            }
        }

    }

    Button {
        id: searchButton
        text: "Find version"
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        visible: false
        onClicked: mainsession.search("version");
    }
    Component.onCompleted: terminal.forceActiveFocus();
}
