import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Caelestia.Config
import Caelestia.Services

Scope {
    id: root

    required property var lock

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    readonly property alias howdy: howdy
    property string lockMessage
    property string state
    property string fprintState
    property string howdyState
    property string buffer

    signal flashMsg

    function handleKey(event: KeyEvent): void {
        if (passwd.active || state === "max")
            return;

        // Trigger howdy on an empty-buffer Enter so face unlock can start
        // without typing a character first.
        if (howdy.canAttempt && !howdy.active && (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) && buffer.length === 0)
            return howdy.start();

        if (howdy.active)
            howdy.abort();

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            passwd.start();
        } else if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier) {
                buffer = "";
            } else {
                buffer = buffer.slice(0, -1);
            }
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            // Allow anything except control characters
            buffer += event.text;
        }
    }

    PamContext {
        id: passwd

        config: "passwd"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onMessageChanged: {
            if (message.startsWith("The account is locked"))
                root.lockMessage = message;
            else if (root.lockMessage && message.endsWith(" left to unlock)"))
                root.lockMessage += "\n" + message;
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;

            respond(root.buffer);
            root.buffer = "";
        }

        onCompleted: res => {
            if (res === PamResult.Success)
                return root.lock.unlock();

            if (res === PamResult.Error)
                root.state = "error";
            else if (res === PamResult.MaxTries)
                root.state = "max";
            else if (res === PamResult.Failed)
                root.state = "fail";

            root.flashMsg();
            stateReset.restart();
        }
    }

    PamContext {
        id: fprint

        property bool available
        property int tries
        property int errorTries

        function checkAvail(): void {
            if (!available || !GlobalConfig.lock.enableFprint || !root.lock.secure) {
                abort();
                return;
            }

            tries = 0;
            errorTries = 0;
            start();
        }

        config: "fprint"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onCompleted: res => {
            if (!available)
                return;

            if (res === PamResult.Success)
                return root.lock.unlock();

            if (res === PamResult.Error) {
                root.fprintState = "error";
                errorTries++;
                if (errorTries < 5) {
                    abort();
                    errorRetry.restart();
                }
            } else if (res === PamResult.MaxTries) {
                // Isn't actually the real max tries as pam only reports completed
                // when max tries is reached.
                tries++;
                if (tries < GlobalConfig.lock.maxFprintTries) {
                    // Restart if not actually real max tries
                    root.fprintState = "fail";
                    start();
                } else {
                    root.fprintState = "max";
                    abort();
                }
            }

            root.flashMsg();
            fprintStateReset.start();
        }
    }

    Process {
        id: availProc

        command: ["sh", "-c", "fprintd-list $USER"]
        onExited: code => { // qmllint disable signal-handler-parameters
            fprint.available = code === 0;
            fprint.checkAvail();
        }
    }

    PamContext {
        id: howdy

        property bool available
        property int tries
        property int errorTries
        readonly property bool canAttempt: available && GlobalConfig.lock.enableHowdy && root.lock.secure

        function checkAvail(): void {
            if (!available || !GlobalConfig.lock.enableHowdy || !root.lock.secure) {
                abort();
                return;
            }

            tries = 0;
            errorTries = 0;
            start();
        }

        config: "howdy"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onCompleted: res => {
            if (!available)
                return;

            if (res === PamResult.Success)
                return root.lock.unlock();

            if (res === PamResult.Error) {
                root.howdyState = "error";
                errorTries++;
                if (errorTries < 5) {
                    abort();
                    howdyErrorRetry.restart();
                }
            } else if (res === PamResult.MaxTries) {
                tries++;
                if (tries < GlobalConfig.lock.maxHowdyTries) {
                    root.howdyState = "fail";
                    start();
                } else {
                    root.howdyState = "max";
                    abort();
                }
            }

            root.flashMsg();
            howdyStateReset.start();
        }
    }

    Process {
        id: howdyAvailProc

        command: ["sh", "-c", "command -v howdy"]
        onExited: code => { // qmllint disable signal-handler-parameters
            howdy.available = code === 0;
            howdy.checkAvail();
        }
    }

    Timer {
        id: errorRetry

        interval: 800
        onTriggered: fprint.start()
    }

    Timer {
        id: stateReset

        interval: 4000
        onTriggered: {
            if (root.state !== "max")
                root.state = "";
        }
    }

    Timer {
        id: fprintStateReset

        interval: 4000
        onTriggered: {
            root.fprintState = "";
            fprint.errorTries = 0;
        }
    }

    Timer {
        id: howdyErrorRetry

        interval: 800
        onTriggered: howdy.start()
    }

    Timer {
        id: howdyStateReset

        interval: 4000
        onTriggered: {
            root.howdyState = "";
            howdy.errorTries = 0;
        }
    }

    Connections {
        function onSecureChanged(): void {
            if (root.lock.secure) {
                availProc.running = true;
                howdyAvailProc.running = true;
                root.buffer = "";
                root.state = "";
                root.fprintState = "";
                root.howdyState = "";
                root.lockMessage = "";
            }
        }

        function onUnlock(): void {
            fprint.abort();
            howdy.abort();
        }

        target: root.lock
    }

    Connections {
        function onEnableFprintChanged(): void {
            fprint.checkAvail();
        }

        function onEnableHowdyChanged(): void {
            if (!GlobalConfig.lock.enableHowdy && howdy.active)
                howdy.abort();
        }

        target: GlobalConfig.lock
    }

    Connections {
        function onResumed(): void {
            if (howdy.canAttempt && !howdy.active && GlobalConfig.lock.triggerHowdyOnWake)
                howdy.start();
        }

        target: SessionManager
    }
}
