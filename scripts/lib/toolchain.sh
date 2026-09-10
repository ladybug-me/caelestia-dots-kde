#!/usr/bin/env bash
# toolchain.sh - Build-tool prerequisites for the install/update step scripts.
#
# Source alongside lib/privileges.sh, which provides caelestia_sudo:
#
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/toolchain.sh"
#
#   linguist_tools_available   Is Qt's lrelease reachable?
#   install_linguist_tools     Install it through caelestia_sudo
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
