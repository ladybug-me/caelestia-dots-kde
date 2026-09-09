#!/usr/bin/env bash
# un03-remove-bridge.sh - remove the bridge/helper scripts installed to
# ~/.local/bin and the KWin bridge script.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

for f in \
    "$HOME/.local/bin/kcolorpicker" \
    "$HOME/.local/bin/qs-kwin-bridge.py" \
    "$HOME/.local/bin/caelestia-shortcuts" \
    "$HOME/.local/bin/caelestia-record" \
    "$HOME/.local/bin/caelestia-keyd-run" \
    "$HOME/.local/bin/caelestia-shell-ipc" \
    "$HOME/.local/bin/ydotoold-wrapper" \
    "$HOME/.local/bin/caelestia-update" \
    "$HOME/.local/bin/caelestia-check-updates"
do
    if [[ -f "$f" ]]; then
        rm -f "$f"
        ok "Removed: $f"
    fi
done

if [[ -d "$HOME/.local/share/kwin/scripts/quickshell-kde-bridge" ]]; then
    rm -rf "$HOME/.local/share/kwin/scripts/quickshell-kde-bridge"
    ok "Removed KWin script: quickshell-kde-bridge"
fi
