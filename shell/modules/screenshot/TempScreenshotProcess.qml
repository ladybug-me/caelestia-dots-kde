import QtQuick
import Quickshell
import Quickshell.Io

Process {
    id: screenshotProc
    running: true
    property string screenshotDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/caelestia-screenshot`
    required property ShellScreen screen
    property string screenshotPath: `${screenshotDir}/image-${screen.name}.png`
    command: ["bash", "-c", `mkdir -p '${screenshotDir}' && spectacle -b -n -f -o '${screenshotPath}'`]
}
