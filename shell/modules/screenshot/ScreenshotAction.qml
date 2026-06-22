pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell
import qs.services

Singleton {
    id: root

    enum Action {
        Copy,
        Edit,
        Search,
        CharRecognition,
        Record,
        RecordWithSound
    }

    property string imageSearchEngineBaseUrl: "https://lens.google.com/uploadbyurl?url="
    property string fileUploadApiEndpoint: "https://uguu.se/upload"

    function escapeShellStr(str) {
        if (!str) return "''";
        return str.replace(/'/g, "'\\''");
    }

    function getCommand(x, y, width, height, screenshotPath, action, saveDir = "") {
        // Set command for action
        const rx = Math.round(x);
        const ry = Math.round(y);
        const rw = Math.round(width);
        const rh = Math.round(height);

        const cropBase = `magick '${escapeShellStr(screenshotPath)}' `
            + `-crop ${rw}x${rh}+${rx}+${ry} +repage`
        const cropToFile = (outPath) => `${cropBase} '${escapeShellStr(outPath)}'`
        const cleanup = `rm -f '${escapeShellStr(screenshotPath)}'`
        const annotationCommand = `swappy -f -`; // default to swappy
        const uploadAndGetUrl = (filePath) => {
            return `curl -sF files[]=@'${escapeShellStr(filePath)}' ${root.fileUploadApiEndpoint} | jq -r '.files[0].url'`
        }
        
        const rawSaveDir = saveDir;

        switch (action) {
            case ScreenshotAction.Action.Copy: {
                let saveDir = rawSaveDir === "" ? "~/Pictures/Screenshots" : rawSaveDir;
                return [
                    "bash", "-c",
                    `set -euo pipefail; ` +
                    `SAVE_DIR='${escapeShellStr(saveDir)}'; ` +
                    `SAVE_DIR="\${SAVE_DIR/#\\~/$HOME}"; ` +
                    `mkdir -p "$SAVE_DIR" && ` +
                    `saveFile="$SAVE_DIR/screenshot-$(date +%Y-%m-%d_%H.%M.%S).png" && ` +
                    `${cropBase} "$saveFile" && ` +
                    `wl-copy -t image/png < "$saveFile"; ` +
                    `${cleanup}`
                ]
            }

            case ScreenshotAction.Action.Edit:
                return ["bash", "-c",
                    `set -euo pipefail; TMPF=$(mktemp /tmp/qs-snip-XXXXXX.png); ` +
                    `${cropBase} "$TMPF" && ` +
                    `${annotationCommand} < "$TMPF"; ` +
                    `rm -f "$TMPF"; ${cleanup}`
                ]

            case ScreenshotAction.Action.Search: {
                const tmpFile = "/tmp/qs-snip-search.png"
                return ["bash", "-c",
                    `set -euo pipefail; ` +
                    `${cropToFile(tmpFile)} && ` +
                    `xdg-open "${root.imageSearchEngineBaseUrl}$(${uploadAndGetUrl(tmpFile)})"; ` +
                    `rm -f '${tmpFile}'; ${cleanup}`
                ]
            }

            case ScreenshotAction.Action.CharRecognition:
                return ["bash", "-c",
                    `set -euo pipefail; TMPF=$(mktemp /tmp/qs-snip-XXXXXX.png); ` +
                    `${cropBase} "$TMPF" && ` +
                    `tesseract "$TMPF" stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | tr '\\n' '+' | sed 's/\\+$/\\n/') | wl-copy; ` +
                    `rm -f "$TMPF"; ${cleanup}`
                ]

            case ScreenshotAction.Action.Record:
                return ["bash", "-c", `spectacle -R r`]

            case ScreenshotAction.Action.RecordWithSound:
                return ["bash", "-c", `spectacle -R r`]

            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                return;
        }
    }
}
