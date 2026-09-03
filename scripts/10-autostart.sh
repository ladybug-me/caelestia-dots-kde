#!/usr/bin/env bash
# 10-autostart.sh  Set up autostart entries for Quickshell and kde-material-you-colors.
# Idempotent: overwrites .desktop files with correct content each run.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

# Resolve the bundle root the same way the build script does, so this works
# whether the installer exports it or the script is run directly.
BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
mkdir -p "$HOME/.local/bin"

echo
echo ""
info "Setting up autostart entries"
echo ""

SHELL_CONFIG="$HOME/.config/quickshell/caelestia/shell.qml"

if [[ ! -f "$SHELL_CONFIG" ]]; then
    die "Caelestia Shell entrypoint not found: $SHELL_CONFIG (run scripts/08-build-shell.sh first)"
fi

# Determine the path of quickshell to avoid PATH differences at login.
if command -v quickshell >/dev/null 2>&1; then
    QUICKSHELL_PATH="$(command -v quickshell)"
elif command -v qs >/dev/null 2>&1; then
    QUICKSHELL_PATH="$(command -v qs)"
elif [ -x "/usr/bin/quickshell" ]; then
    QUICKSHELL_PATH="/usr/bin/quickshell"
elif [ -x "/usr/local/bin/quickshell" ]; then
    QUICKSHELL_PATH="/usr/local/bin/quickshell"
else
    die "Quickshell is not installed or is not available in PATH."
fi

# Caelestia Shell autostart
# Launch the shell built by 08-build-shell.sh directly. This avoids depending
# on the distro's caelestia-cli version or its config-directory resolution.
echo "  Creating Caelestia Shell autostart entry..."
cat > "$HOME/.local/bin/caelestia-autostart.sh" << EOF
#!/bin/bash
export QML2_IMPORT_PATH="\$HOME/.local/lib/qt6/qml:\$HOME/.config/quickshell/caelestia"
export CAELESTIA_LIB_DIR="\$HOME/.local/lib/caelestia"
export QS_NO_RELOAD_POPUP=1
export QS_DROP_EXPENSIVE_FONTS=1
export QS_DISABLE_CRASH_HANDLER=1
export QSG_RENDER_LOOP=threaded
export QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
# No --daemonize: the autostart entry already runs under a systemd user unit,
# which supervises the process and connects its stdout/stderr to the journal.
# Detaching would replace that with /dev/null, and every application launched
# from the shell inherits those descriptors - which is how the shell was
# handing apps a stdout that goes nowhere. Vesktop deadlocks in exactly that
# state when a call starts (issue #402); reproducible outside the shell with
# `vesktop >/dev/null 2>&1`.
#
# Dropping it also makes the old stdbuf wrapper unnecessary: journald stdio is
# what the line-buffering hack was working around, and stdbuf leaked
# LD_PRELOAD=libstdbuf.so into every launched app on top of that.
exec "$QUICKSHELL_PATH" -n -p "\$HOME/.config/quickshell/caelestia/shell.qml"
EOF
chmod +x "$HOME/.local/bin/caelestia-autostart.sh"

# Phase 1 (DesktopServices), not 2 (Applications). The shell registers
# org.freedesktop.Notifications, and applications decide once, when they start,
# whether a notification server exists -- one that finds none draws its own
# popups for the rest of the session, in its own corner, ignoring every setting
# here. In phase 2 the shell starts alongside the user's autostarted apps with
# no ordering between them, so which apps end up talking to it is a coin toss
# per login. Phase 1 finishes before any of them begin.
cat > "$AUTOSTART_DIR/caelestiashell.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Caelestia Shell
Comment=Start Caelestia Shell
Exec=$HOME/.local/bin/caelestia-autostart.sh
Icon=quickshell
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-AutostartPhase=1
X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1
EOF
ok "Quickshell autostart created."

# KWin restricts privileged Wayland protocols (like zkde_screencast_unstable_v1,
# used for live window thumbnails). For every such protocol, KWin's
# allowInterface() calls KWin::fetchRequestedInterfaces(client->executablePath()),
# which uses KApplicationTrader::query() to find an installed .desktop file whose
# Exec= *first token*, resolved via QFileInfo::canonicalFilePath(), matches the
# client's executable path *exactly* (no $PATH lookup, no symlink allowances
# beyond what canonicalFilePath() resolves, and no wrapper scripts). A desktop
# file with no Exec= line at all never matches anything (QProcess::splitCommand
# returns an empty list, so the predicate always rejects it). Create a
# user-level override at the standard XDG path, with Exec= pointing at the
# fully-resolved quickshell binary, so KWin can find it and grant the protocol.
echo "  Creating quickshell KDE Wayland interface declaration..."
mkdir -p "$HOME/.local/share/applications"
QUICKSHELL_CANONICAL_PATH="$(realpath "$QUICKSHELL_PATH")"
cat > "$HOME/.local/share/applications/quickshell.desktop" << DESKEOF
[Desktop Entry]
Type=Application
Name=Quickshell
NoDisplay=true
Exec=$QUICKSHELL_CANONICAL_PATH
X-KDE-Wayland-Interfaces=zkde_screencast_unstable_v1,org_kde_plasma_window_management
DESKEOF
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
# KApplicationTrader/KService resolve through the ksycoca cache, not just the
# desktop-file-database used above; force a rebuild so the new Exec= is seen.
if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 --noincremental >/dev/null 2>&1 || true
fi
ok "Quickshell Wayland interface declaration created."

#  kde-material-you-colors systemd service 
# Creates and enables a systemd user service for kde-material-you-colors.
echo "  Deploying systemd service for KDE Material You Colors..."

if [[ "${APPLY_MATERIAL_YOU:-true}" == "true" ]]; then
    # Clean up old desktop autostart entry if it exists
    rm -f "$AUTOSTART_DIR/kde-material-you-colors.desktop" 2>/dev/null || true

    # Clean up old Material You color schemes to prevent them from multiplying
    rm -f "$HOME/.local/share/color-schemes/MaterialYou"*.colors 2>/dev/null || true

    mkdir -p "$HOME/.config/systemd/user"
    # Determine the path of kde-material-you-colors
    if command -v kde-material-you-colors >/dev/null 2>&1; then
        KMYC_PATH=$(command -v kde-material-you-colors)
    elif [ -f "$HOME/.local/bin/kde-material-you-colors" ]; then
        KMYC_PATH="$HOME/.local/bin/kde-material-you-colors"
    elif [ -f "/usr/bin/kde-material-you-colors" ]; then
        KMYC_PATH="/usr/bin/kde-material-you-colors"
    else
        KMYC_PATH="$HOME/.local/bin/kde-material-you-colors"
    fi

    cat > "$HOME/.config/systemd/user/kde-material-you-colors.service" << EOF
[Unit]
Description=KDE Material You Colors
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=$KMYC_PATH
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now kde-material-you-colors.service 2>/dev/null || true
    ok "kde-material-you-colors systemd service enabled."
else
    skip "Skipping kde-material-you-colors systemd service."
fi

# Live window thumbnails.
#
# KWin only advertises its privileged Wayland interfaces to clients whose
# desktop file requests them: it resolves the client's /proc/<pid>/exe, then
# looks for an installed .desktop whose Exec resolves to that same binary and
# reads X-KDE-Wayland-Interfaces from it. Quickshell's packaged entry has no
# Exec line at all, so the shell matches nothing and zkde_screencast_unstable_v1
# is never offered — the dock hover popup and window switcher then fall back to
# drawing the app icon instead of a live preview.
#
# Note this cannot live on the autostart entry above: KWin matches on the
# resolved executable, and that entry's Exec is the wrapper script rather than
# the quickshell binary, so it never matches.
if [[ -f "$BUNDLE_DIR/assets/org.quickshell.desktop" ]]; then
    echo "  Requesting KWin screencast interface for window previews..."
    mkdir -p "$HOME/.local/share/applications"
    sed "s|^Exec=.*|Exec=$QUICKSHELL_CANONICAL_PATH|" \
        "$BUNDLE_DIR/assets/org.quickshell.desktop" \
        > "$HOME/.local/share/applications/org.quickshell.desktop" 2>/dev/null || true
    # KWin reads this through KService, which needs its cache rebuilt.
    kbuildsycoca6 >/dev/null 2>&1 || true
    echo "  [OK]  Window preview interface requested."
fi

ok "Autostart entries configured."
