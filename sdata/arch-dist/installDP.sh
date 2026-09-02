#!/usr/bin/env bash
# installDP.sh - Arch package installation for Caelestia KDE Port

set -uo pipefail

log()  { printf '  [INFO]  %s\n' "$*"; }
err()  { printf '  [ERR]   %s\n' "$*" >&2; }

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
    libpipewire glibc qt6-declarative gcc-libs qt6-base qt6-declarative qt6-wayland libqalculate kpipewire kglobalaccel kglobalacceld libsecret ksshaskpass
    networkmanager-qt vulkan-headers
    ffmpeg
)

SHELL_PACKAGES=(
    caelestia-cli quickshell
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
fi

# libcava is installed only via package managers: it is prebuilt by CI into a
# binary repo hosted on GitHub Releases (see
# .github/workflows/prebuilt-artifacts.yml) and falls back to the AUR package
# when the repo is unreachable. It is never compiled from source on the
# machine. Darkly is installed prebuilt (own binary repo, or the darkly-bin
# AUR package) so it is never compiled on the machine.
PREBUILT_PKGS=()
if [[ "$PACKAGE_GROUP" == "all" || "$PACKAGE_GROUP" == "core" ]]; then
    PREBUILT_PKGS+=(libcava)
fi
if [[ "$PACKAGE_GROUP" == "all" || "$PACKAGE_GROUP" == "themes" ]]; then
    if [[ "$INSTALL_DARKLY" == "true" ]]; then
        PREBUILT_PKGS+=(darkly)
    else
        log "Skipping Darkly package installation by user choice."
    fi
fi

# Map a binary-repo package name to the AUR package to install when the binary
# repo is unreachable. Darkly is published to the AUR as darkly-bin (prebuilt),
# so we install that instead of compiling the darkly source package.
aur_pkg_for() {
    case "$1" in
        darkly) echo "darkly-bin" ;;
        *)      echo "$1" ;;
    esac
}

BIN_REPO_NAME="caelestia-bin"
BIN_REPO_URL="https://github.com/ladybug-me/caelestia-dots-kde/releases/download/caelestia-bin-repo"

install_from_binary_repo() {
    if ! grep -q "^\[$BIN_REPO_NAME\]" /etc/pacman.conf 2>/dev/null; then
        {
            echo ""
            echo "[$BIN_REPO_NAME]"
            echo "SigLevel = Optional"
            echo "Server = $BIN_REPO_URL"
            echo ""
        } | sudo tee -a /etc/pacman.conf >/dev/null
    fi
    sudo pacman -Sy --noconfirm >/dev/null 2>&1
}

if [[ ${#PREBUILT_PKGS[@]} -gt 0 ]] && [[ -z "${CAELESTIA_SKIP_BINARY_REPO:-}" ]]; then
    if install_from_binary_repo; then
        for pkg in "${PREBUILT_PKGS[@]}"; do
            if sudo pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1; then
                log "Installed $pkg from the prebuilt repo."
            else
                log "Prebuilt $pkg unavailable; installing from the AUR."
                PACKAGES+=("$(aur_pkg_for "$pkg")")
            fi
        done
    else
        log "Prebuilt repo unreachable; installing from the AUR instead."
        for pkg in "${PREBUILT_PKGS[@]}"; do
            PACKAGES+=("$(aur_pkg_for "$pkg")")
        done
        sudo sed -i "/^\[$BIN_REPO_NAME\]/,/^$/d" /etc/pacman.conf
    fi
elif [[ ${#PREBUILT_PKGS[@]} -gt 0 ]]; then
    for pkg in "${PREBUILT_PKGS[@]}"; do
        PACKAGES+=("$(aur_pkg_for "$pkg")")
    done
fi

log "Installing packages (group: $PACKAGE_GROUP)..."
FAILED_PKGS=()

# Source-compilation fallbacks for AUR packages with no reliable binary repo
# copy. When yay can't download/fetch an AUR package (or its source), build it
# directly from the upstream source instead of failing outright.
# Key: AUR package name -> source repo URL. Labels under "build type" below
# select the build backend.
SOURCE_BUILD_REPOS=(
    # package            repo
    "ttf-rubik-vf        https://github.com/googlefonts/rubik"
    "app2unit            https://github.com/Vladimir-csp/app2unit"
    "python-materialyoucolor https://github.com/gregwym/MaterialYouColor.py"
    "caelestia-cli       https://github.com/dim-ghub/caelestia-cli"
)

# Resolve a package name to its source repo URL (empty if not a source-build target)
source_repo_for() {
    local name="$1" entry pkg url
    for entry in "${SOURCE_BUILD_REPOS[@]}"; do
        read -r pkg url <<<"$entry"
        if [[ "$pkg" == "$name" ]]; then
            echo "$url"
            return 0
        fi
    done
    echo ""
    return 1
}

# Build a package from its upstream source repository. Uses the build backend
# the project ships (meson, CMake, autotools, or a plain makefile).
build_from_source() {
    local pkg="$1" repo="$2" tmpdir
    tmpdir="$(mktemp -d)"
    if ! git clone --depth 1 "$repo" "$tmpdir"; then
        err "Failed to clone source for $pkg from $repo."
        rm -rf "$tmpdir"
        return 1
    fi
    (
        cd "$tmpdir" || exit 1
        if [ -f "meson.build" ]; then
            meson setup build && meson compile -C build && sudo meson install -C build
        elif [ -f "CMakeLists.txt" ]; then
            cmake -B build && cmake --build build && sudo cmake --install build
        elif [ -x "autogen.sh" ] || [ -f "configure.ac" ] || [ -f "configure" ]; then
            if [ -x "autogen.sh" ]; then ./autogen.sh; fi
            ./configure && make && sudo make install
        elif [ -f "Makefile" ] || [ -f "makefile" ] || [ -f "GNUmakefile" ]; then
            make && sudo make install
        else
            err "No recognized build system for $pkg; skipping source build."
            exit 1
        fi
    ) || {
        err "Manual build for $pkg failed."
        rm -rf "$tmpdir"
        return 1
    }
    rm -rf "$tmpdir"
    return 0
}

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
            _built=no
            tmpdir="$(mktemp -d)"
            if git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "$tmpdir"; then
                (
                    cd "$tmpdir" || exit 1
                    makepkg -si --noconfirm
                ) && _built=yes || {
                    err "Manual build from AUR for $pkg failed."
                }
            else
                err "Could not fetch AUR repository for $pkg."
            fi
            rm -rf "$tmpdir"

            # Last resort: compile straight from upstream source if the AUR
            # build (or its source download) failed and we know the repo.
            if [[ "$_built" != "yes" ]]; then
                repo="$(source_repo_for "$pkg")"
                if [[ -n "$repo" ]]; then
                    log "Compiling $pkg from source ($repo)..."
                    if build_from_source "$pkg" "$repo"; then
                        log "Built $pkg from source."
                    else
                        FAILED_PKGS+=("$pkg")
                    fi
                else
                    err "No source repository mapping for $pkg."
                    FAILED_PKGS+=("$pkg")
                fi
            fi
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

if [[ "$PACKAGE_GROUP" == "all" || "$PACKAGE_GROUP" == "themes" ]]; then
    if [[ "$INSTALL_DARKLY" == "true" ]]; then
        log "Installing Darkly GTK theme..."
        yay -S --needed --noconfirm sassc >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm sassc >/dev/null 2>&1 || true
        tmpdir="$(mktemp -d)"
        if git clone --depth 1 https://github.com/wrymt/darkly-gtk "$tmpdir"; then
            (
                cd "$tmpdir" || exit 1
                ./install.sh -l || err "Failed to install Darkly GTK theme."
            )
        else
            err "Failed to clone Darkly GTK theme."
        fi
        rm -rf "$tmpdir"
    else
        log "Skipping Darkly GTK theme by user choice."
    fi
fi

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update || true
fi

if command -v sassc >/dev/null 2>&1 && ! command -v sass >/dev/null 2>&1; then
    sudo ln -sf /usr/bin/sassc /usr/local/bin/sass || true
fi

log "Arch package installation complete."
