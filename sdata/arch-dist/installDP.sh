#!/usr/bin/env bash
# installDP.sh - Arch package installation for Caelestia KDE Port

set -uo pipefail

log()  { echo -e "\033[0;36m[INFO]\033[0m $*"; }
err()  { echo -e "\033[0;31m[ERR]\033[0m  $*"; }

log "Installing Arch packages..."

# Ensure yay
if ! command -v yay >/dev/null 2>&1; then
    log "yay not found - installing..."
    sudo pacman -S --needed --noconfirm base-devel git || true
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmpdir"
    (
        cd "$tmpdir" || exit 1
        makepkg -si --noconfirm
    )
    rm -rf "$tmpdir"
fi

# Core dependencies (minus hyprland-specific ones)
PACKAGES=(
    # build dependencies
    cmake ninja
    # Core system tools
    wl-clipboard cliphist wl-clip-persist inotify-tools app2unit wireplumber trash-cli jq aubio lm_sensors
    # lib files
    libpipewire glibc libcava qt6-declarative gcc-libs qt6-base qt6-declarative libqalculate
    # Shell wrapper
    caelestia-cli quickshell-git
    # Shells & terminal
    foot fish eza fastfetch starship btop bash
    # Themes & Fonts
    adw-gtk-theme papirus-icon-theme ttf-jetbrains-mono-nerd ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd darkly
    # Utilities
    swappy brightnessctl ddcutil networkmanager imagemagick tesseract tesseract-data-eng satty spectacle xdg-utils sassc
    #playerctl
)

log "Syncing package databases and installing packages..."
FAILED_PKGS=()
yay -Syu --noconfirm || true

for pkg in "${PACKAGES[@]}"; do
    if ! yay -S --needed --noconfirm "$pkg"; then
        log "yay failed to install $pkg. Attempting manual build from AUR..."
        tmpdir="$(mktemp -d)"
        if git clone "https://aur.archlinux.org/${pkg}.git" "$tmpdir"; then
            (
                cd "$tmpdir" || exit 1
                makepkg -si --noconfirm
            ) || {
                err "Manual build for $pkg failed."
                FAILED_PKGS+=("$pkg")
            }
        else
            err "Could not find AUR repository for $pkg."
            FAILED_PKGS+=("$pkg")
        fi
        rm -rf "$tmpdir"
    fi
done

if [ ${#FAILED_PKGS[@]} -ne 0 ]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
    err "The following packages could not be installed:"
    for pkg in "${FAILED_PKGS[@]}"; do
        err "  - $pkg"
        echo "$pkg" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"
    done
fi

if command -v sassc >/dev/null 2>&1 && ! command -v sass >/dev/null 2>&1; then
    sudo ln -sf /usr/bin/sassc /usr/local/bin/sass || true
fi

log "Arch package installation complete."
