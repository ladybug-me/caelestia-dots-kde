#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/privileges.sh"

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SHELL_DIR="$BUNDLE_DIR/shell"

# Prefer Ninja for faster builds; fall back to CMake's default generator when
# it is not available (e.g. a standalone/update run before package install).
# Reflected in the toolchain stamp so a build dir is invalidated if the
# available generator changes.
if command -v ninja >/dev/null 2>&1; then
    CMAKE_GENERATOR="Ninja"
else
    warn "ninja not found; falling back to Unix Makefiles (builds will be slower)."
    CMAKE_GENERATOR="Unix Makefiles"
fi

# Fingerprint of the toolchain that builds Caelestia. Build directories are
# kept between runs so repeated installs/updates rebuild incrementally; they
# are only wiped when this fingerprint changes (e.g. a distro Qt/CMake
# upgrade that would otherwise leave stale object files behind).
# Only the feature version is fingerprinted: patch releases (6.11.2 -> 6.11.3)
# keep their ABI and their headers hash the same in ccache, so wiping the build
# directory for one costs a full rebuild and buys nothing.
caelestia_toolchain_stamp() {
    local cmake_ver qt_ver
    cmake_ver="$(cmake --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
    qt_ver="$(pkg-config --modversion Qt6Core 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+' || true)"
    printf 'bundle:%s cmake:%s qt6core:%s gen:%s\n' "$BUNDLE_DIR" "$cmake_ver" "$qt_ver" "$CMAKE_GENERATOR"
}

# Stamps written before the fingerprint dropped patch versions carried the full
# `cmake version X.Y.Z` string. Normalising both sides keeps those build dirs
# alive instead of forcing one gratuitous full rebuild on upgrade.
caelestia_normalise_stamp() {
    sed -E -e 's/cmake version //' -e 's/([0-9]+\.[0-9]+)\.[0-9]+/\1/g'
}

# Reuse an existing CMake build directory unless the toolchain fingerprint
# changed since the last configure.
prepare_build_dir() {
    local dir="$1"
    if [[ -f "$dir/CMakeCache.txt" && -f "$dir/.caelestia_toolchain_stamp" ]] \
        && [[ "$(caelestia_normalise_stamp < "$dir/.caelestia_toolchain_stamp")" \
            == "$(caelestia_toolchain_stamp | caelestia_normalise_stamp)" ]]; then
        return 0
    fi
    rm -rf "$dir"
    mkdir -p "$dir"
    caelestia_toolchain_stamp > "$dir/.caelestia_toolchain_stamp"
}

# Print only the error lines from a build log (skipping warning spam), plus a
# short tail for context. The full log is always preserved on disk.
show_build_errors() {
    local log="$1"
    grep -E 'error:|FAILED:|ninja: build stopped|CMake Error|make(\[[0-9]+\])?: \*\*\*|undefined reference|ld: ' "$log" || true
    echo "----- last 20 lines of $log -----"
    tail -n 20 "$log"
}

# Leave a core for the desktop: a -j$(nproc) build makes the running session
# stutter for as long as it lasts. CAELESTIA_BUILD_JOBS overrides, and Ninja
# additionally backs off when the load average is already above the core count.
BUILD_JOBS="${CAELESTIA_BUILD_JOBS:-}"
if [[ -z "$BUILD_JOBS" ]]; then
    BUILD_JOBS=$(( $(nproc 2>/dev/null || echo 2) - 1 ))
    if [[ $BUILD_JOBS -lt 1 ]]; then
        BUILD_JOBS=1
    fi
fi

# Both Ninja and Make take -l: hold off on starting new jobs while the machine
# is already loaded, so a build never fully monopolises the desktop.
BUILD_LOAD="$(nproc 2>/dev/null || echo 2)"

# Run compilers at a lower priority so the shell stays responsive during a
# build. Ignored when nice is unavailable.
caelestia_build() {
    if command -v nice >/dev/null 2>&1; then
        nice -n 10 "$@"
    else
        "$@"
    fi
}

# Persistent ccache so repeated installs/updates reuse compiled objects even
# across clean build-directory wipes. The shell build already wires ccache up
# via CMAKE_CXX_COMPILER_LAUNCHER; this only gives it a stable cache dir.
CCACHE_DIR="${CCACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/ccache}"
export CCACHE_DIR
mkdir -p "$CCACHE_DIR"
if command -v ccache >/dev/null 2>&1; then
    ccache --max-size 8G >/dev/null 2>&1 || true
fi


if [[ "${CAELESTIA_SETUP_RUNNING:-0}" == "0" ]]; then
    info "Running standalone update mode... syncing submodules first."
    
    if [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
        info "Initializing all submodules..."
        git submodule sync --recursive >/dev/null 2>&1 || true
        git submodule update --init --recursive --depth 1 --jobs "$(nproc 2>/dev/null || echo 1)" >/dev/null 2>&1 || die "Failed to initialize all submodules"

        # Pin plasma-wallpaper-application to the tagged release.
        WALLPAPER_DIR="$BUNDLE_DIR/src/plasma-wallpaper-application"
        WALLPAPER_TAG="v1.2"
        if [[ -e "$WALLPAPER_DIR/.git" ]]; then
            info "Pinning plasma-wallpaper-application to tag $WALLPAPER_TAG..."
            git -C "$WALLPAPER_DIR" fetch --tags --quiet 2>/dev/null || true
            git -C "$WALLPAPER_DIR" checkout "tags/$WALLPAPER_TAG" --quiet 2>/dev/null || \
                warn "Could not checkout tag $WALLPAPER_TAG for plasma-wallpaper-application; using current HEAD."
        fi
    fi

    info "Installing Caelestia Services..."
    if [[ -f "$BUNDLE_DIR/scripts/06-services.sh" ]]; then
        bash "$BUNDLE_DIR/scripts/06-services.sh" || warn "06-services.sh failed"
    fi

    info "Installing plasma-wallpaper-application..."
    if [[ -f "$BUNDLE_DIR/scripts/02-packages.sh" ]]; then
        bash "$BUNDLE_DIR/scripts/02-packages.sh" || warn "02-packages.sh failed"
    else
        warn "02-packages.sh not found; skipping wallpaper plugin installation."
    fi

    # Only escalate when something is actually missing. Running the package
    # manager unconditionally cost a root prompt and a repo round-trip on every
    # single update, even though the packages were already there.
    missing_packages() {
        local pkg
        for pkg in "$@"; do
            if command -v pacman >/dev/null; then
                pacman -Qq "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
            elif command -v rpm >/dev/null; then
                rpm -q "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
            elif command -v dpkg >/dev/null; then
                dpkg -s "$pkg" >/dev/null 2>&1 || printf '%s\n' "$pkg"
            fi
        done
    }

    # ksshaskpass is in the list so a GUI-launched update has a way to ask for
    # the password once, instead of polkit prompting per privileged command.
    info "Checking Wayland and KDE build dependencies..."
    if command -v pacman >/dev/null; then
        mapfile -t MISSING < <(missing_packages qt6-wayland kpipewire kglobalaccel kglobalacceld ksshaskpass)
        if [[ ${#MISSING[@]} -gt 0 ]]; then
            info "Installing via pacman: ${MISSING[*]}"
            caelestia_sudo pacman -S --needed --noconfirm "${MISSING[@]}" || warn "pacman install failed..."
        fi
    elif command -v dnf >/dev/null; then
        mapfile -t MISSING < <(missing_packages qt6-qtwayland qt6-qtwayland-devel kf6-kglobalaccel-devel kf6-kwindowsystem-devel qt6-qtbase-private-devel kf6-kpipewire kf6-kpipewire-devel ksshaskpass)
        if [[ ${#MISSING[@]} -gt 0 ]]; then
            info "Installing via dnf: ${MISSING[*]}"
            caelestia_sudo dnf install -y "${MISSING[@]}" || warn "dnf install failed..."
        fi
    elif command -v apt-get >/dev/null; then
        mapfile -t MISSING < <(missing_packages qt6-wayland qt6-wayland-dev libkf6globalaccel-dev libkf6windowsystem-dev qt6-base-private-dev libkf6kpipewire-dev ksshaskpass)
        if [[ ${#MISSING[@]} -gt 0 ]]; then
            info "Installing via apt: ${MISSING[*]}"
            caelestia_sudo apt-get update && caelestia_sudo apt-get install -y "${MISSING[@]}" || warn "apt install failed..."
        fi
    fi
    
    if [[ "${CAELESTIA_SKIP_DEPLOY:-0}" == "0" ]]; then
        info "Configuring KDE Lock Screen to use Caelestia..."
        WALLPAPER_STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/wallpaper-plugin-installed"
        PLUGIN_OK=false
        if [[ "${CAELESTIA_WALLPAPER_PLUGIN_INSTALLED:-false}" == "true" ]]; then
            PLUGIN_OK=true
        elif command -v kpackagetool6 >/dev/null 2>&1 \
            && kpackagetool6 --list -t Plasma/Wallpaper 2>/dev/null \
            | grep -q "net.dosowisko.PlasmaApplicationWallpaper"; then
            PLUGIN_OK=true
        elif ! command -v kpackagetool6 >/dev/null 2>&1 && [[ -f "$WALLPAPER_STAMP" ]]; then
            PLUGIN_OK=true
        fi

        if $PLUGIN_OK && command -v kwriteconfig6 >/dev/null 2>&1; then
            kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin net.dosowisko.PlasmaApplicationWallpaper
            kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key command "quickshell -p $HOME/.config/quickshell/caelestia/lockscreen.qml"
            kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key fps 1
            kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key alwaysShowClock false
            kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key showMediaControls false
            ok "KDE Lock Screen configured."
        elif ! $PLUGIN_OK; then
            warn "plasma-wallpaper-application plugin not installed. Skipping KDE Lock Screen configuration."
        else
            warn "KDE config tools not found. Skipping KDE Lock Screen configuration."
        fi
    else
        info "KDE Lock Screen configuration skipped."
    fi

    info "Deleting yet-another-monochrome-icon-set for lag free update..."
    if [ -z "${SHELL_DIR-}" ]; then
        warn "SHELL_DIR is not set. Aborting deletion to prevent system damage."
        return 1 2>/dev/null || exit 1
    fi
    TARGET_DIR="$SHELL_DIR/assets/icons/yet-another-monochrome-icon-set"
    if [ -d "$TARGET_DIR" ]; then
        if ! rm -rf "$TARGET_DIR"; then
            warn "Failed to delete yet-another-monochrome-icon-set."
            return 1 2>/dev/null || exit 1
        fi
    fi

    info "Updating autostart environment variables"
    if [[ -f "$BUNDLE_DIR/scripts/10-autostart.sh" ]]; then
        bash "$BUNDLE_DIR/scripts/10-autostart.sh" || warn "10-autostart.sh failed"
    fi
fi

# UPDATER ONLY BLOCK END

info "Building Caelestia Shell..."

if [ ! -d "$SHELL_DIR" ]; then
    err "Shell directory not found at $SHELL_DIR!"
    exit 1
fi

if command -v python3 >/dev/null 2>&1 && [[ -f "$BUNDLE_DIR/.github/scripts/check_qml_deployment.py" ]]; then
    python3 "$BUNDLE_DIR/.github/scripts/check_qml_deployment.py" --source-root "$SHELL_DIR" || {
        err "QML source compatibility validation failed."
        exit 1
    }
fi

cd "$SHELL_DIR" || exit 1

info "Configuring CMake..."
prepare_build_dir build
cmake -G "$CMAKE_GENERATOR" -B build -DCMAKE_BUILD_TYPE=Release -DCAELESTIA_CACHE_DEPS=ON -DCMAKE_INSTALL_PREFIX="$HOME/.local" -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia" -DINSTALL_LIBDIR="lib/caelestia" -DINSTALL_QMLDIR="lib/qt6/qml" || {
    err "CMake configuration failed."
    exit 1
}

info "Building with $BUILD_JOBS parallel jobs..."
# Stream the build live while filtering compiler warning/note spam, and keep
# the full output in a log for diagnostics on failure.
BUILD_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/shell-build.log"
mkdir -p "$(dirname "$BUILD_LOG")"
set +e
caelestia_build cmake --build build -j"$BUILD_JOBS" -- -l "$BUILD_LOAD" 2>&1 | tee "$BUILD_LOG" | grep -vE --line-buffered 'warning:|note:'
_build_rc=${PIPESTATUS[0]}
set -e
if [[ $_build_rc -ne 0 ]]; then
    err "Build failed. Full log: $BUILD_LOG"
    show_build_errors "$BUILD_LOG"
    exit 1
fi

info "Installing to user local dir..."
if ! cmake --install build 2>&1 | tee -a "$BUILD_LOG"; then
    err "Installation failed. Full log: $BUILD_LOG"
    exit 1
fi

# The install step strips the effect, so the installed file never matches the
# built one byte for byte. Track what we last installed instead: skip the root
# install when the freshly built effect is the one already on the system and
# nothing has replaced it since.
WS_STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/workspace-tracker.installed"

ws_built_effect() {
    local built
    shopt -s nullglob globstar
    for built in kwin-effects/workspace-tracker/build/**/*.so; do
        shopt -u nullglob globstar
        printf '%s\n' "$built"
        return 0
    done
    shopt -u nullglob globstar
    return 1
}

ws_signature() {
    local built="$1" installed="$2"
    printf '%s %s\n' \
        "$(sha256sum "$built" | cut -d' ' -f1)" \
        "$(stat -c '%s:%Y' "$installed" 2>/dev/null || echo missing)"
}

ws_installed_path() {
    local base="$1" dir
    for dir in /usr/lib/qt6/plugins/kwin/effects/plugins /usr/lib64/qt6/plugins/kwin/effects/plugins; do
        [[ -f "$dir/$base" ]] && { printf '%s\n' "$dir/$base"; return 0; }
    done
    return 1
}

ws_effect_up_to_date() {
    local built installed
    built="$(ws_built_effect)" || return 1
    installed="$(ws_installed_path "$(basename "$built")")" || return 1
    [[ -f "$WS_STAMP" ]] || return 1
    [[ "$(cat "$WS_STAMP")" == "$(ws_signature "$built" "$installed")" ]]
}

ws_record_install() {
    local built installed
    built="$(ws_built_effect)" || return 0
    installed="$(ws_installed_path "$(basename "$built")")" || return 0
    mkdir -p "$(dirname "$WS_STAMP")"
    ws_signature "$built" "$installed" > "$WS_STAMP"
}

info "Building and installing workspace-tracker KWin Effect..."
prepare_build_dir kwin-effects/workspace-tracker/build
WS_INSTALLED=0
WS_RECONFIGURE=1
if cmake -G "$CMAKE_GENERATOR" -B kwin-effects/workspace-tracker/build -S kwin-effects/workspace-tracker -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >/dev/null; then
    WS_BUILD_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/workspace-tracker-build.log"
    if ! caelestia_build cmake --build kwin-effects/workspace-tracker/build -j"$BUILD_JOBS" -- -l "$BUILD_LOAD" >"$WS_BUILD_LOG" 2>&1; then
        warn "Workspace tracker build failed. Full log: $WS_BUILD_LOG"
        show_build_errors "$WS_BUILD_LOG"
    elif ws_effect_up_to_date; then
        # Installing this needs root. Skipping it when the built effect is
        # byte-identical to the installed one keeps a normal update from
        # asking for a password at all.
        info "Workspace tracker already up to date; skipping system install."
        WS_INSTALLED=1
        WS_RECONFIGURE=0
    elif ! caelestia_sudo cmake --install "$PWD/kwin-effects/workspace-tracker/build" >/dev/null; then
        warn "Workspace tracker system installation failed."
    else
        WS_INSTALLED=1
        ws_record_install
    fi
else
    warn "Workspace tracker configuration failed; skipping KWin effect build."
fi

if [[ $WS_INSTALLED -eq 1 ]]; then
    if command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file kwinrc --group Plugins --key kwin_workspace_trackerEnabled true
    fi
    # Only poke KWin when the effect actually changed - a reconfigure blanks
    # and rebuilds every effect, which is visible to the user.
    if [[ $WS_RECONFIGURE -eq 1 ]]; then
        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
        ok "Installed workspace-tracker to KDE."
    fi
fi

# Validate every generated QML module before declaring success. Checking only
# Caelestia.Config lets a partial install reach Quickshell and fail as a large
# cascade of "Type unavailable" errors.
QML_BASE="$HOME/.local/lib/qt6/qml"
QML_MODULES=(
    Caelestia
    Caelestia/Components
    Caelestia/Config
    Caelestia/Internal
    Caelestia/Models
    Caelestia/Services
    Caelestia/Blobs
    Caelestia/Images
    Caelestia/Layouts
    M3Shapes
)

for module in "${QML_MODULES[@]}"; do
    module_dir="$QML_BASE/$module"
    if [[ ! -f "$module_dir/qmldir" ]]; then
        err "Missing QML module metadata: $module_dir/qmldir"
        exit 1
    fi

    shopt -s nullglob
    plugin_files=("$module_dir"/*.so)
    shopt -u nullglob
    if [[ ${#plugin_files[@]} -eq 0 ]]; then
        err "Missing QML plugin library in $module_dir"
        exit 1
    fi
done

export QML2_IMPORT_PATH="$QML_BASE${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

# Add wrapper config to bashrc/fish
if grep -q "QML2_IMPORT_PATH" ~/.bashrc; then
    if ! grep -q "quickshell/caelestia" ~/.bashrc; then
        sed -i '/QML2_IMPORT_PATH/ s|\(.*[^"]\)\("*\)$|\1:$HOME/.config/quickshell/caelestia\2|' ~/.bashrc
    fi
else
    echo 'export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml:$HOME/.config/quickshell/caelestia"' >> ~/.bashrc
fi

if ! grep -q "CAELESTIA_LIB_DIR" ~/.bashrc; then
    echo 'export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"' >> ~/.bashrc
fi

if [ -f "$HOME/.config/fish/config.fish" ]; then
    if grep -q "QML2_IMPORT_PATH" ~/.config/fish/config.fish; then
        if ! grep -q "quickshell/caelestia" ~/.config/fish/config.fish; then
            sed -i '/QML2_IMPORT_PATH/ s|\(.*[^"]\)\("*\)$|\1:$HOME/.config/quickshell/caelestia\2|' ~/.config/fish/config.fish
        fi
    else
        echo 'set -gx QML2_IMPORT_PATH "$HOME/.local/lib/qt6/qml:$HOME/.config/quickshell/caelestia"' >> ~/.config/fish/config.fish
    fi

    if ! grep -q "CAELESTIA_LIB_DIR" ~/.config/fish/config.fish; then
        echo 'set -gx CAELESTIA_LIB_DIR "$HOME/.local/lib/caelestia"' >> ~/.config/fish/config.fish
    fi
fi

mkdir -p ~/.local/bin ~/.config/systemd/user

info "Installing Caelestia bin wrappers..."
install -m 755 "$BUNDLE_DIR/src/bin/caelestia-record" ~/.local/bin/caelestia-record
install -m 755 "$BUNDLE_DIR/src/bin/caelestia-screenshot" ~/.local/bin/caelestia-screenshot
install -m 755 "$BUNDLE_DIR/src/bin/caelestia-shell-ipc" ~/.local/bin/caelestia-shell-ipc
install -m 755 "$BUNDLE_DIR/src/bin/caelestia" ~/.local/bin/caelestia
install -m 755 "$BUNDLE_DIR/src/bin/caelestia-update" ~/.local/bin/caelestia-update
install -m 755 "$BUNDLE_DIR/src/bin/caelestia-check-updates" ~/.local/bin/caelestia-check-updates
ok "Caelestia bin wrappers installed to ~/.local/bin"


# Copying mono icon theme
DEST_DIR="$HOME/.config/quickshell/caelestia/assets/icons/yet-another-monochrome-icon-set"
TMP_DIR="${DEST_DIR}.tmp"

mkdir -p "$(dirname "$DEST_DIR")"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

if rsync -a --chmod=u+w --exclude='.git' "$BUNDLE_DIR/src/yet-another-monochrome-icon-set/" "$TMP_DIR/"; then
    rm -rf "$DEST_DIR"
    mv "$TMP_DIR" "$DEST_DIR"
    info "Yet another monochrome icon set copied successfully."
else
    rm -rf "$TMP_DIR"
    warn "Failed to copy yet-another-monochrome-icon-set."
fi

# Save current commit and branch for the update checker
mkdir -p ~/.config/quickshell/caelestia
if [ -d "$BUNDLE_DIR/.git" ]; then
    git -C "$BUNDLE_DIR" rev-parse HEAD > ~/.config/quickshell/caelestia/.current_commit 2>/dev/null || true
    git -C "$BUNDLE_DIR" rev-parse --abbrev-ref HEAD > ~/.config/quickshell/caelestia/.update_branch 2>/dev/null || true

    # Persist the installed version too. The update checker resolves
    # unrecognised commits through its bare cache repo, which only mirrors
    # origin branches - a commit that exists only in this local checkout
    # would otherwise resolve to "unknown" in the Updates page.
    if [ -f "$BUNDLE_DIR/.github/version.env" ]; then
        cp "$BUNDLE_DIR/.github/version.env" ~/.config/quickshell/caelestia/.current_version 2>/dev/null || true
    else
        git -C "$BUNDLE_DIR" show HEAD:.github/version.env > ~/.config/quickshell/caelestia/.current_version 2>/dev/null || true
    fi
fi

ok "Caelestia Shell and KDE Bridges built and installed successfully to user directory."
