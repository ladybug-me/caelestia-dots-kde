#!/usr/bin/env bash
# 02-packages.sh - Ensure the runtime tooling the shell needs: Python for
# konsave backups and the helpers, and matugen for the color palette.
# (Package groups are installed by the individual 02-*-packages.sh scripts)

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/privileges.sh"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"

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
info "Ensuring the palette generator"
# matugen is what turns a wallpaper into a palette, and only Arch packages it.
# Report its absence here, where the fix is a package command, rather than let
# the first wallpaper change fail with nothing to say about why.
if command -v matugen >/dev/null 2>&1; then
    ok "matugen is installed."
else
    warn "matugen is not installed: wallpapers and schemes cannot generate a palette."
    info "  Arch:   sudo pacman -S matugen"
    info "  Fedora: cargo install matugen"
    info "  Debian: cargo install matugen (the installer builds it for you)"
fi

echo
ok "Package installation complete."
