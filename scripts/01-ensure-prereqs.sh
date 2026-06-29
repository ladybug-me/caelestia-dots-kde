#!/usr/bin/env bash
# 01-ensure-prereqs.sh - Ensure prerequisites are installed.
# Idempotent: exits immediately if present.

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BUNDLE_DIR/scripts/00-ui.sh"

ui_section "Step 1/11 - Prerequisites"

if [[ "$BASE_DISTRO" == "arch" ]]; then
    ensure_yay() {
        if command -v yay >/dev/null 2>&1; then
            ui_ok "yay is already installed."
            return 0
        fi

        ui_info "yay not found. Installing..."

        if ! command -v pacman >/dev/null 2>&1; then
            ui_die "pacman not found. This installer requires Arch Linux."
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
        ui_ok "yay installed."
    }

    ensure_yay

    ui_info "Configuring yay sudo looping and disabling interactive menus..."
    yay -Y --sudoloop --nocleanmenu --nodiffmenu --save 2>/dev/null || true
    ui_ok "yay configured."

elif [[ "$BASE_DISTRO" == "fedora" ]]; then
    ui_info "Checking for Fedora prerequisites (dnf, yq, createrepo_c, jq)..."

    if ! command -v dnf >/dev/null 2>&1; then
        ui_die "dnf not found. This installer requires Fedora 42 or later."
    fi

    if command -v yq >/dev/null 2>&1 && command -v createrepo_c >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        ui_ok "Prerequisites are already installed."
    else
        ui_info "Missing prerequisites. Installing..."
        sudo dnf install -y yq createrepo_c jq
        ui_ok "Prerequisites installed."
    fi
fi
