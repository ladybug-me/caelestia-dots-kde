#!/usr/bin/env bash
# 08-kde-apps.sh — Install KDE-specific applications:
#   - kvantum + kvantum-qt5 (Qt style engine for Material You look)
#   - kde-material-you-colors (AUR widget/daemon for wallpaper-adaptive colors)
#
# Idempotent: checks before installing.

echo
echo "════════════════════════════════════════"
echo "  Step 7/11 — KDE Theme Apps"
echo "════════════════════════════════════════"

install_if_missing() {
    local pkg="$1"
    if [[ "$BASE_DISTRO" == "arch" ]]; then
        if pacman -Qi "$pkg" >/dev/null 2>&1; then
            echo "  [SKIP] $pkg already installed."
            return 0
        fi
        echo "  Installing $pkg..."
        yay -S --needed ${CONFIRM_ARG:-} "$pkg" 2>/dev/null || \
        sudo pacman -S --needed ${CONFIRM_ARG:-} "$pkg" 2>/dev/null || {
            echo -e "  \033[0;31m[FAIL] Could not install $pkg — skipping.\033[0m"
            return 1
        }
        echo "  [OK]  $pkg installed."
    elif [[ "$BASE_DISTRO" == "fedora" ]]; then
        if dnf list --installed "$pkg" >/dev/null 2>&1; then
            echo "  [SKIP] $pkg already installed."
            return 0
        fi
        echo "  Installing $pkg..."
        sudo dnf install -y "$pkg" 2>/dev/null || {
            echo -e "  \033[0;31m[FAIL] Could not install $pkg — skipping.\033[0m"
            return 1
        }
        echo "  [OK]  $pkg installed."
    fi
}

# ── Kvantum ───────────────────────────────────────────────────────────────────
install_if_missing kvantum
install_if_missing kvantum-qt5 || true   # optional qt5 support

# ── uv (required for kde-material-you-colors on fedora) ───────────────────────
if ! command -v uv >/dev/null 2>&1; then
    echo "  Installing uv..."
 #   if [[ "$BASE_DISTRO" == "arch" ]]; then
    install_if_missing uv || curl -LsSf https://astral.sh/uv/install.sh | sh
    #else
     #   curl -LsSf https://astral.sh/uv/install.sh | sh
    #fi
    # Add uv to path for current session if installed via script
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
fi

# ── kde-material-you-colors ───────────────────────────────────────────────────
if [[ "${APPLY_MATERIAL_YOU:-true}" == "true" ]]; then
    if [[ "$BASE_DISTRO" == "arch" ]]; then
        install_if_missing kde-material-you-colors
    elif [[ "$BASE_DISTRO" == "fedora" ]]; then
        if ! command -v kde-material-you-colors >/dev/null 2>&1; then
            echo "  Installing kde-material-you-colors via uv..."
            sudo dnf install -y dbus-devel dbus-glib-devel python3-devel
            uv tool install kde-material-you-colors >/dev/null 2>&1 || {
                echo -e "  \033[0;31m[FAIL] Could not install kde-material-you-colors — skipping.\033[0m"
            }
        else
            echo "  [SKIP] kde-material-you-colors already installed."
        fi
    fi
else
    echo "  [SKIP] Skipping kde-material-you-colors installation."
fi

# ── darkly (plasma theme) ─────────────────────────────────────────────────────
# (darkly is installed via illogical-impulse-fonts-themes in installDP.sh or feddeps.toml)

# Update plasma configuration for default look/feel if needed
    kwriteconfig6 --file plasmarc --group "Theme" --key "name" "Darkly" 2>/dev/null || true.

echo "[OK]  KDE extra apps step complete."
