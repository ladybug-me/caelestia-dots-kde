pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    readonly property string shellName: "fish"

    property string outputBuffer: ""
    property string currentDirectory: Paths.home
    property string currentSuggestion: ""
    property string hostname: ""
    property int activeProcessesCount: 0
    property bool isRunning: activeProcessesCount > 0

    readonly property string prompt: {
        const user = Quickshell.env("USER") || "user";
        return user + "@" + (root.hostname !== "" ? root.hostname : "caelestia");
    }

    function ansiToHtml(ansiStr) {
        let escaped = ansiStr.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

        let result = "";
        let regex = /\x1b\[([0-9;]*)m/g;
        let lastIndex = 0;
        let activeSpans = 0;
        let match;

        while ((match = regex.exec(escaped)) !== null) {
            result += escaped.substring(lastIndex, match.index);
            let codes = match[1].split(';').map(Number);

            if (codes.includes(0) || match[1] === "") {
                while (activeSpans > 0) {
                    result += "</span>";
                    activeSpans--;
                }
            }

            let styles = [];
            for (let code of codes) {
                if (code === 1) {
                    styles.push("font-weight: bold;");
                } else if (code === 3) {
                    styles.push("font-style: italic;");
                } else if (code === 4) {
                    styles.push("text-decoration: underline;");
                } else if (code >= 30 && code <= 37) {
                    const colors = {
                        30: "#1e1e2e" // Dark / Black
                        ,
                        31: "#f38ba8" // Red
                        ,
                        32: "#a6e3a1" // Green
                        ,
                        33: "#f9e2af" // Yellow
                        ,
                        34: "#89b4fa" // Blue
                        ,
                        35: "#cba6f7" // Magenta
                        ,
                        36: "#89dceb" // Cyan
                        ,
                        37: "#cdd6f4"  // White
                    };
                    styles.push("color: " + (colors[code] || "#cdd6f4") + ";");
                } else if (code >= 90 && code <= 97) {
                    const colors = {
                        90: "#585b70" // Bright Black (Gray)
                        ,
                        91: "#f38ba8" // Bright Red
                        ,
                        92: "#a6e3a1" // Bright Green
                        ,
                        93: "#f9e2af" // Bright Yellow
                        ,
                        94: "#89b4fa" // Bright Blue
                        ,
                        95: "#cba6f7" // Bright Magenta
                        ,
                        96: "#89dceb" // Bright Cyan
                        ,
                        97: "#cdd6f4"  // Bright White
                    };
                    styles.push("color: " + (colors[code] || "#cdd6f4") + ";");
                }
            }

            if (styles.length > 0) {
                result += "<span style=\"" + styles.join(" ") + "\">";
                activeSpans++;
            }

            lastIndex = regex.lastIndex;
        }

        result += escaped.substring(lastIndex);

        while (activeSpans > 0) {
            result += "</span>";
            activeSpans--;
        }

        // Wrap inside a <pre> tag with explicit monospace font-family styling to prevent spaces from collapsing in QML RichText
        return "<pre style=\"font-family: 'JetBrains Mono', Consolas, monospace; margin: 0;\">" + result.replace(/\n/g, "<br>") + "</pre>";
    }

    function scrollToBottom() {
        Qt.callLater(() => {
            if (outputFlickable) {
                outputFlickable.contentY = Math.max(0, outputFlickable.contentHeight - outputFlickable.height);
            }
        });
    }

    function startShell() {
        outputBuffer = ""; // Completely blank startup as requested
        outputArea.text = "";
    }

    property var activeShellProcess: null

    function sendCommand(text) {
        let trimmed = text.trim();
        if (trimmed === "")
            return;

        // Print folder path and command to the screen exactly like the shell
        outputBuffer += (outputBuffer === "" ? "" : "\n") + "\x1b[36m" + prompt + "\x1b[0m\n\x1b[32m❯\x1b[0m " + trimmed + "\n";
        outputArea.text = ansiToHtml(outputBuffer);
        scrollToBottom();

        if (trimmed === "clear") {
            clearOutput();
            return;
        }

        if (activeShellProcess !== null && activeShellProcess.running) {
            // Write to stdin of the active process
            activeShellProcess.write(trimmed + "\n");
            return;
        }

        if (trimmed.startsWith("cd ")) {
            let path = trimmed.substring(3).trim();
            changeDirectory(path);
            return;
        } else if (trimmed === "cd") {
            currentDirectory = Paths.home;
            return;
        }

        // Spawn command dynamically under fish shell - no pipe buffering issue!
        activeShellProcess = shellProcessComp.createObject(root, {
            command: ["fish", "-c", trimmed],
            workingDirectory: currentDirectory,
            running: true
        });
    }

    function changeDirectory(path) {
        if (path.startsWith("~")) {
            path = Paths.home + path.substring(1);
        }
        pwdResolverComp.createObject(root, {
            command: ["fish", "-c", "cd " + path + " && pwd"],
            workingDirectory: currentDirectory,
            running: true
        });
    }

    function clearOutput() {
        outputBuffer = "";
        outputArea.text = "";
    }

    implicitWidth: 840
    implicitHeight: 500

    Component.onCompleted: {
        startShell();
        hostnameResolverComp.createObject(root, {
            command: ["cat", "/etc/hostname"],
            running: true
        });
    }

    Component {
        id: shellProcessComp

        Process {
            running: false
            stdout: SplitParser {
                onRead: text => {
                    outputBuffer += text + "\n";
                    outputArea.text = ansiToHtml(outputBuffer);
                    scrollToBottom();
                }
            }
            stderr: SplitParser {
                onRead: text => {
                    outputBuffer += "\x1b[31m" + text + "\x1b[0m\n";
                    outputArea.text = ansiToHtml(outputBuffer);
                    scrollToBottom();
                }
            }
            Component.onCompleted: {
                activeProcessesCount++;
            }
            onExited: code => {
                activeProcessesCount--;
                destroy();
            }
        }
    }

    Component {
        id: pwdResolverComp

        Process {
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let resolved = this.text.trim();
                    if (resolved && resolved !== "") {
                        currentDirectory = resolved;
                    }
                    destroy();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    outputBuffer += "\x1b[31m" + this.text + "\x1b[0m\n";
                    outputArea.text = ansiToHtml(outputBuffer);
                    scrollToBottom();
                    destroy();
                }
            }
        }
    }

    Component {
        id: autocompleterComp

        Process {
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let suggestions = this.text.split("\n").map(s => s.trim()).filter(s => s !== "");
                    if (suggestions.length > 0) {
                        // Extract first suggestion before any tab description
                        let suggestion = suggestions[0].split("\t")[0];
                        let words = commandInput.text.split(" ");
                        let lastWord = words[words.length - 1];

                        if (suggestion.startsWith(lastWord)) {
                            words[words.length - 1] = suggestion;
                            commandInput.text = words.join(" ");
                            commandInput.cursorPosition = commandInput.text.length;
                        } else {
                            words[words.length - 1] = suggestion;
                            commandInput.text = words.join(" ");
                            commandInput.cursorPosition = commandInput.text.length;
                        }
                    }
                    destroy();
                }
            }
        }
    }

    Component {
        id: silentAutocompleterComp

        Process {
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let suggestions = this.text.split("\n").map(s => s.trim()).filter(s => s !== "");
                    if (suggestions.length > 0) {
                        let suggestion = suggestions[0].split("\t")[0];
                        let words = commandInput.text.split(" ");
                        let lastWord = words[words.length - 1];
                        let fullSuggestion = words.join(" ");

                        // Replace last word with the suggestion to construct full suggested command line
                        words[words.length - 1] = suggestion;
                        fullSuggestion = words.join(" ");

                        if (fullSuggestion.startsWith(commandInput.text)) {
                            currentSuggestion = fullSuggestion;
                        } else {
                            currentSuggestion = "";
                        }
                    } else {
                        currentSuggestion = "";
                    }
                    destroy();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    destroy();
                }
            }
        }
    }

    Timer {
        id: autocompleteDebounceTimer

        interval: 80 // Responsive but light debouncing
        repeat: false
        onTriggered: {
            let typed = commandInput.text;
            if (typed.trim() === "") {
                currentSuggestion = "";
                return;
            }
            silentAutocompleterComp.createObject(root, {
                command: ["fish", "-c", "complete -C\"" + typed.replace(/"/g, "\\\"") + "\""],
                workingDirectory: currentDirectory,
                running: true
            });
        }
    }

    Component {
        id: hostnameResolverComp

        Process {
            running: false
            stdout: StdioCollector {
                onStreamFinished: {
                    let resolved = this.text.trim();
                    if (resolved && resolved !== "") {
                        root.hostname = resolved;
                    }
                    destroy();
                }
            }
        }
    }

    StyledRect {
        anchors.fill: parent

        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            // Terminal output area
            StyledFlickable {
                id: outputFlickable

                Layout.fillWidth: true
                Layout.fillHeight: true

                contentWidth: width
                contentHeight: outputArea.implicitHeight + Tokens.padding.small * 2
                flickableDirection: Flickable.VerticalFlick

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: outputFlickable
                }

                TextEdit {
                    id: outputArea

                    width: outputFlickable.width - Tokens.padding.small * 2
                    x: Tokens.padding.small
                    y: Tokens.padding.small

                    readOnly: true
                    selectByMouse: true
                    cursorVisible: false
                    textFormat: TextEdit.RichText
                    wrapMode: TextEdit.Wrap
                    font: Tokens.font.mono.small
                    color: "#eceff4" // Nord Snow Storm (Bright off-white for perfect readability)
                }
            }

            // Input area - Switched to a standard Rectangle with Colours.palette.m3surfaceContainer and correct rounding
            Rectangle {
                id: inputBoxRect

                Layout.fillWidth: true
                Layout.preferredHeight: 36

                radius: Tokens.rounding.medium // Corrected to match standard dashboard input fields
                color: Colours.palette.m3surfaceContainer // Solid standard surfaceContainer background
                border.width: 0 // Removed outline border completely

                RowLayout {
                    id: inputRow

                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: root.prompt + " ❯"
                        font: Tokens.font.mono.small
                        color: "#a6e3a1" // Vibrant, bright Catppuccin Green for excellent contrast
                    }

                    // Text fields container to overlay ghost autocomplete text behind typing text
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            id: ghostText

                            anchors.fill: parent
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0

                            font: commandInput.font
                            verticalAlignment: Text.AlignVCenter
                            textFormat: Text.RichText

                            text: {
                                let typed = commandInput.text;
                                let escapedTyped = typed.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                                let suggestionColor = Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.35).toString();

                                if (currentSuggestion !== "" && currentSuggestion.startsWith(typed)) {
                                    let suffix = currentSuggestion.substring(typed.length);
                                    let escapedSuffix = suffix.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                                    return "<span style='color: transparent;'>" + escapedTyped + "</span>" + "<span style='color: " + suggestionColor + ";'>" + escapedSuffix + "</span>";
                                }
                                return "";
                            }
                        }

                        StyledTextField {
                            id: commandInput

                            property var commandHistory: []
                            property int historyIndex: -1
                            property string tempTypedText: ""

                            anchors.fill: parent
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0

                            font: Tokens.font.mono.small
                            selectedTextColor: Colours.palette.m3onSurface // Ensure highlighted/selected text is fully visible

                            background: null
                            focus: true

                            onVisibleChanged: {
                                if (visible) {
                                    forceActiveFocus();
                                }
                            }

                            onTextChanged: {
                                autocompleteDebounceTimer.restart();
                            }

                            // Press Right Arrow key to accept the suggestion
                            Keys.onRightPressed: event => {
                                if (currentSuggestion !== "" && currentSuggestion.startsWith(text) && cursorPosition === text.length) {
                                    text = currentSuggestion;
                                    cursorPosition = text.length;
                                    event.accepted = true;
                                } else {
                                    event.accepted = false; // Normal cursor move
                                }
                            }

                            // Traverse history up with arrow key
                            Keys.onUpPressed: event => {
                                if (commandHistory.length === 0)
                                    return;
                                if (historyIndex === -1) {
                                    tempTypedText = text;
                                    historyIndex = commandHistory.length - 1;
                                } else if (historyIndex > 0) {
                                    historyIndex--;
                                }
                                text = commandHistory[historyIndex];
                                cursorPosition = text.length;
                                event.accepted = true;
                            }

                            // Traverse history down with arrow key
                            Keys.onDownPressed: event => {
                                if (historyIndex === -1)
                                    return;
                                if (historyIndex < commandHistory.length - 1) {
                                    historyIndex++;
                                    text = commandHistory[historyIndex];
                                } else {
                                    historyIndex = -1;
                                    text = tempTypedText;
                                }
                                cursorPosition = text.length;
                                event.accepted = true;
                            }

                            // Trigger native fish autocompletion on Tab key press
                            Keys.onTabPressed: event => {
                                if (currentSuggestion !== "" && currentSuggestion.startsWith(text)) {
                                    text = currentSuggestion;
                                    cursorPosition = text.length;
                                    event.accepted = true;
                                } else {
                                    let typed = text;
                                    if (typed.trim() === "")
                                        return;

                                    autocompleterComp.createObject(root, {
                                        command: ["fish", "-c", "complete -C\"" + typed.replace(/"/g, "\\\"") + "\""],
                                        workingDirectory: currentDirectory,
                                        running: true
                                    });
                                    event.accepted = true;
                                }
                            }

                            onAccepted: {
                                const cmd = text;
                                text = "";
                                if (cmd.trim() !== "") {
                                    if (commandHistory.length === 0 || commandHistory[commandHistory.length - 1] !== cmd) {
                                        commandHistory.push(cmd);
                                        commandHistory = commandHistory; // Notify QML bindings
                                    }
                                }
                                historyIndex = -1;
                                tempTypedText = "";
                                currentSuggestion = "";
                                root.sendCommand(cmd);
                            }
                        }
                    }
                }
            }
        }
    }
}
