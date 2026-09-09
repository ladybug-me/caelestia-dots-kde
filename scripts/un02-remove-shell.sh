#!/usr/bin/env bash
# un02-remove-shell.sh - remove the shell's config, native plugin, QML
# modules, and the lock-screen/wallpaper Plasma packages.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

if [[ -d "$HOME/.config/quickshell/caelestia" ]]; then
    rm -rf "$HOME/.config/quickshell/caelestia"
    ok "Removed ~/.config/quickshell/caelestia"
fi

if [[ -d "$HOME/.local/lib/caelestia" ]]; then
    rm -rf "$HOME/.local/lib/caelestia"
    ok "Removed ~/.local/lib/caelestia"
fi

for qml_mod in Caelestia M3Shapes; do
    if [[ -d "$HOME/.local/lib/qt6/qml/$qml_mod" ]]; then
        rm -rf "$HOME/.local/lib/qt6/qml/$qml_mod"
        ok "Removed QML module: $qml_mod"
    fi
done

if [[ -d "$HOME/.local/share/caelestia-shell" ]]; then
    rm -rf "$HOME/.local/share/caelestia-shell"
    ok "Removed ~/.local/share/caelestia-shell"
fi

if [[ -d "$HOME/.local/share/plasma/shells/caelestia.desktop" ]]; then
    rm -rf "$HOME/.local/share/plasma/shells/caelestia.desktop"
    ok "Removed ~/.local/share/plasma/shells/caelestia.desktop"
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Wallpaper -r net.dosowisko.PlasmaApplicationWallpaper >/dev/null 2>&1 || true
fi
if [[ -d "$HOME/.local/share/plasma/wallpapers/net.dosowisko.PlasmaApplicationWallpaper" ]]; then
    rm -rf "$HOME/.local/share/plasma/wallpapers/net.dosowisko.PlasmaApplicationWallpaper"
    ok "Removed Plasma wallpaper plugin: net.dosowisko.PlasmaApplicationWallpaper"
fi
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/wallpaper-plugin-installed"
