#!/usr/bin/env bash
# installDP_debian.sh - Debian/Ubuntu package installation for Caelestia KDE Port

set -uo pipefail

log()  { echo -e "\033[0;36m[INFO]\033[0m $*"; }
err()  { echo -e "\033[0;31m[ERR]\033[0m  $*"; }

log "Installing Debian packages..."

INSTALL_FISH="${INSTALL_FISH:-true}"
INSTALL_PAPIRUS="${INSTALL_PAPIRUS:-true}"
INSTALL_DARKLY="${INSTALL_DARKLY:-true}"

# Core dependencies split by group — controlled via PACKAGE_GROUP env var
PACKAGE_GROUP="${PACKAGE_GROUP:-all}"

CORE_PACKAGES=(
    cmake ninja-build ccache g++ build-essential
    wl-clipboard cliphist inotify-tools wireplumber trash-cli jq yq
    libaubio-dev aubio-tools lm-sensors libsensors-dev
    libpipewire-0.3-dev pipewire libc6
    qt6-base-dev qt6-base-private-dev qt6-declarative-dev qml6-module-qtquick qt6-wayland qt6-wayland-dev qt6-svg-dev qt6-shadertools-dev
    libkf6globalaccel-dev libkf6windowsystem-dev libkf6networkmanagerqt-dev libkpipewire-dev libsecret-1-dev
    ffmpeg libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libqalculate-dev qalc
)

SHELL_PACKAGES=(
    foot eza fastfetch btop bash
)

THEME_PACKAGES=(
    adw-gtk3
)

UTILITY_PACKAGES=(
    fuzzel swappy ddcutil network-manager imagemagick tesseract-ocr tesseract-ocr-eng kde-spectacle slurp grim xdg-utils sassc python3-venv uv konsave
)

# Packages that need manual build or script fallback on Debian if apt package missing
FALLBACK_PKGS=(
    quickshell starship libcava app2unit gpu-screen-recorder wl-clip-persist satty adw-gtk3 uv konsave
)

# Build final package list based on selected group
PACKAGES=()
FALLBACK_TARGETS=()
case "$PACKAGE_GROUP" in
    core)   PACKAGES=("${CORE_PACKAGES[@]}");   FALLBACK_TARGETS=("libcava" "app2unit") ;;
    shell)  PACKAGES=("${SHELL_PACKAGES[@]}");  FALLBACK_TARGETS=("quickshell" "starship") ;;
    themes) PACKAGES=("${THEME_PACKAGES[@]}");  FALLBACK_TARGETS=("adw-gtk3") ;;
    utils)  PACKAGES=("${UTILITY_PACKAGES[@]}"); FALLBACK_TARGETS=("gpu-screen-recorder" "wl-clip-persist" "satty" "uv" "konsave") ;;
    all|*)  PACKAGES=("${CORE_PACKAGES[@]}" "${SHELL_PACKAGES[@]}" "${THEME_PACKAGES[@]}" "${UTILITY_PACKAGES[@]}")
            FALLBACK_TARGETS=("quickshell" "starship" "libcava" "app2unit" "gpu-screen-recorder" "wl-clip-persist" "satty" "adw-gtk3" "uv" "konsave") ;;
esac

log "Installing packages (group: $PACKAGE_GROUP)..."

# Optional packages only included for relevant groups (or "all")
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

log "Updating apt package index..."
sudo apt-get update || true

FAILED_PKGS=()

# Filter batch packages (excluding known fallback build targets)
BATCH_PKGS=()
for pkg in "${PACKAGES[@]}"; do
    _is_fallback="no"
    for fb in "${FALLBACK_TARGETS[@]}"; do
        if [[ "$pkg" == "$fb" ]]; then _is_fallback="yes"; break; fi
    done
    if [[ "$_is_fallback" == "no" ]]; then
        BATCH_PKGS+=("$pkg")
    fi
done

# Batch install standard packages via apt
if [[ ${#BATCH_PKGS[@]} -gt 0 ]]; then
    log "Batch installing standard Debian packages..."
    if ! sudo apt-get install -y --no-install-recommends "${BATCH_PKGS[@]}"; then
        log "Batch install had failures. Retrying standard packages individually..."
        for pkg in "${BATCH_PKGS[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                sudo apt-get install -y --no-install-recommends "$pkg" || {
                    err "apt failed to install $pkg"
                    FAILED_PKGS+=("$pkg")
                }
            fi
        done
    fi
fi

# Process fallback / manual build targets
for pkg in "${FALLBACK_TARGETS[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1 || command -v "$pkg" >/dev/null 2>&1; then
        continue
    fi

    if sudo apt-get install -y "$pkg" 2>/dev/null; then
        continue
    fi

    log "apt failed or package missing for $pkg. Attempting manual fallback..."
    case "$pkg" in
        quickshell)
            log "Attempting to install quickshell from PPA..."
            sudo apt-get install -y software-properties-common || true
            sudo add-apt-repository -y ppa:avengemedia/danklinux || true
            sudo apt-get update || true
            sudo apt-get install -y quickshell || { err "Failed to install quickshell from PPA."; FAILED_PKGS+=("$pkg"); }
            ;;
        libcava|cava)
            tmpdir="$(mktemp -d)"
            sudo apt-get install -y libasound2-dev libfftw3-dev libpulse-dev libiniparser-dev meson ninja-build cmake gcc g++ || true
            if git clone --depth 1 https://github.com/LukashonakV/cava "$tmpdir"; then
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
            sudo apt-get install -y make || true
            if git clone --depth 1 https://github.com/Vladimir-csp/app2unit "$tmpdir"; then
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
            sudo apt-get install -y build-essential git ffmpeg meson libxi-dev libdrm-dev libavcodec-dev libavformat-dev libx11-dev libxcomposite-dev libxdamage-dev libxrender-dev libxrandr-dev libpulse-dev libva-dev libcap-dev libdbus-1-dev libpipewire-0.3-dev libavfilter-dev libvulkan-dev || true
            if git clone --depth 1 https://repo.dec05eba.com/gpu-screen-recorder "$tmpdir"; then
                (
                    cd "$tmpdir" || exit 1
                    sudo ./install.sh
                ) || { err "Manual build for $pkg failed."; FAILED_PKGS+=("$pkg"); }
            else
                err "Failed to clone $pkg."
                FAILED_PKGS+=("$pkg")
            fi
            rm -rf "$tmpdir"
            ;;
        starship)
            if curl -sS https://starship.rs/install.sh | sh -s -- -y; then  # ci:allow-curl-pipe
                log "starship installed successfully."
            else
                err "Manual build for $pkg failed."
                FAILED_PKGS+=("$pkg")
            fi
            ;;
        wl-clip-persist)
            sudo apt-get install -y build-essential cargo git libwayland-dev || true
            if command -v cargo >/dev/null 2>&1; then
                tmpdir="$(mktemp -d)"
                if git clone --depth 1 https://github.com/Linus789/wl-clip-persist "$tmpdir"; then
                    (
                        cd "$tmpdir" || exit 1
                        cargo build --release
                        sudo cp target/release/wl-clip-persist /usr/local/bin/
                    ) || { err "cargo build $pkg failed."; FAILED_PKGS+=("$pkg"); }
                else
                    err "Failed to clone $pkg."
                    FAILED_PKGS+=("$pkg")
                fi
                rm -rf "$tmpdir"
            else
                err "Cargo not available to build $pkg."
                FAILED_PKGS+=("$pkg")
            fi
            ;;
        satty)
            if ! command -v cargo-binstall >/dev/null 2>&1; then
                curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash || true # ci:allow-curl-pipe
                export PATH="$PATH:$HOME/.cargo/bin"
                # Add to PATH permanently for future shell sessions
                for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
                    touch "$rc" 2>/dev/null || true
                    grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$rc" 2>/dev/null || echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$rc" 2>/dev/null || true
                done
                if command -v fish >/dev/null 2>&1; then
                    fish -c 'fish_add_path ~/.cargo/bin' >/dev/null 2>&1 || true
                fi
            fi
            if command -v cargo-binstall >/dev/null 2>&1; then
                cargo-binstall -y satty || {
                    log "Normal cargo-binstall failed. Trying with sudo..."
                    sudo "$(command -v cargo-binstall)" -y satty || { err "sudo cargo-binstall $pkg failed."; FAILED_PKGS+=("$pkg"); }
                }
            else
                err "cargo-binstall not available to install $pkg."
                FAILED_PKGS+=("$pkg")
            fi
            ;;
        uv)
            if curl -LsSf https://astral.sh/uv/install.sh | sh; then # ci:allow-curl-pipe
                log "uv installed successfully."
                export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
            else
                err "Failed to install uv."
                FAILED_PKGS+=("$pkg")
            fi
            ;;
        konsave)
            export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
            if command -v uv >/dev/null 2>&1; then
                uv tool install konsave || { err "uv tool install $pkg failed."; FAILED_PKGS+=("$pkg"); }
            else
                err "uv is required to install $pkg, but it is not available."
                FAILED_PKGS+=("$pkg")
            fi
            ;;
        adw-gtk3)
            tmpdir="$(mktemp -d)"
            log "Downloading adw-gtk3 theme..."
            if curl -sL "https://github.com/lassekongo83/adw-gtk3/releases/download/v5.3/adw-gtk3v5.3.tar.xz" | tar -xJ -C "$tmpdir"; then
                mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/themes"
                cp -r "$tmpdir/adw-gtk3" "$tmpdir/adw-gtk3-dark" "${XDG_DATA_HOME:-$HOME/.local/share}/themes/" || { err "Failed to install adw-gtk3"; FAILED_PKGS+=("$pkg"); }
            else
                err "Failed to download adw-gtk3 theme."
                FAILED_PKGS+=("$pkg")
            fi
            rm -rf "$tmpdir"
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

if [[ "$PACKAGE_GROUP" == "all" || "$PACKAGE_GROUP" == "themes" ]]; then

log "Downloading and installing required custom fonts (parallel)..."
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

# Download all fonts in parallel
curl -sL "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" -o "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/MaterialSymbolsRounded.ttf" &
_pid_ms=$!

curl -sL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/CascadiaCode.zip" -o "/tmp/CascadiaCode.zip" &
_pid_cc=$!

curl -sL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip" -o "/tmp/JetBrainsMono.zip" &
_pid_jb=$!

curl -sL "https://github.com/google/fonts/raw/main/ofl/rubik/Rubik-VariableFont_wght.ttf" -o "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/Rubik-VariableFont_wght.ttf" &
_pid_ru=$!

# Wait for all downloads to finish
wait $_pid_ms $_pid_cc $_pid_jb $_pid_ru

# Extract zip files
unzip -qo "/tmp/CascadiaCode.zip" -d "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" 2>/dev/null && rm -f "/tmp/CascadiaCode.zip" || { err "Failed to extract CascadiaCode font."; echo "CascadiaCode font" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"; }
unzip -qo "/tmp/JetBrainsMono.zip" -d "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" 2>/dev/null && rm -f "/tmp/JetBrainsMono.zip" || { err "Failed to extract JetBrains Mono Nerd Font."; echo "JetBrains Mono Nerd Font" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"; }
# Material Symbols and Rubik are single .ttf files, no extraction needed
[[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/MaterialSymbolsRounded.ttf" ]] || { err "Failed to download Material Symbols font."; echo "Material Symbols font" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"; }
[[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/Rubik-VariableFont_wght.ttf" ]] || { err "Failed to download Rubik font."; echo "Rubik font" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_packages.txt"; }

fc-cache -f

log "Building and Installing Darkly KDE Theme..."
if [[ "$INSTALL_DARKLY" == "true" ]]; then
    if ! command -v darkly >/dev/null 2>&1; then
        tmpdir="$(mktemp -d)"
        sudo apt-get install -y cmake extra-cmake-modules gettext libkf6config-dev libkf6configwidgets-dev libkf6coreaddons-dev libkf6guiaddons-dev libkf6i18n-dev libkf6iconthemes-dev libkf6kio-dev libkf6widgetsaddons-dev libkf6windowsystem-dev libkf6colorscheme-dev libkf6kcmutils-dev libkirigami-dev libkdecorations3-dev libkf6style-dev qt6-base-dev qt6-declarative-dev || true
        if git clone --depth 1 https://github.com/Bali10050/Darkly "$tmpdir"; then
            (
                cd "$tmpdir" || exit 1
                cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_QT5=OFF && cmake --build build -j"$(nproc)" && cd build && sudo cmake --install .
            ) || err "Failed to build Darkly theme from source."
        fi
        rm -rf "$tmpdir"
    fi
else
    log "Skipping Darkly package installation by user choice."
fi

fi  # end of PACKAGE_GROUP themes/all block

if [[ "$PACKAGE_GROUP" == "all" || "$PACKAGE_GROUP" == "shell" ]]; then

log "Installing Caelestia CLI wrapper..."
if ! command -v caelestia >/dev/null 2>&1; then
    sudo apt-get install -y python3-pip python3-build python3-installer python3-hatchling python3-hatch-vcs || true
    tmpdir="$(mktemp -d)"
    (
        cd "$tmpdir" || exit 1
        curl -sL "https://github.com/caelestia-dots/cli/releases/download/v1.0.8/caelestia-1.0.8.tar.gz" -o caelestia.tar.gz
        tar -xzf caelestia.tar.gz
        cd caelestia-1.0.8 || exit 1
        python3 -m build --wheel --no-isolation
        if ! sudo pip3 install dist/*.whl --break-system-packages 2>/dev/null; then
            pip3 install dist/*.whl --user --break-system-packages 2>/dev/null || pip3 install dist/*.whl --user
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

fi  # end of PACKAGE_GROUP shell/all block

log "Debian package installation complete."
