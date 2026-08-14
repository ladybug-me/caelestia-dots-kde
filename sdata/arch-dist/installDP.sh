#!/usr/bin/env bash
# installDP.sh - Arch package installation for Caelestia KDE Port

set -uo pipefail

log()  { echo -e "\033[0;36m[INFO]\033[0m $*"; }
err()  { echo -e "\033[0;31m[ERR]\033[0m  $*"; }

log "Installing Arch packages..."

INSTALL_FISH="${INSTALL_FISH:-true}"
INSTALL_PAPIRUS="${INSTALL_PAPIRUS:-true}"
INSTALL_DARKLY="${INSTALL_DARKLY:-true}"

# Ensure yay
if ! command -v yay >/dev/null 2>&1; then
    log "yay not found - installing..."
    sudo pacman -S --needed --noconfirm base-devel git || true
    tmpdir="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmpdir"
    (
        cd "$tmpdir" || exit 1
        makepkg -si --noconfirm
    )
    rm -rf "$tmpdir"
fi

# Core dependencies split by group — controlled via PACKAGE_GROUP env var
PACKAGE_GROUP="${PACKAGE_GROUP:-all}"

CORE_PACKAGES=(
    cmake ninja ccache
    wl-clipboard cliphist wl-clip-persist inotify-tools app2unit wireplumber trash-cli jq aubio lm_sensors
    libpipewire glibc libcava qt6-declarative gcc-libs qt6-base qt6-declarative qt6-wayland libqalculate kpipewire kglobalaccel kglobalacceld libsecret
    networkmanager-qt
    ffmpeg
)

SHELL_PACKAGES=(
    caelestia-cli quickshell-git
    foot eza fastfetch starship btop bash
)

THEME_PACKAGES=(
    adw-gtk-theme ttf-jetbrains-mono-nerd ttf-material-symbols-variable ttf-rubik-vf ttf-cascadia-code-nerd
    noto-fonts noto-fonts-cjk noto-fonts-emoji
)

UTILITY_PACKAGES=(
    swappy ddcutil networkmanager imagemagick tesseract tesseract-data-eng satty spectacle xdg-utils sassc bat ripgrep lazygit xdg-user-dirs
)

# Build final package list based on selected group
PACKAGES=()
case "$PACKAGE_GROUP" in
    core)   PACKAGES=("${CORE_PACKAGES[@]}") ;;
    shell)  PACKAGES=("${SHELL_PACKAGES[@]}") ;;
    themes) PACKAGES=("${THEME_PACKAGES[@]}") ;;
    utils)  PACKAGES=("${UTILITY_PACKAGES[@]}") ;;
    all|*)  PACKAGES=("${CORE_PACKAGES[@]}" "${SHELL_PACKAGES[@]}" "${THEME_PACKAGES[@]}" "${UTILITY_PACKAGES[@]}") ;;
esac

if [[ "$PACKAGE_GROUP" == "all" || "$PACKAGE_GROUP" == "shell" ]]; then
    if [[ "$INSTALL_FISH" == "true" ]]; then
        PACKAGES+=(fish)
    else
        log "Skipping Fish installation by user choice."
    fi
fi

if [[ "$PACKAGE_GROUP" == "all" || "$PACKAGE_GROUP" == "themes" ]]; then
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
fi

log "Installing packages (group: $PACKAGE_GROUP)..."
FAILED_PKGS=()

# Batch install all packages at once — much faster than individual yay calls
if ! yay -S --needed --noconfirm "${PACKAGES[@]}"; then
    log "Batch install had failures. Retrying individually..."
    for pkg in "${PACKAGES[@]}"; do
        # Skip packages already installed by the batch attempt
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            continue
        fi
        if ! yay -S --needed --noconfirm "$pkg"; then
            log "yay failed to install $pkg. Attempting manual build from AUR..."
            tmpdir="$(mktemp -d)"
            if git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$tmpdir"; then
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
fi

if [ ${#FAILED_PKGS[@]} -ne 0 ]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
    err "The following packages could not be installed:"
    for pkg in "${FAILED_PKGS[@]}"; do
        err "  - $pkg"
        echo "$pkg" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"
    done
fi

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update || true
fi

if command -v sassc >/dev/null 2>&1 && ! command -v sass >/dev/null 2>&1; then
    sudo ln -sf /usr/bin/sassc /usr/local/bin/sass || true
fi

log "Arch package installation complete."
