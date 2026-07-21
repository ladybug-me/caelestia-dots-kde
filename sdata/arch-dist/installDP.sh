#!/usr/bin/env bash
# installDP.sh - Arch package installation for Caelestia KDE Port

set -uo pipefail

log()  { echo -e "\033[0;36m[INFO]\033[0m $*"; }
err()  { echo -e "\033[0;31m[ERR]\033[0m  $*"; }

refresh_pkg_dbs() {
    log "Refreshing pacman package databases..."
    sudo pacman -Syy --noconfirm || true
}

install_with_yay_retry() {
    local pkg="$1"
    local attempt

    for attempt in 1 2 3; do
        if yay -S --needed --noconfirm "$pkg"; then
            return 0
        fi

        log "Attempt $attempt/3 failed for $pkg. Refreshing databases and retrying..."
        refresh_pkg_dbs
    done

    return 1
}

log "Installing Arch packages..."

INSTALL_FISH="${INSTALL_FISH:-true}"
INSTALL_PAPIRUS="${INSTALL_PAPIRUS:-true}"
INSTALL_DARKLY="${INSTALL_DARKLY:-true}"

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
    libpipewire glibc libcava qt6-declarative gcc-libs qt6-base qt6-declarative qt6-wayland libqalculate
    # Shell wrapper
    caelestia-cli quickshell-git
    # Shells & terminal
    foot eza fastfetch starship btop bash
    # Themes & Fonts
    adw-gtk-theme ttf-jetbrains-mono-nerd ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd
    # Utilities
    swappy brightnessctl ddcutil networkmanager imagemagick tesseract tesseract-data-eng satty spectacle xdg-utils sassc
    #playerctl
)

if [[ "$INSTALL_FISH" == "true" ]]; then
    PACKAGES+=(fish)
else
    log "Skipping Fish installation by user choice."
fi

if [[ "$INSTALL_PAPIRUS" == "true" ]]; then
    PACKAGES+=(papirus-icon-theme)
else
    log "Skipping Papirus icon theme installation by user choice."
fi

if [[ "$INSTALL_DARKLY" == "true" ]]; then
    PACKAGES+=(darkly)
else
    log "Skipping Darkly package installation by user choice."
fi

log "Syncing package databases and installing packages..."
FAILED_PKGS=()
yay -Syu --noconfirm || true

for pkg in "${PACKAGES[@]}"; do
    if ! install_with_yay_retry "$pkg"; then
        if pacman -Si "$pkg" >/dev/null 2>&1; then
            log "$pkg appears to be an official repo package. Trying pacman fallback..."
            refresh_pkg_dbs
            if sudo pacman -S --needed --noconfirm "$pkg"; then
                continue
            fi

            err "Repository installation failed for $pkg after retries."
            FAILED_PKGS+=("$pkg")
            continue
        fi

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
