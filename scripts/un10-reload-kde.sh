#!/usr/bin/env bash
# un10-reload-kde.sh - reconfigure KWin/Plasma and reapply the previous
# look-and-feel (or Breeze) now that all Caelestia files are gone.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

CACHE_DIR="${CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde}"
PREVIOUS_LOOKANDFEEL=""
THEME_RESTORED_FROM_BACKUP="false"
if [[ -f "$CACHE_DIR/uninstall-theme-state.env" ]]; then
    # shellcheck disable=SC1090
    . "$CACHE_DIR/uninstall-theme-state.env"
fi

qdbus6 org.kde.KWin /KWin reconfigure               2>/dev/null || true
systemctl --user restart plasma-kglobalaccel.service 2>/dev/null || true
kbuildsycoca6 --noincremental                        2>/dev/null || true

if command -v lookandfeeltool >/dev/null 2>&1; then
    if [[ -n "$PREVIOUS_LOOKANDFEEL" ]]; then
        info "Reapplying previous KDE look-and-feel: $PREVIOUS_LOOKANDFEEL"
        lookandfeeltool --apply "$PREVIOUS_LOOKANDFEEL" 2>/dev/null || \
            warn "Could not apply $PREVIOUS_LOOKANDFEEL with lookandfeeltool."
    elif [[ "$THEME_RESTORED_FROM_BACKUP" == "true" ]]; then
        info "Skipping Breeze look-and-feel apply because theme was restored from backup."
    else
        lookandfeeltool --apply "org.kde.breeze.desktop" 2>/dev/null || true
    fi
fi

rm -f "$CACHE_DIR/uninstall-theme-state.env"
ok "KDE reloaded"
