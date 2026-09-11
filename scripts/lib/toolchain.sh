#!/usr/bin/env bash
# toolchain.sh - Build-tool prerequisites for the install/update step scripts.
#
# Source alongside lib/privileges.sh, which provides caelestia_sudo:
#
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/toolchain.sh"
#
#   linguist_tools_available   Is Qt's lrelease reachable?
#   install_linguist_tools     Install it through caelestia_sudo
#   install_cava_sdk           Download & extract prebuilt CAVA SDK tarball
#
# These helpers never log; callers decide what to tell the user.

# linguist_tools_available
#
# True when `lrelease` can be run, either from PATH or from the location
# distros use when they keep the Qt tools out of PATH.
linguist_tools_available() {
    local fallback="${CAELESTIA_LRELEASE_FALLBACK:-/usr/lib/qt6/bin/lrelease}"

    command -v lrelease >/dev/null 2>&1 || [[ -x "$fallback" ]]
}

# install_linguist_tools
#
# Install Qt's Linguist tools so CMake can compile the translation catalogues.
# Without lrelease CMake only warns and the shell ships English regardless of
# the catalogues in shell/translations.
#
# Privileged package calls go through caelestia_sudo rather than plain sudo:
# this step also runs from a GUI-triggered update with no controlling terminal,
# where a bare sudo has nothing to prompt on and fails silently (#664).
# caelestia_sudo falls back through cached credentials, SUDO_PASS, an askpass
# helper and finally pkexec.
#
# Returns 0 when the tools are already present or were installed, 1 otherwise.
install_linguist_tools() {
    if linguist_tools_available; then
        return 0
    fi

    if command -v pacman >/dev/null 2>&1; then
        caelestia_sudo pacman -S --needed --noconfirm qt6-tools
    elif command -v dnf >/dev/null 2>&1; then
        caelestia_sudo dnf install -y qt6-qttools-devel
    elif command -v apt-get >/dev/null 2>&1; then
        caelestia_sudo apt-get install -y qt6-l10n-tools qt6-tools-dev
    else
        return 1
    fi
}

# install_cava_sdk [distro]
#
# Download and extract the prebuilt CAVA SDK (libcava + headers) from the CAVA
# continuous release so the shell can link against it without building from source.
#
# Distro can be explicitly passed (e.g. arch, fedora, debian/ubuntu) or defaults
# to $BASE_DISTRO / detected package manager.
#
# Returns 0 on success, 1 on failure.
install_cava_sdk() {
    local arch="${CAELESTIA_TARGET_ARCH:-}"
    if [[ -z "$arch" ]]; then
        arch="$(uname -m 2>/dev/null || echo "x86_64")"
    fi

    local distro="${1:-${BASE_DISTRO:-}}"
    if [[ -z "$distro" ]]; then
        if command -v pacman >/dev/null 2>&1; then
            distro="arch"
        elif command -v dnf >/dev/null 2>&1; then
            distro="fedora"
        elif command -v apt-get >/dev/null 2>&1; then
            distro="ubuntu"
        fi
    fi

    local asset_suffix
    case "$distro" in
        arch) asset_suffix="arch" ;;
        fedora) asset_suffix="fedora" ;;
        debian|ubuntu) asset_suffix="ubuntu" ;;
        *) return 1 ;;
    esac

    local url="https://github.com/ladybug-me/cava/releases/download/continuous/cava-${arch}-${asset_suffix}.tar.gz"
    local tar_cmd=(tar -C /usr -xzf - --exclude='bin')
    if [[ "$EUID" -ne 0 ]]; then
        if command -v caelestia_sudo >/dev/null 2>&1; then
            tar_cmd=(caelestia_sudo "${tar_cmd[@]}")
        elif command -v sudo >/dev/null 2>&1; then
            tar_cmd=(sudo "${tar_cmd[@]}")
        fi
    fi

    curl -fsSL "$url" | "${tar_cmd[@]}" 2>/dev/null
}
