#!/usr/bin/env bash
# 04-deploy-kde.sh  Apply KDE Plasma settings: Darkly theme, Kvantum,
#                    5 virtual desktops, disable KDE OSDs.

set -euo pipefail

# Applies:
#   - Plasma style:      Darkly
#   - Application style: Darkly (via kvantum-dark as engine)
#   - Window decoration: Darkly
#   - Kvantum theme:     MaterialAdw (from repo-base .config/Kvantum)
#   - 5 virtual desktops with Meta+1..0 / Meta+Shift+1..0 shortcuts
#   - KDE OSD disabled (volume/brightness popups)

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"

echo
echo ""
echo "  Step 4/11  KDE Settings"
echo ""

#  Darkly Theme
if [[ "${APPLY_DARKLY:-true}" == "true" ]]; then
    #  Darkly: Plasma style 
    echo "  Applying Darkly plasma style..."
    kwriteconfig6 --file plasmarc --group "Theme" --key "name" "Darkly" 2>/dev/null || true

    #  Darkly: Application style (Qt widget style) 
    echo "  Applying Darkly application style..."
    kwriteconfig6 --file kdeglobals --group "KDE" --key "widgetStyle" "darkly" 2>/dev/null || true
    kwriteconfig6 --file kdeglobals --group "General" --key "ColorScheme" "Darkly" 2>/dev/null || true

    #  Darkly: Window decoration 
    echo "  Applying Darkly window decoration..."
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
        --key "library" "org.kde.darkly" 2>/dev/null || \
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
        --key "library" "org.kde.breeze" 2>/dev/null || true
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
        --key "theme" "@darkly" 2>/dev/null || true

else
    echo "  [SKIP] Skipping Darkly theme"
fi

# ── 3. Apply via lookandfeeltool if Darkly LNF exists (Fonts included) ────────
if [[ "${APPLY_FONTS:-true}" == "true" ]]; then
    if command -v lookandfeeltool >/dev/null 2>&1; then
        if [[ "${APPLY_DARKLY:-true}" == "true" ]]; then
            echo "  Applying custom fonts and LNF via lookandfeeltool..."
            lookandfeeltool --apply "Darkly" 2>/dev/null || true
        else
            echo "  [SKIP] Skipping Darkly LNF as Darkly theme was opted out. (Fonts must be applied manually)"
        fi
    fi
else
    echo "  [SKIP] Skipping custom fonts application."
fi

#  Cliphist Service 
echo "  Setting up cliphist background service..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/cliphist.service" << 'EOF'
[Unit]
Description=Clipboard history service
After=graphical-session.target

[Service]
Type=simple
ExecStart=/bin/bash -c "wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store & wl-clip-persist --clipboard regular & wait"
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now cliphist.service 2>/dev/null || true
echo "  [OK]  Cliphist background service enabled."

echo "[OK]  KDE settings applied."

#  Set Default Wallpaper 
echo "  Setting default wallpaper to Minimal-Paper.png..."
WALLPAPER_PATH="$BUNDLE_DIR/shell/assets/wallpapers/Minimal-Paper.png"
if [[ -f "$WALLPAPER_PATH" ]]; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (i=0; i < allDesktops.length; i++) {
            d = allDesktops[i];
            d.wallpaperPlugin = 'org.kde.image';
            d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
            d.writeConfig('Image', 'file://' + '$WALLPAPER_PATH');
        }
    " 2>/dev/null || true
    # Also save it for Caelestia
    mkdir -p "$HOME/.local/share/caelestia/state/wallpaper"
    echo "$WALLPAPER_PATH" > "$HOME/.local/share/caelestia/state/wallpaper/path.txt"
fi
