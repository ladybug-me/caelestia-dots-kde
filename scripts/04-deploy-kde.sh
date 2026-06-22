#!/usr/bin/env bash
# 04-deploy-kde.sh — Apply KDE Plasma settings: Darkly theme, Kvantum, polonium,
#                    5 virtual desktops, disable KDE OSDs.
#
# Applies:
#   - Plasma style:      Darkly
#   - Application style: Darkly (via kvantum-dark as engine)
#   - Window decoration: Darkly
#   - Kvantum theme:     MaterialAdw (from repo-base .config/Kvantum)
#   - Polonium:          disabled by default (or user-chosen at start)
#   - KWin script:       quickshell-kde-bridge enabled
#   - 5 virtual desktops with Meta+1..0 / Meta+Shift+1..0 shortcuts
#   - KDE OSD disabled (volume/brightness popups)

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
POLONIUM_ENABLED="${POLONIUM_ENABLED:-false}"

echo
echo "════════════════════════════════════════"
echo "  Step 4/11 — KDE Settings"
echo "════════════════════════════════════════"

# ── Darkly: Plasma style ─────────────────────────────────────────────────────
echo "  Applying Darkly plasma style..."
kwriteconfig6 --file plasmarc --group "Theme" --key "name" "Darkly" 2>/dev/null || true

# ── Darkly: Application style (Qt widget style) ───────────────────────────────
echo "  Applying Darkly application style..."
kwriteconfig6 --file kdeglobals --group "KDE" --key "widgetStyle" "darkly" 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group "General" --key "ColorScheme" "Darkly" 2>/dev/null || true

# ── Darkly: Window decoration ─────────────────────────────────────────────────
echo "  Applying Darkly window decoration..."
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
    --key "library" "org.kde.darkly" 2>/dev/null || \
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
    --key "library" "org.kde.breeze" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
    --key "theme" "@darkly" 2>/dev/null || true

# ── Bibata: Cursor theme ──────────────────────────────────────────────────────
echo "  Applying Bibata cursor theme..."
kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "Bibata-Modern-Ice" 2>/dev/null || true

# ── Polonium: tiling window manager ──────────────────────────────────────────
echo "  Configuring Polonium (tiling) — enabled=$POLONIUM_ENABLED ..."
kwriteconfig6 --file kwinrc --group "Plugins" \
    --key "poloniumEnabled" "$POLONIUM_ENABLED" 2>/dev/null || true


# ── KWin bridge script ────────────────────────────────────────────────────────
echo "  Enabling quickshell-kde-bridge KWin script..."
kwriteconfig6 --file kwinrc --group "Plugins" \
    --key "quickshell-kde-bridgeEnabled" "true" 2>/dev/null || true

# ── 5 Virtual Desktops ───────────────────────────────────────────────────────
echo "  Setting up 5 virtual desktops..."
kwriteconfig6 --file kwinrc --group "Desktops" --key "Number" "5"
kwriteconfig6 --file kwinrc --group "Desktops" --key "Rows" "1"
for i in $(seq 1 5); do
    kwriteconfig6 --file kwinrc --group "Desktops" --key "Name_$i" "Desktop $i"
done
echo "  [OK]  5 virtual desktops configured."

#Switching desktops are handled by keyd src/keyboardshortcuts/shortcuts.md

# ── Disable KDE OSDs (volume, brightness popups) ─────────────────────────────
echo "  Disabling KDE OSD popups..."
# Plasma volume OSD
kwriteconfig6 --file plasmarc --group "OSD" --key "Enabled" "false" 2>/dev/null || true
# kde-plasma-volume / kded audio volume OSD
kwriteconfig6 --file kdeglobals --group "KDE" --key "OSDEnabled" "false" 2>/dev/null || true
# plasma-volume OSD
kwriteconfig6 --file plasmanotifyrc --group "Notifications" \
    --key "LoudnessChangedOSD" "false" 2>/dev/null || true
# Brightness OSD via powerdevil
kwriteconfig6 --file powerdevilrc --group "BrightnessControl" \
    --key "showOSD" "false" 2>/dev/null || true
kwriteconfig6 --file powerdevilrc --group "AC" \
    --key "brightnessosd" "false" 2>/dev/null || true
# Plasma workspace OSD (Plasma 6 unified OSD daemon)
kwriteconfig6 --file plasmarc --group "OSD" --key "ShowOnActiveScreen" "false" 2>/dev/null || true
# Disable the plasma-volume kded module OSD flag
mkdir -p "$HOME/.config"
cat > "$HOME/.config/kmixrc" <<'EOF' 2>/dev/null || true
[Global]
ShowOSD=false
EOF
echo "  [OK]  KDE OSDs disabled."

# ── Apply via lookandfeeltool if Darkly LNF exists ───────────────────────────
if command -v lookandfeeltool >/dev/null 2>&1; then
    lookandfeeltool --apply "Darkly" 2>/dev/null || true
fi

# ── Cliphist Service ──────────────────────────────────────────────────────────
echo "  Setting up cliphist background service..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/cliphist.service" << 'EOF'
[Unit]
Description=Clipboard history service
After=graphical-session.target

[Service]
Type=simple
ExecStart=/bin/bash -c "wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store & wait"
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now cliphist.service 2>/dev/null || true
echo "  [OK]  Cliphist background service enabled."

echo "[OK]  KDE settings applied."
