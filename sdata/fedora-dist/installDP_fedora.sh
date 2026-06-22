#!/usr/bin/env bash
# installDP_fedora.sh — Fedora package installation for Caelestia KDE Port

set -uo pipefail

log()  { echo -e "\033[0;36m[INFO]\033[0m $*"; }
err()  { echo -e "\033[0;31m[ERR]\033[0m  $*"; }

log "Installing Fedora packages..."

# Core dependencies (minus hyprland-specific ones)
PACKAGES=(
    # build dependencies
    cmake ninja-build
    # Core system tools
    wl-clipboard cliphist inotify-tools wireplumber trash-cli jq aubio lm_sensors lm_sensors-devel
    # lib files
    pipewire-devel glibc qt6-qtdeclarative qt6-qtdeclarative-devel qt6-qtsvg qt6-qtsvg-devel qt6-qtshadertools-devel libgcc qt6-qtbase libqalculate libqalculate-devel aubio-devel
    # Shells & terminal
    foot fish eza fastfetch starship btop bash
    # Themes & Fonts
    adw-gtk3-theme papirus-icon-theme google-rubik-fonts
    # Utilities
    fuzzel swappy brightnessctl ddcutil NetworkManager ImageMagick tesseract tesseract-langpack-eng spectacle gpu-screen-recorder slurp grim xdg-utils sassc
    # playerctl
    # Known to require manual build/copr on Fedora
    app2unit libcava quickshell-git
)

log "Enabling RPM Fusion for H264 hardware codecs..."
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || true
sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || true

PACKAGES+=(ffmpeg)

log "Installing packages via dnf..."
sudo dnf upgrade -y || true

FAILED_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    if sudo dnf install -y "$pkg"; then
        continue
    fi

    log "dnf failed to install $pkg. Attempting copr fallback..."
    COPR_FAILED="yes"
    case "$pkg" in
        quickshell-git|quickshell)
            if sudo dnf copr enable -y errornointernet/quickshell && sudo dnf install -y quickshell-git; then
                COPR_FAILED="no"
            fi
            ;;
        gpu-screen-recorder)
            if sudo dnf copr enable -y brycensranch/gpu-screen-recorder-git && sudo dnf install -y gpu-screen-recorder-ui; then
                COPR_FAILED="no"
            fi
            ;;
        app2unit)
            if sudo dnf copr enable -y celestelove/app2unit && sudo dnf install -y app2unit; then
                COPR_FAILED="no"
            fi
            ;;
        starship)
            if sudo dnf copr enable -y atim/starship && sudo dnf install -y starship; then
                COPR_FAILED="no"
            fi
            ;;
        libcava)
            if sudo dnf copr enable -y celestelove/libcava && sudo dnf install -y libcava-devel; then
                COPR_FAILED="no"
            fi
            ;;

    esac

    if [ "$COPR_FAILED" = "no" ]; then
        continue
    fi

    log "Copr fallback failed or not defined for $pkg. Attempting manual build..."
    case "$pkg" in
        libcava)
            tmpdir="$(mktemp -d)"
            sudo dnf install -y alsa-lib-devel fftw-devel pulseaudio-libs-devel iniparser-devel meson ninja-build cmake gcc-c++
            if git clone https://github.com/LukashonakV/cava "$tmpdir"; then
                (
                    cd "$tmpdir" || exit 1
                    if [ -f "meson.build" ]; then
                        meson setup build && meson compile -C build && sudo meson install -C build
                    elif [ -f "CMakeLists.txt" ]; then
                        cmake -B build && cmake --build build && sudo cmake --install build
                    else
                        ./autogen.sh && ./configure && make && sudo make install
                    fi
                ) || { err "Manual build for $pkg failed."; FAILED_PKGS+=("$pkg"); }
            else
                err "Failed to clone $pkg."
                FAILED_PKGS+=("$pkg")
            fi
            rm -rf "$tmpdir"
            ;;
        app2unit)
            tmpdir="$(mktemp -d)"
            sudo dnf install -y make
            if git clone https://github.com/Vladimir-csp/app2unit "$tmpdir"; then
                (
                    cd "$tmpdir" || exit 1
                    sudo make install
                ) || { err "Manual build for $pkg failed."; FAILED_PKGS+=("$pkg"); }
            else
                err "Failed to clone $pkg."
                FAILED_PKGS+=("$pkg")
            fi
            rm -rf "$tmpdir"
            ;;
        gpu-screen-recorder)
            tmpdir="$(mktemp -d)"
            sudo dnf install -y meson ninja-build pkgconf libXcomposite-devel libXrandr-devel libXfixes-devel libdrm-devel wayland-devel pipewire-devel libcap-devel ffmpeg-devel
            if git clone https://git.dec05eba.com/gpu-screen-recorder "$tmpdir"; then
                (
                    cd "$tmpdir" || exit 1
                    meson setup build && ninja -C build && sudo meson install -C build
                ) || { err "Manual build for $pkg failed."; FAILED_PKGS+=("$pkg"); }
            else
                err "Failed to clone $pkg."
                FAILED_PKGS+=("$pkg")
            fi
            rm -rf "$tmpdir"
            ;;
        starship)
            if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
                log "starship installed successfully."
            else
                err "Manual build for $pkg failed."
                FAILED_PKGS+=("$pkg")
            fi
            ;;
        *)
            err "No manual fallback defined for $pkg."
            FAILED_PKGS+=("$pkg")
            ;;
    esac
done

if [ ${#FAILED_PKGS[@]} -ne 0 ]; then
    mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
    err "The following packages could not be installed:"
    for pkg in "${FAILED_PKGS[@]}"; do
        err "  - $pkg"
        echo "$pkg" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"
    done
fi


log "Downloading and installing required custom fonts (Material Symbols Rounded, Jet Brain Mono & CaskaydiaCove NF)..."
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
curl -sL "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" -o "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/MaterialSymbolsRounded.ttf" || { err "Failed to download Material Symbols font."; echo "Material Symbols font" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"; }
curl -sL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/CascadiaCode.zip" -o "/tmp/CascadiaCode.zip" && unzip -qo "/tmp/CascadiaCode.zip" -d "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" && rm "/tmp/CascadiaCode.zip" || { err "Failed to download CascadiaCode font."; echo "CascadiaCode font" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"; }
curl -sL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip" -o "/tmp/JetBrainsMono.zip" && unzip -qo "/tmp/JetBrainsMono.zip" -d "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" && rm -f "/tmp/JetBrainsMono.zip" || { err "Failed to download JetBrains Mono Nerd Font."; echo "JetBrains Mono Nerd Font" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"; }
fc-cache -f

log "Building and Installing Darkly KDE Theme..."
if ! command -v darkly >/dev/null 2>&1; then
    sudo dnf copr enable -y deltacopy/darkly && sudo dnf install -y darkly || true
fi

log "Installing Caelestia CLI wrapper..."
if ! command -v caelestia >/dev/null 2>&1; then
    sudo dnf install -y python3-pip python3-build python3-installer python3-hatchling python3-hatch-vcs || true
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir" || exit 1
        curl -sL "https://github.com/caelestia-dots/cli/releases/download/v1.0.8/caelestia-1.0.8.tar.gz" -o caelestia.tar.gz
        tar -xzf caelestia.tar.gz
        cd caelestia-1.0.8
        python3 -m build --wheel --no-isolation
        if ! sudo pip3 install dist/*.whl --break-system-packages; then
            pip3 install dist/*.whl --user --break-system-packages
            if [[ -f "$HOME/.local/bin/caelestia" ]]; then
                sudo ln -sf "$HOME/.local/bin/caelestia" /usr/local/bin/caelestia || true
            fi
        fi
        
        # Install fish completions if fish is present
        mkdir -p ~/.config/fish/completions/
        cp ./completions/caelestia.fish ~/.config/fish/completions/ 2>/dev/null || true
    )
    rm -rf "$tmpdir"
fi

if command -v sassc >/dev/null 2>&1 && ! command -v sass >/dev/null 2>&1; then
    sudo ln -sf /usr/bin/sassc /usr/local/bin/sass || true
fi

log "Fedora package installation complete."
