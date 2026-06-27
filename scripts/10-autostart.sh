#!/usr/bin/env bash
# 06-autostart.sh — Set up autostart entries for Quickshell and kde-material-you-colors.
# Idempotent: overwrites .desktop files with correct content each run.

AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

echo
echo "════════════════════════════════════════"
echo "  Step 10/11 — Autostart Setup"
echo "════════════════════════════════════════"

# ── Caelestia Shell autostart ──────────────────────────────────────────────────────
# Uses `caelestia shell -d`: starts Caelestia shell as a daemon
# detaches it from the autostart process so KDE doesn't wait for it.
echo "  Creating Caelestia Shell autostart entry..."
cat > "$AUTOSTART_DIR/caelestiashell.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Caelestia Shell
Comment=Start Caelestia Shell
Exec=bash -c 'sleep 2 && caelestia shell -d &'
Icon=quickshell
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-AutostartPhase=2
EOF
echo "  [OK]  Quickshell autostart created."

# ── kde-material-you-colors systemd service ──────────────────────────────────
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
    echo "  [OK]  kde-material-you-colors systemd service enabled."
else
    echo "  [SKIP] Skipping kde-material-you-colors systemd service."
fi

echo "[OK]  Autostart entries configured."
