#!/usr/bin/env bash
# 04-deploy-kde.sh - Apply KDE Plasma settings, theme choices, desktop layout,
# and session defaults.

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BUNDLE_DIR/scripts/00-ui.sh"

POLONIUM_ENABLED="${POLONIUM_ENABLED:-false}"

ui_section "Step 4/11 - KDE Settings"

apply_setting() {
    local description="$1"
    shift
    ui_info "$description"
    "$@" 2>/dev/null || true
}

set_config() {
    kwriteconfig6 "$@" 2>/dev/null || true
}

if [[ "${APPLY_DARKLY:-true}" == "true" ]]; then
    apply_setting "Applying Darkly plasma style..." set_config --file plasmarc --group "Theme" --key "name" "Darkly"
    apply_setting "Applying Darkly application style..." set_config --file kdeglobals --group "KDE" --key "widgetStyle" "darkly"
    set_config --file kdeglobals --group "General" --key "ColorScheme" "Darkly"
    apply_setting "Applying Darkly window decoration..." set_config --file kwinrc --group "org.kde.kdecoration2" --key "library" "org.kde.darkly"
    set_config --file kwinrc --group "org.kde.kdecoration2" --key "library" "org.kde.breeze"
    set_config --file kwinrc --group "org.kde.kdecoration2" --key "theme" "@darkly"
    apply_setting "Applying Bibata cursor theme..." set_config --file kcminputrc --group Mouse --key cursorTheme "Bibata-Modern-Ice"
else
    ui_skip "Skipping Darkly theme and Bibata cursor application."
fi

ui_info "Configuring Polonium (tiling), enabled=$POLONIUM_ENABLED..."
set_config --file kwinrc --group "Plugins" --key "poloniumEnabled" "$POLONIUM_ENABLED"

ui_info "Enabling quickshell-kde-bridge KWin script..."
set_config --file kwinrc --group "Plugins" --key "quickshell-kde-bridgeEnabled" "true"

ui_info "Setting up 5 virtual desktops..."
set_config --file kwinrc --group "Desktops" --key "Number" "5"
set_config --file kwinrc --group "Desktops" --key "Rows" "1"
for i in $(seq 1 5); do
    set_config --file kwinrc --group "Desktops" --key "Name_$i" "Desktop $i"
done
ui_ok "5 virtual desktops configured."

ui_info "Disabling KDE OSD popups..."
set_config --file plasmarc --group "OSD" --key "Enabled" "false"
set_config --file kdeglobals --group "KDE" --key "OSDEnabled" "false"
set_config --file plasmanotifyrc --group "Notifications" --key "LoudnessChangedOSD" "false"
set_config --file powerdevilrc --group "BrightnessControl" --key "showOSD" "false"
set_config --file powerdevilrc --group "AC" --key "brightnessosd" "false"
set_config --file plasmarc --group "OSD" --key "ShowOnActiveScreen" "false"

mkdir -p "$HOME/.config"
cat > "$HOME/.config/kmixrc" <<'EOF' 2>/dev/null || true
[Global]
ShowOSD=false
EOF
ui_ok "KDE OSDs disabled."

if [[ "${APPLY_FONTS:-true}" == "true" ]]; then
    if command -v lookandfeeltool >/dev/null 2>&1; then
        if [[ "${APPLY_DARKLY:-true}" == "true" ]]; then
            ui_info "Applying custom fonts and look and feel via lookandfeeltool..."
            lookandfeeltool --apply "Darkly" 2>/dev/null || true
        else
            ui_skip "Skipping Darkly look and feel because the theme was opted out. Fonts must be applied manually."
        fi
    fi
else
    ui_skip "Skipping custom fonts application."
fi

ui_info "Setting up cliphist background service..."
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
ui_ok "Cliphist background service enabled."

ui_ok "KDE settings applied."

ui_info "Setting default wallpaper to Minimal-Paper.png..."
WALLPAPER_PATH="$BUNDLE_DIR/shell/assets/wallpapers/Minimal-Paper.png"
if [[ -f "$WALLPAPER_PATH" ]]; then
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
        var allDesktops = desktops();
        for (i = 0; i < allDesktops.length; i++) {
            d = allDesktops[i];
            d.wallpaperPlugin = 'org.kde.image';
            d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
            d.writeConfig('Image', 'file://' + '$WALLPAPER_PATH');
        }
    " 2>/dev/null || true
    mkdir -p "$HOME/.local/share/caelestia/state/wallpaper"
    echo "$WALLPAPER_PATH" > "$HOME/.local/share/caelestia/state/wallpaper/path.txt"
fi
