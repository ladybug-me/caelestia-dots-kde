#!/usr/bin/env bash
# 02-packages.sh - Install plasma-wallpaper-application and ensure Python tooling
# (Package groups are installed by the individual 02-*-packages.sh scripts)

set -euo pipefail

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"

echo
echo ""
echo "  Installing wallpaper plugin & Python tooling"
echo ""

echo "--- Installing plasma-wallpaper-application ---"
if [[ "${APPLY_LOCKSCREEN:-true}" != "false" ]]; then
    if [[ -d "$BUNDLE_DIR/src/plasma-wallpaper-application/package" ]]; then
        kpackagetool6 -t Plasma/Wallpaper -i "$BUNDLE_DIR/src/plasma-wallpaper-application/package" >/dev/null 2>&1 || kpackagetool6 -t Plasma/Wallpaper -u "$BUNDLE_DIR/src/plasma-wallpaper-application/package" || echo "[WARN] plasma-wallpaper-application installation failed"
    else
        echo "[WARN] plasma-wallpaper-application not found, Skipping installation"
    fi
else
    echo "[WARN] Lockscreen wallpaper not enabled, Skipping installation"
fi

echo

echo "--- Ensuring Python tooling for konsave backups ---"
if ! command -v python3 >/dev/null 2>&1 || ! python3 -m pip --version >/dev/null 2>&1; then
    if [[ "$BASE_DISTRO" == "arch" ]]; then
        sudo pacman -S --needed --noconfirm python python-pip
    elif [[ "$BASE_DISTRO" == "fedora" ]]; then
        sudo dnf install -y python3 python3-pip
    fi
fi

echo
echo "[OK]  Package installation complete."
