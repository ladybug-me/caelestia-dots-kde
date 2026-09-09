#!/usr/bin/env bash
# un08-remove-packages.sh - optionally remove the packages the installer
# added, plus pip/uv/KWin-script extras. Skips entirely unless the user
# opted in via the Uninstall picker screen's "remove packages" toggle.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

if [[ "${REMOVE_PACKAGES:-false}" != "true" ]]; then
    skip "Package removal skipped (user chose to keep packages)"
    exit 0
fi

BASE_DISTRO="${BASE_DISTRO:-unknown}"

ARCH_PACKAGES=(
    caelestia-cli quickshell
    cmake ninja
    wl-clipboard cliphist inotify-tools app2unit wireplumber trash-cli
    jq aubio lm_sensors libcava libqalculate
    foot fish eza fastfetch starship btop
    adw-gtk-theme papirus-icon-theme
    ttf-jetbrains-mono-nerd ttf-material-symbols-variable
    ttf-rubik-vf ttf-cascadia-code-nerd darkly darkly-bin
    swappy brightnessctl ddcutil imagemagick
    tesseract tesseract-data-eng satty spectacle sassc
    kvantum kvantum-qt5 kde-material-you-colors
    keyd
)

FEDORA_PACKAGES=(
    quickshell-git caelestia-cli
    cmake ninja-build
    wl-clipboard cliphist inotify-tools app2unit wireplumber trash-cli
    jq aubio lm_sensors lm_sensors-devel libcava libcava-devel libqalculate libqalculate-devel
    foot fish eza fastfetch starship btop
    adw-gtk3-theme google-rubik-fonts papirus-icon-theme darkly
    swappy brightnessctl ddcutil imagemagick
    tesseract tesseract-langpack-eng spectacle
    fuzzel satty slurp grim sassc
    ffmpeg gpu-screen-recorder
    qt6-qtdeclarative qt6-qtdeclarative-devel
    qt6-qtsvg qt6-qtsvg-devel qt6-qtshadertools-devel
    pipewire-devel aubio-devel
    dbus-devel dbus-glib-devel python3-devel
    kvantum kde-material-you-colors
    keyd
)

DEBIAN_PACKAGES=(
    cmake ninja-build ccache g++ build-essential
    wl-clipboard cliphist inotify-tools wireplumber trash-cli jq yq
    libaubio-dev aubio-tools lm-sensors libsensors-dev cava
    libpipewire-0.3-dev pipewire
    qt6-base-dev qt6-base-private-dev qt6-declarative-dev qml6-module-qtquick qt6-wayland qt6-wayland-dev qt6-svg-dev qt6-shadertools-dev
    libkf6globalaccel-dev libkf6windowsystem-dev libkf6kpipewire-dev libsecret-1-dev libkirigami-dev libkdecorations3-dev libkf6style-dev libkf6kcmutils-dev libkf6colorscheme-dev
    ffmpeg libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libqalculate-dev qalc
    foot fish eza fastfetch btop bash
    adw-gtk3-theme fonts-rubik papirus-icon-theme darkly
    fuzzel swappy brightnessctl ddcutil network-manager imagemagick
    tesseract-ocr tesseract-ocr-eng kde-spectacle slurp grim xdg-utils sassc
    libdbus-1-dev libdbus-glib-1-dev python3-dev
    qt6-style-kvantum kvantum quickshell
    libxi-dev libdrm-dev libx11-dev libxcomposite-dev libxdamage-dev libxrender-dev libxrandr-dev libpulse-dev libva-dev libcap-dev libavfilter-dev libvulkan-dev
)

info "Removing packages for base distro: $BASE_DISTRO"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    mapfile -t _installed < <(yay -Qq "${ARCH_PACKAGES[@]}" 2>/dev/null)
    if [[ ${#_installed[@]} -gt 0 ]]; then
        yay -Rns --noconfirm "${_installed[@]}" 2>/dev/null || \
            warn "Some packages could not be removed automatically. Check manually."
    fi
    ok "Arch packages removed"
elif [[ "$BASE_DISTRO" == "fedora" ]]; then
    sudo dnf remove -y "${FEDORA_PACKAGES[@]}" 2>/dev/null || \
        warn "Some packages could not be removed. Check manually."
    ok "Fedora packages removed"
elif [[ "$BASE_DISTRO" == "debian" ]]; then
    sudo apt-get remove -y "${DEBIAN_PACKAGES[@]}" 2>/dev/null || \
        warn "Some packages could not be removed. Check manually."
    ok "Debian packages removed"
else
    warn "Unknown base distro ($BASE_DISTRO); skipping distro package removal."
fi

if command -v caelestia >/dev/null 2>&1 || python3 -m caelestia --help &>/dev/null 2>&1; then
    sudo pip3 uninstall -y caelestia 2>/dev/null || true
    pip3 uninstall -y caelestia 2>/dev/null || true
    ok "Removed caelestia pip package"
fi

if command -v uv >/dev/null 2>&1; then
    uv tool uninstall kde-material-you-colors 2>/dev/null || true
    uv tool uninstall konsave 2>/dev/null || true
    ok "Removed uv tools: kde-material-you-colors, konsave"
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    if kpackagetool6 -t KWin/Script -s krohnkite >/dev/null 2>&1; then
        kpackagetool6 -t KWin/Script -r krohnkite 2>/dev/null || true
        ok "Removed Krohnkite KWin script"
    fi
fi
