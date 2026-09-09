#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
# ==============================================================
#   Caelestia KDE Port - Uninstall shim
#
#   The uninstall logic now lives in the installer TUI's manifest-driven
#   flow (installer/uninstall-steps.json), reachable interactively from
#   the "Uninstall Caelestia" menu entry or, as here, directly via
#   `./uninstall.sh`. It's still fully interactive (sudo prompt, the
#   remove-packages toggle, backup selection) - there's no cron use case
#   for uninstalling, unlike update.sh.
# ==============================================================

set -uo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$BUNDLE_DIR/installer/caelestia-install"

if [[ ! -x "$BIN" ]]; then
    echo "[ERR]   Installer binary missing: $BIN" >&2
    echo "        Run install.sh first to build it." >&2
    exit 1
fi

# BASE_DISTRO drives un08-remove-packages.sh's package list; detect it here
# since a standalone `./uninstall.sh` run has no prior setup.sh in this
# process to have already exported it.
if [[ -z "${BASE_DISTRO:-}" ]] && [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID:-}" in
        arch|cachyos|endeavouros|manjaro|artix) BASE_DISTRO="arch" ;;
        fedora|nobara|bazzite|rhel|centos|almalinux|rocky) BASE_DISTRO="fedora" ;;
        debian|ubuntu|pop|mint|kali|raspbian|elementary|zorin|deepin|devuan) BASE_DISTRO="debian" ;;
        *)
            if echo "${ID_LIKE:-}" | grep -iq "arch"; then BASE_DISTRO="arch"
            elif echo "${ID_LIKE:-}" | grep -iq "fedora"; then BASE_DISTRO="fedora"
            elif echo "${ID_LIKE:-}" | grep -iq -E "debian|ubuntu"; then BASE_DISTRO="debian"
            else BASE_DISTRO="unknown"; fi
            ;;
    esac
fi
export BASE_DISTRO="${BASE_DISTRO:-unknown}"

exec "$BIN" --uninstall
