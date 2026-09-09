#!/usr/bin/env bash
# un09-cleanup-build-dirs.sh - remove regenerable CMake build directories.
#
# The installer's own cache dir (which still holds the shared install log
# this very run is being tailed from) is NOT touched here - it's cleaned up
# separately, after the whole TUI program exits, via main.go's existing
# REMOVE_CACHE handling (same flag the Install flow already uses).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"

for build_dir in "$BUNDLE_DIR/shell/build" "$BUNDLE_DIR/shell/plugin/build"; do
    if [[ -d "$build_dir" ]]; then
        rm -rf "$build_dir"
        ok "Removed build dir: $build_dir"
    else
        skip "No build dir at $build_dir"
    fi
done
