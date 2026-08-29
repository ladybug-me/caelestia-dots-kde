#!/usr/bin/env bash
# privileges.sh - Shared privilege escalation helpers.
#
# Pairs with lib/log.sh; source both from a step script:
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/privileges.sh"
#
# Sourced by the updater and the install steps so a single credential prompt
# covers the whole run, including GUI launches with no controlling terminal.
#
#   caelestia_prime_sudo   Obtain credentials once and keep them warm
#   caelestia_sudo         Run a command as root, reusing those credentials
#   caelestia_sudo_quiet   Same, but never prompts (returns 1 instead)
#
# Guard against double-sourcing: the updater sources this and then runs step
# scripts that source it again. Written as an if so a false test never trips
# `set -e` in the sourcing script.
if [[ -z "${CAELESTIA_PRIVILEGES_SOURCED:-}" ]]; then
CAELESTIA_PRIVILEGES_SOURCED=1

# The installer TUI puts a wrapper on PATH that rewrites every sudo call to
# `sudo -A` against its own askpass helper. That is right for the step scripts
# it drives, but it defeats the -n probe and the -S password feed used below,
# so those go straight to the real binary.
caelestia_real_sudo() {
    if [[ -x /usr/bin/sudo ]]; then
        /usr/bin/sudo "$@"
    else
        sudo "$@"
    fi
}

# First askpass helper found, used when there is no terminal to prompt on.
caelestia_find_askpass() {
    local helper
    for helper in ksshaskpass /usr/lib/ssh/ksshaskpass /usr/libexec/ksshaskpass \
        lxqt-openssh-askpass x11-ssh-askpass ssh-askpass; do
        if command -v "$helper" >/dev/null 2>&1; then
            command -v "$helper"
            return 0
        fi
    done
    return 1
}

# Obtain root credentials once, then refresh the timestamp in the background so
# no child ever has to ask again - even across a long build. Seeding sudo's own
# timestamp (rather than escalating per command) is what keeps a GUI-launched
# update down to a single prompt.
caelestia_prime_sudo() {
    if [[ "$EUID" -eq 0 || -n "${CAELESTIA_SUDO_PRIMED:-}" ]]; then
        return 0
    fi

    if caelestia_real_sudo -n true 2>/dev/null; then
        : # already cached
    elif [[ -n "${SUDO_PASS:-}" ]]; then
        printf '%s\n' "$SUDO_PASS" | caelestia_real_sudo -S -p '' -v || return 1
    elif [[ -t 0 ]]; then
        caelestia_real_sudo -v || return 1
    else
        local askpass
        if askpass="$(caelestia_find_askpass)"; then
            export SUDO_ASKPASS="$askpass"
            caelestia_real_sudo -A -v || return 1
        elif command -v pkexec >/dev/null 2>&1; then
            # No askpass helper: fall back to escalating each command through
            # pkexec. Nothing to prime, so leave the flag unset.
            return 0
        else
            return 1
        fi
    fi

    export CAELESTIA_SUDO_PRIMED=1

    # Refresh with -n so it extends the timestamp without ever re-prompting.
    (
        while kill -0 "$$" 2>/dev/null; do
            sleep 30
            caelestia_real_sudo -nv 2>/dev/null || true
        done
    ) &
    CAELESTIA_SUDO_KEEPALIVE_PID=$!
    export CAELESTIA_SUDO_KEEPALIVE_PID
    return 0
}

caelestia_stop_sudo_keepalive() {
    if [[ -n "${CAELESTIA_SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$CAELESTIA_SUDO_KEEPALIVE_PID" 2>/dev/null; then
        kill "$CAELESTIA_SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}

# Escalation is lazy on purpose: a routine update usually has no root work left
# to do, and asking for a password it never uses is the main thing that made
# updates feel like a password interrogation. The first command that really
# needs root primes the credentials, and everything after it rides along.
caelestia_sudo() {
    if [[ "$EUID" -ne 0 ]] && ! caelestia_real_sudo -n true 2>/dev/null; then
        caelestia_prime_sudo || true
    fi

    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    elif caelestia_real_sudo -n true 2>/dev/null; then
        caelestia_real_sudo -n "$@"
    elif [[ -n "${SUDO_PASS:-}" ]]; then
        printf '%s\n' "$SUDO_PASS" | caelestia_real_sudo -S -p '' "$@"
    elif [[ -t 0 ]]; then
        caelestia_real_sudo "$@"
    elif [[ -n "${SUDO_ASKPASS:-}" ]]; then
        caelestia_real_sudo -A "$@"
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec "$@"
    else
        if declare -F err >/dev/null; then
            err "Cannot elevate privileges. Install ksshaskpass or pkexec, or run from a terminal."
        else
            echo "  [ERR]   Cannot elevate privileges." >&2
        fi
        return 1
    fi
}

# Root work that must never interrupt the user: it takes cached credentials or
# the password the installer exported, and simply fails otherwise. Feeding the
# password avoids -n, which would refuse before the password is even read.
caelestia_sudo_quiet() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    elif [[ -n "${SUDO_PASS:-}" ]]; then
        printf '%s\n' "$SUDO_PASS" | caelestia_real_sudo -S -p '' "$@"
    else
        caelestia_real_sudo -n "$@"
    fi
}

fi # CAELESTIA_PRIVILEGES_SOURCED
