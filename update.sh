#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
# ==============================================================
#   Caelestia KDE Port - Update shim
#
#   The update logic now lives in the installer TUI's manifest-driven
#   flow (installer/update-steps.json), shared with the interactive
#   "Update Caelestia" screen. This script is a thin wrapper so cron
#   jobs and direct `./update.sh [branch]` calls keep working without
#   a terminal. `branch` (main|dev) is optional; omit it to update
#   whatever branch is already checked out.
# ==============================================================

set -uo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$BUNDLE_DIR/installer/caelestia-install"

if [[ ! -x "$BIN" ]]; then
    echo "[ERR]   Installer binary missing: $BIN" >&2
    echo "        Run install.sh first to build it." >&2
    exit 1
fi

# Prevent concurrent update runs from racing on git/CMake/config writes.
# fd 9 stays open across exec, so the lock is held until the binary exits.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/caelestia-update.lock"
flock -n 9 || { echo "Another Caelestia update is already running." >&2; exit 1; }

exec "$BIN" --update "$@"

