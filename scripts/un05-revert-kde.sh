#!/usr/bin/env bash
# un05-revert-kde.sh - re-enable KDE OSDs and restore (or reset) the desktop
# theme/lock screen/wallpaper from the selected backup (SELECTED_BACKUP).
#
# Writes PREVIOUS_LOOKANDFEEL/THEME_RESTORED_FROM_BACKUP to a small state
# file under CACHE_DIR for un10-reload-kde.sh to pick up - each step script
# is its own process, so this can't just be a shell variable.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

SELECTED_BACKUP="${SELECTED_BACKUP:-}"
SELECTED_KNSV=""
PREVIOUS_LOOKANDFEEL=""
THEME_RESTORED_FROM_BACKUP="false"

if [[ -n "$SELECTED_BACKUP" ]]; then
    SELECTED_KNSV="$(find "$SELECTED_BACKUP" -maxdepth 1 -type f -name '*.knsv' | head -n 1)"
    if [[ -f "$SELECTED_BACKUP/previous_lookandfeel.txt" ]]; then
        PREVIOUS_LOOKANDFEEL="$(cat "$SELECTED_BACKUP/previous_lookandfeel.txt")"
    fi
fi

kwriteconfig6 --file plasmarc         --group "OSD"              --key "Enabled"            "true"  2>/dev/null || true
kwriteconfig6 --file plasmarc         --group "OSD"              --key "ShowOnActiveScreen"  "true"  2>/dev/null || true
kwriteconfig6 --file kdeglobals       --group "KDE"              --key "OSDEnabled"          "true"  2>/dev/null || true
kwriteconfig6 --file plasmanotifyrc   --group "Notifications"    --key "LoudnessChangedOSD" "true"  2>/dev/null || true
kwriteconfig6 --file powerdevilrc     --group "BrightnessControl"--key "showOSD"            "true"  2>/dev/null || true
kwriteconfig6 --file powerdevilrc     --group "AC"               --key "brightnessosd"       "true"  2>/dev/null || true
ok "Re-enabled KDE OSD notifications"

ensure_konsave() {
    if command -v konsave >/dev/null 2>&1; then
        KONSAVE_BIN="$(command -v konsave)"
        return 0
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        return 1
    fi
    info "Installing konsave for KDE profile restore..."
    KONSAVE_VENV_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/konsave-venv"
    if [[ ! -x "$KONSAVE_VENV_DIR/bin/konsave" ]]; then
        python3 -m venv "$KONSAVE_VENV_DIR" >/dev/null 2>&1 || return 1
        "$KONSAVE_VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || true
        "$KONSAVE_VENV_DIR/bin/python" -m pip install --upgrade konsave >/dev/null 2>&1 || return 1
    fi
    KONSAVE_BIN="$KONSAVE_VENV_DIR/bin/konsave"
    [[ -x "$KONSAVE_BIN" ]]
}

if [[ -n "$SELECTED_KNSV" ]]; then
    if ensure_konsave; then
        info "Restoring KDE settings from konsave archive..."
        if "$KONSAVE_BIN" -i "$SELECTED_KNSV" >/dev/null 2>&1 && \
           "$KONSAVE_BIN" -a caelestia-preinstall >/dev/null 2>&1; then
            THEME_RESTORED_FROM_BACKUP="true"
            ok "Restored KDE settings from konsave backup."
        else
            warn "konsave restore failed, falling back to manual restore paths."
            SELECTED_KNSV=""
        fi
    else
        warn "konsave is unavailable, falling back to manual restore paths."
        SELECTED_KNSV=""
    fi
fi

if [[ -z "$SELECTED_KNSV" ]]; then
    MANUAL_KDE_RESTORE_COUNT=0
    if [[ -n "$SELECTED_BACKUP" ]]; then
        info "Restoring core KDE configuration files from backup..."
        for kde_cfg in kdeglobals ksplashrc plasmarc kwinrc kcminputrc plasma-org.kde.plasma.desktop-appletsrc; do
            if [[ -f "$SELECTED_BACKUP/.config/$kde_cfg" ]]; then
                if cp "$SELECTED_BACKUP/.config/$kde_cfg" "$HOME/.config/$kde_cfg"; then
                    ((MANUAL_KDE_RESTORE_COUNT++))
                fi
            fi
        done
        if (( MANUAL_KDE_RESTORE_COUNT > 0 )); then
            THEME_RESTORED_FROM_BACKUP="true"
            ok "Restored $MANUAL_KDE_RESTORE_COUNT core KDE configuration file(s) from backup (including wallpaper and splash when present)."
        else
            warn "Selected backup did not contain expected core KDE config files. Falling back to Breeze defaults."
        fi
    fi

    if [[ "$THEME_RESTORED_FROM_BACKUP" != "true" ]]; then
        info "No theme backup found. Reverting to default Breeze theme..."
        kwriteconfig6 --file plasmarc --group "Theme" --key "name" "default"  2>/dev/null || true
        kwriteconfig6 --file kdeglobals --group "KDE"     --key "widgetStyle"  "Breeze" 2>/dev/null || true
        kwriteconfig6 --file kdeglobals --group "General" --key "ColorScheme"  "BreezeLight" 2>/dev/null || true
        kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "library" "org.kde.breeze" 2>/dev/null || true
        kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "theme"   "@breeze"        2>/dev/null || true
        kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "breeze_cursors" 2>/dev/null || true
        ok "Reset KDE theme settings to Breeze."
    fi
fi

kwriteconfig6 --file kwinrc --group "Plugins" --key "quickshell-kde-bridgeEnabled" "false" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "Plugins" --key "krohnkiteEnabled"             "false" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "Plugins" --key "kwin_workspace_trackerEnabled" "false" 2>/dev/null || true
ok "Disabled KWin plugins: quickshell-kde-bridge, krohnkite, kwin_workspace_tracker"

kwriteconfig6 --file plasmashellrc --group "Shell" --key "ShellPackage" --delete 2>/dev/null || true
kwriteconfig6 --file kscreenlockerrc --group "Greeter" --key "Theme" "org.kde.breeze.desktop" 2>/dev/null || true
kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin "org.kde.image" 2>/dev/null || true
kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key command --delete 2>/dev/null || true
kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key fps --delete 2>/dev/null || true
kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key alwaysShowClock --delete 2>/dev/null || true
kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key showMediaControls --delete 2>/dev/null || true
ok "Restored stock KDE lock screen configuration."

kwriteconfig6 --file kwinrc --group "Desktops" --key "Number" "1" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "Desktops" --key "Rows"   "1" 2>/dev/null || true
for i in $(seq 1 5); do
    kwriteconfig6 --file kwinrc --group "Desktops" --key "Name_$i" "Desktop $i" 2>/dev/null || true
done
ok "Restored desktop count to 1"

for i in $(seq 1 5); do
    kwriteconfig6 --file kglobalshortcutsrc --group "kwin" \
        --key "Switch to Desktop $i"  "none,none,Switch to Desktop $i"          2>/dev/null || true
    kwriteconfig6 --file kglobalshortcutsrc --group "kwin" \
        --key "Window to Desktop $i"  "none,none,Move Window to Desktop $i"     2>/dev/null || true
done
ok "Cleared installer workspace shortcuts from kglobalshortcutsrc"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
if [[ -n "$SELECTED_BACKUP" ]] && [[ -f "$SELECTED_BACKUP/.config/kglobalshortcutsrc" ]]; then
    cp "$SELECTED_BACKUP/.config/kglobalshortcutsrc" "$HOME/.config/kglobalshortcutsrc"
    ok "Restored kglobalshortcutsrc from backup"
elif ls "$BUNDLE_DIR/backups/kglobalshortcutsrc_"* >/dev/null 2>&1; then
    _bk_file="$(ls -t "$BUNDLE_DIR/backups/kglobalshortcutsrc_"* 2>/dev/null | head -1)"
    if [[ -f "$_bk_file" ]]; then
        cp "$_bk_file" "$HOME/.config/kglobalshortcutsrc"
        ok "Restored kglobalshortcutsrc from $(basename "$_bk_file")"
    fi
fi

rm -f "$HOME/.local/share/konsole/MaterialYou.colorscheme"
rm -f "$HOME/.local/share/konsole/MaterialYouAlt.colorscheme"
rm -f "$HOME/.local/share/konsole/TempMyou.profile"
rm -f "$HOME/.local/share/color-schemes/MaterialYou"*.colors
ok "Removed Konsole profiles generated by Caelestia"

_DARKLY_GTK_THEME="${XDG_DATA_HOME:-$HOME/.local/share}/themes/Darkly"
_GTK4_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"
if [[ -d "$_DARKLY_GTK_THEME" ]]; then
    rm -rf "$_DARKLY_GTK_THEME"
    ok "Removed Darkly GTK theme"
fi
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/desktoptheme/Darkly" 2>/dev/null || true
rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/plasma/desktoptheme/darkly" 2>/dev/null || true
if [[ -f "$_GTK4_DIR/gtk.css.created_by_darkly_installer.bak" ]]; then
    mv -f "$_GTK4_DIR/gtk.css.created_by_darkly_installer.bak" "$_GTK4_DIR/gtk.css"
fi
if [[ -f "$_GTK4_DIR/gtk-darkly.css" || -d "$_GTK4_DIR/darkly-gtk-assets" ]]; then
    rm -f "$_GTK4_DIR/gtk-darkly.css"
    rm -rf "$_GTK4_DIR/darkly-gtk-assets"
    ok "Removed Darkly GTK libadwaita files"
fi

if [[ -n "$SELECTED_BACKUP" ]]; then
    if [[ -f "$SELECTED_BACKUP/.config/konsolerc" ]]; then
        cp "$SELECTED_BACKUP/.config/konsolerc" "$HOME/.config/konsolerc"
        ok "Restored konsolerc from backup"
    fi
    if [[ -d "$SELECTED_BACKUP/local/konsole" ]]; then
        rm -rf "$HOME/.local/share/konsole"
        cp -r  "$SELECTED_BACKUP/local/konsole" "$HOME/.local/share/konsole"
        ok "Restored ~/.local/share/konsole from backup"
    fi
fi

STATE_DIR="${CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde}"
mkdir -p "$STATE_DIR"
{
    echo "PREVIOUS_LOOKANDFEEL=$PREVIOUS_LOOKANDFEEL"
    echo "THEME_RESTORED_FROM_BACKUP=$THEME_RESTORED_FROM_BACKUP"
} > "$STATE_DIR/uninstall-theme-state.env"
