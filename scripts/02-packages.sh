#!/usr/bin/env bash
# 02-packages.sh - Install plasma-wallpaper-application and ensure Python tooling
# (Package groups are installed by the individual 02-*-packages.sh scripts)

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/privileges.sh"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"

echo
echo ""
info "Installing wallpaper plugin & Python tooling"
echo ""

info "Installing plasma-wallpaper-application (v1.2)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
WALLPAPER_STAMP="$CACHE_DIR/wallpaper-plugin-installed"
export CAELESTIA_WALLPAPER_PLUGIN_INSTALLED=false

if [[ "${APPLY_LOCKSCREEN:-true}" != "false" ]]; then
    if [[ -d "$BUNDLE_DIR/src/plasma-wallpaper-application/package" ]]; then
        if kpackagetool6 -t Plasma/Wallpaper -i "$BUNDLE_DIR/src/plasma-wallpaper-application/package" >/dev/null 2>&1; then
            mkdir -p "$CACHE_DIR"
            echo "v1.2" > "$WALLPAPER_STAMP"
            CAELESTIA_WALLPAPER_PLUGIN_INSTALLED=true
            ok "plasma-wallpaper-application v1.2 installed."
        elif kpackagetool6 -t Plasma/Wallpaper -u "$BUNDLE_DIR/src/plasma-wallpaper-application/package" >/dev/null 2>&1; then
            mkdir -p "$CACHE_DIR"
            echo "v1.2" > "$WALLPAPER_STAMP"
            CAELESTIA_WALLPAPER_PLUGIN_INSTALLED=true
            ok "plasma-wallpaper-application v1.2 updated."
        else
            warn "plasma-wallpaper-application installation failed"
        fi
    else
        warn "plasma-wallpaper-application not found. Skipping installation."
    fi
else
    skip "Lockscreen wallpaper not enabled by user choice."
fi

echo

info "Ensuring Python tooling for konsave backups"
if ! command -v python3 >/dev/null 2>&1 || ! python3 -m pip --version >/dev/null 2>&1; then
    package_distro="${BASE_DISTRO:-}"
    if [[ -z "$package_distro" ]]; then
        if command -v pacman >/dev/null 2>&1; then
            package_distro="arch"
        elif command -v dnf >/dev/null 2>&1; then
            package_distro="fedora"
        elif command -v apt-get >/dev/null 2>&1; then
            package_distro="debian"
        fi
    fi

    if [[ "$package_distro" == "arch" ]]; then
        caelestia_sudo pacman -S --needed --noconfirm python python-pip
    elif [[ "$package_distro" == "fedora" ]]; then
        caelestia_sudo dnf install -y python3 python3-pip
    elif [[ "$package_distro" == "debian" ]]; then
        caelestia_sudo apt-get update && caelestia_sudo apt-get install -y python3 python3-pip python3-venv
    else
        warn "Could not determine the distro for Python tooling installation."
    fi
fi

echo
ok "Package installation complete."
