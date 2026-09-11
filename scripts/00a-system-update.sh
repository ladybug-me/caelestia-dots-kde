#!/usr/bin/env bash
# 00a-system-update.sh - System update script

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

if [[ "${SKIP_SYSTEM_UPDATE:-false}" == "true" ]]; then
    info "Skipping full system update (SKIP_SYSTEM_UPDATE=true)."
    exit 0
fi

# A rolling upgrade that replaces these pulls the libraries out from under the
# session that is already running: the live KWin/Plasma keeps the old ones in
# memory until the session ends, while 08-build-shell.sh compiles the Caelestia
# plugin against the new headers on disk and 06-services.sh loads the KWin
# bridge into that same old process. That is the partial-upgrade state Arch
# warns about, and it surfaces later as Wayland protocol/ABI errors that look
# like a broken build rather than a stale session (issue #627).
#
# Only checked on Arch: it is the rolling distro where this happens routinely,
# and `pacman -Q` is the version query that exists there. Fedora and Debian
# installs do not get this guard.
SESSION_PACKAGES=(kwin plasma-workspace libplasma qt6-base qt6-declarative)

session_package_versions() {
    local pkg
    for pkg in "${SESSION_PACKAGES[@]}"; do
        pacman -Q "$pkg" 2>/dev/null || printf '%s not-installed\n' "$pkg"
    done
}

# Identity of the running KWin: its PID and start time in clock ticks. Both
# change when the session is restarted, which is the only thing that makes a
# stale-session verdict stop applying. No running KWin (a TTY install, another
# desktop) means there is no session to invalidate, so the guard stands down.
kwin_session_identity() {
    local pid
    pid="$(pgrep -x kwin_wayland 2>/dev/null | head -n1 || true)"
    [[ -n "$pid" ]] || pid="$(pgrep -x kwin_x11 2>/dev/null | head -n1 || true)"
    [[ -n "$pid" ]] || return 1
    # Field 22 of /proc/<pid>/stat is the process start time in clock ticks.
    printf '%s %s\n' "$pid" "$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || echo '?')"
}

STALE_SESSION_STAMP="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-kde/stale-session"

# A flagged session stays flagged. "Retry" on the failure prompt re-runs this
# step, and by then the upgrade it applied is no longer a difference to detect,
# so the verdict is remembered against the session that produced it.
if [[ -f "$STALE_SESSION_STAMP" ]]; then
    if [[ "$(cat "$STALE_SESSION_STAMP" 2>/dev/null)" == "$(kwin_session_identity 2>/dev/null)" ]]; then
        err "This Plasma session still predates the last KWin/Qt upgrade. Log out and"
        err "back in (or reboot), then run the installer again."
        exit 1
    fi
    rm -f "$STALE_SESSION_STAMP"
fi

if [[ "${BASE_DISTRO:-unknown}" == "arch" ]]; then
    versions_before="$(session_package_versions)"
    if [[ -n "${CONFIRM_ARG:-}" ]]; then
        sudo pacman -Syu --noconfirm
    else
        sudo pacman -Syu
    fi

    if [[ "$(session_package_versions)" != "$versions_before" ]]; then
        err "The upgrade replaced packages the running session still has loaded in memory:"
        diff <(printf '%s\n' "$versions_before") <(session_package_versions) \
            | grep -E '^[<>]' | sed 's/^</  [ERR]   had /; s/^>/  [ERR]   now /' >&2 || true
        err "Building and loading the Caelestia KWin plugin now would link against the new"
        err "libraries while the live KWin still runs the old ones, which fails later with"
        err "errors that look unrelated to this upgrade."
        err "Exit the installer, log out and back in (or reboot), then run it again - the"
        err "upgrade is already applied, so the re-run goes straight to the rest."
        if identity="$(kwin_session_identity 2>/dev/null)" && [[ -n "$identity" ]]; then
            mkdir -p "$(dirname "$STALE_SESSION_STAMP")"
            printf '%s\n' "$identity" > "$STALE_SESSION_STAMP"
        fi
        exit 1
    fi
elif [[ "${BASE_DISTRO:-unknown}" == "fedora" ]]; then
    if [[ -n "${CONFIRM_ARG:-}" ]]; then
        sudo dnf upgrade --refresh -y
    else
        sudo dnf upgrade --refresh
    fi
elif [[ "${BASE_DISTRO:-unknown}" == "debian" ]]; then
    if [[ -n "${CONFIRM_ARG:-}" ]]; then
        sudo apt-get update && sudo apt-get upgrade -y
    else
        sudo apt-get update && sudo apt-get upgrade
    fi
else
    warn "Distro not set properly, skipping system update."
fi
