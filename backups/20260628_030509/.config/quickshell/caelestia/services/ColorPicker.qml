pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Item {
    id: root

    Process {
        id: dbusProcess
        command: [
            "dbus-send",
            "--session",
            "--print-reply",
            "--dest=org.kde.KWin",
            "/ColorPicker",
            "org.kde.kwin.ColorPicker.pick"
        ]
        
        stdout: StdioCollector {
            id: outCollector
            onStreamFinished: {
                // The output looks like:
                // method return time=1686000000 sender=:1.30 -> destination=:1.100 serial=101 reply_serial=2
                //    uint32 4294967295
                let text = outCollector.text;
                let match = text.match(/uint32\s+(\d+)/);
                if (match) {
                    let decimalColor = parseInt(match[1], 10);
                    // Convert to hex (ignoring alpha to get #RRGGBB)
                    let hex = (decimalColor & 0x00FFFFFF).toString(16).padStart(6, '0');
                    let colorCode = "#" + hex.toUpperCase();
                    
                    // Copy to clipboard using wl-copy
                    Quickshell.execDetached(["bash", "-c", `echo -n '${colorCode}' | wl-copy`]);
                    
                    // Notify user
                    Quickshell.execDetached(["notify-send", "Color Picker", `Color ${colorCode} copied to clipboard!`]);
                }
            }
        }
    }

    function pickColor() {
        if (!dbusProcess.running) {
            dbusProcess.running = true;
        }
    }
}
