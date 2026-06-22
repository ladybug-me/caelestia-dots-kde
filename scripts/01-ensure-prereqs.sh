#!/usr/bin/env bash
# 01-ensure-prereqs.sh — Ensure prerequisites are installed.
# Idempotent: exits immediately if present.

if [[ "$BASE_DISTRO" == "arch" ]]; then
    ensure_yay() {
        if command -v yay >/dev/null 2>&1; then
            echo "[OK]  yay is already installed."
            return 0
        fi

        echo "==> yay not found — installing..."

        if ! command -v pacman >/dev/null 2>&1; then
            echo -e "\033[0;31m[ERR] pacman not found. This installer requires Arch Linux.\033[0m"
            exit 1
        fi

        sudo pacman -S --needed --noconfirm base-devel git

        local tmpdir
        tmpdir="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay-bin.git "$tmpdir"
        (
            cd "$tmpdir"
            makepkg -si --noconfirm
        )
        rm -rf "$tmpdir"
        echo "[OK]  yay installed."
    }

    ensure_yay

    echo "==> Configuring yay sudo looping and disabling interactive menus..."
    yay -Y --sudoloop --nocleanmenu --nodiffmenu --save 2>/dev/null || true
    echo "[OK]  yay configured."

elif [[ "$BASE_DISTRO" == "fedora" ]]; then
    echo "==> Checking for Fedora prerequisites (dnf, yq, createrepo_c, jq)..."

    if ! command -v dnf >/dev/null 2>&1; then
        echo -e "\033[0;31m[ERR] dnf not found. This installer requires Fedora 42 or later.\033[0m"
        exit 1
    fi

    if command -v yq >/dev/null 2>&1 && command -v createrepo_c >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        echo "[OK]  Prerequisites are already installed."
    else
        echo "==> Missing prerequisites — installing..."
        sudo dnf install -y yq createrepo_c jq
        echo "[OK]  Prerequisites installed."
    fi
fi
