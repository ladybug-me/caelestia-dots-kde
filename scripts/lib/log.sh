#!/usr/bin/env bash
# ==============================================================
#   Caelestia installer log helpers
#
#   Canonical status format shared by every step script. Source
#   from any step script:
#       source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
#
#   Markers: [INFO], [OK], [WARN], [SKIP], [ERR].
#   The installer TUI scans step output for [WARN] markers to show
#   the WARN status, so keep the spelling and spacing exact.
# ==============================================================

if [[ -n "${CAELESTIA_LOG_LOADED:-}" ]]; then
    return 0
fi
CAELESTIA_LOG_LOADED=1

# Plain output only. Step output lands in install.log (a file), where
# ANSI colors would just be noise, and the TUI strips escapes anyway.
info() { printf '  [INFO]  %s\n' "$*"; }
ok()   { printf '  [OK]    %s\n' "$*"; }
warn() { printf '  [WARN]  %s\n' "$*"; }
skip() { printf '  [SKIP]  %s\n' "$*"; }
err()  { printf '  [ERR]   %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }
