#!/usr/bin/env bash
# 04-deploy-kde.sh  Apply KDE Plasma settings: Darkly theme, Kvantum,
#                    5 virtual desktops, disable KDE OSDs.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

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
info "Applying KDE settings"
echo ""

#  Darkly Theme
if [[ "${APPLY_DARKLY:-true}" == "true" ]]; then
    #  Darkly: Plasma style 
    info "Applying Darkly plasma style..."
    kwriteconfig6 --file plasmarc --group "Theme" --key "name" "Darkly" 2>/dev/null || true

    #  Darkly: Application style (Qt widget style) 
    info "Applying Darkly application style..."
    kwriteconfig6 --file kdeglobals --group "KDE" --key "widgetStyle" "darkly" 2>/dev/null || true
    kwriteconfig6 --file kdeglobals --group "General" --key "ColorScheme" "Darkly" 2>/dev/null || true

    #  Darkly: Window decoration 
    info "Applying Darkly window decoration..."
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
        --key "library" "org.kde.darkly" 2>/dev/null || \
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
        --key "library" "org.kde.breeze" 2>/dev/null || true
    kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" \
        --key "theme" "@darkly" 2>/dev/null || true

else
    skip "Skipping Darkly theme"
fi

# ── 3. Apply via lookandfeeltool if Darkly LNF exists (Fonts included) ────────
if [[ "${APPLY_FONTS:-true}" == "true" ]]; then
    if command -v lookandfeeltool >/dev/null 2>&1; then
        if [[ "${APPLY_DARKLY:-true}" == "true" ]]; then
            info "Applying custom fonts and LNF via lookandfeeltool..."
            lookandfeeltool --apply "Darkly" 2>/dev/null || true
        else
            skip "Skipping Darkly LNF as Darkly theme was opted out. (Fonts must be applied manually)"
        fi
    fi
else
    skip "Skipping custom fonts application."
fi

#  Cliphist Service 
info "Setting up cliphist background service..."
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
ok "Cliphist background service enabled."

ok "KDE settings applied."

#  Set Default Wallpaper 
# Prefer the dharmx "digital" pack (downloaded by 03a-wallpapers.sh) when it
# is present; otherwise keep the bundled Minimal-Paper.png fallback so a fresh
# install still has a wallpaper even with no network.
if [[ -n "${CAELESTIA_WALLPAPERS_DIR:-}" ]]; then
    WALLS_DIR="$CAELESTIA_WALLPAPERS_DIR"
elif [[ -n "${XDG_PICTURES_DIR:-}" ]]; then
    WALLS_DIR="$XDG_PICTURES_DIR/Wallpapers"
elif command -v xdg-user-dir >/dev/null 2>&1 \
        && PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null)" \
        && [[ -n "$PICTURES_DIR" ]]; then
    WALLS_DIR="$PICTURES_DIR/Wallpapers"
else
    WALLS_DIR="$HOME/Pictures/Wallpapers"
fi
PACK_DEFAULT="$WALLS_DIR/dharmx-digital/a_couple_of_people_standing_on_a_mountain.png"
FALLBACK_PATH="$BUNDLE_DIR/shell/assets/wallpapers/Minimal-Paper.png"

if [[ -f "$PACK_DEFAULT" ]]; then
    WALLPAPER_PATH="$PACK_DEFAULT"
else
    WALLPAPER_PATH="$FALLBACK_PATH"
fi
info "Setting default wallpaper to $(basename "$WALLPAPER_PATH")..."
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
    # Also save it for Caelestia, in the state dir the shell actually reads.
    STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
    mkdir -p "$STATE_DIR/wallpaper"
    echo "$WALLPAPER_PATH" > "$STATE_DIR/wallpaper/path.txt"
fi
