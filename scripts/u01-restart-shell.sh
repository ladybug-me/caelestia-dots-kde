#!/usr/bin/env bash
# u01-restart-shell.sh  Restart the running Caelestia shell after an update

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

if command -v caelestia >/dev/null 2>&1; then
    CAELESTIA_BIN=$(command -v caelestia)
elif [[ -x "$HOME/.local/bin/caelestia" ]]; then
    CAELESTIA_BIN="$HOME/.local/bin/caelestia"
elif [[ -x "/usr/local/bin/caelestia" ]]; then
    CAELESTIA_BIN="/usr/local/bin/caelestia"
elif [[ -x "/usr/bin/caelestia" ]]; then
    CAELESTIA_BIN="/usr/bin/caelestia"
else
    CAELESTIA_BIN="caelestia"
fi

# Resolve a reliable way to talk to the running shell instance. Prefer the
# (now-patched) CLI; fall back to the path-based IPC wrapper.
SHELL_IPC=""
if [[ -x "$HOME/.local/bin/caelestia-shell-ipc" ]]; then
    SHELL_IPC="$HOME/.local/bin/caelestia-shell-ipc"
fi

info "Stopping the running shell..."
if "$CAELESTIA_BIN" shell -k 2>/dev/null; then
    : # CLI succeeded
elif [[ -n "$SHELL_IPC" ]] && "$SHELL_IPC" quit 2>/dev/null; then
    : # IPC wrapper succeeded
else
    pkill -f "quickshell.*caelestia/shell.qml" 2>/dev/null || true
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
SCHEME_FILE="$STATE_DIR/scheme.json"
i=0
while [[ $i -lt 15 && ! -s "$SCHEME_FILE" ]]; do
    sleep 1
    i=$((i + 1))
done

info "Starting the shell..."
# The IPC wrapper is preferred over the CLI here because it starts the shell
# as a transient user service: the CLI's `shell -d` daemonizes, which points
# the shell's stdio at /dev/null, and every application launched from the
# shell then inherits a stdout that goes nowhere. Vesktop deadlocks when a
# call starts in exactly that state (issue #402).
if [[ -n "$SHELL_IPC" ]]; then
    "$SHELL_IPC" start 2>/dev/null &
elif command -v systemd-run >/dev/null 2>&1; then
    QUICKSHELL_PATH="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null || echo quickshell)"
    export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml"
    export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"
    systemd-run --user --quiet --collect --unit=caelestia-shell \
        --description="Caelestia Shell" \
        -- "$QUICKSHELL_PATH" -n -p "$HOME/.config/quickshell/caelestia/shell.qml" &
elif command -v "$CAELESTIA_BIN" >/dev/null 2>&1; then
    "$CAELESTIA_BIN" shell -d >/dev/null 2>&1 &
else
    QUICKSHELL_PATH="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null || echo quickshell)"
    export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml"
    export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"
    stdbuf -oL -eL "$QUICKSHELL_PATH" -d -n -p "$HOME/.config/quickshell/caelestia/shell.qml" >/dev/null 2>&1 &
fi

ok "Shell restarted."
