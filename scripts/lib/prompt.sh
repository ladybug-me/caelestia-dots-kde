#!/usr/bin/env bash
# ==============================================================
#   Caelestia interactive prompt helpers
#
#   Prefer charmbracelet gum for the styled, keyboard-driven prompt
#   experience; fall back to plain read/select so prompts still work
#   before gum is installed (fresh bootstrap, or a standalone update /
#   uninstall on a system that has not yet installed Caelestia).
#
#   Source from any script that prompts the user:
#       source "$(dirname "${BASH_SOURCE[0]}")/lib/prompt.sh"
# ==============================================================

if [[ -n "${CAELESTIA_PROMPT_LOADED:-}" ]]; then
    return 0
fi
CAELESTIA_PROMPT_LOADED=1

_has_gum() { command -v gum >/dev/null 2>&1; }

# confirm_no <message> - yes/no defaulting to no. Exit 0 on yes.
confirm_no() {
    local msg="$1"
    if _has_gum; then
        gum confirm --default=no "$msg"
    else
        local ans
        read -r -p "$msg [y/N]: " ans
        [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
    fi
}

# confirm_yes <message> - yes/no defaulting to yes. Exit 0 on yes.
confirm_yes() {
    local msg="$1"
    if _has_gum; then
        gum confirm --default=yes "$msg"
    else
        local ans
        read -r -p "$msg [Y/n]: " ans
        ans="${ans:-y}"
        [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
    fi
}

# choose <header> <option...> - print the selected option. Exit non-zero on
# cancel. Options with spaces are supported.
choose() {
    local header="$1"
    shift
    if _has_gum; then
        gum choose --header "$header" "$@"
    else
        local PS3="$header "
        local sel
        select sel in "$@"; do
            if [[ -n "$sel" ]]; then
                printf '%s\n' "$sel"
                return 0
            fi
            printf 'Please enter a valid number.\n'
        done
        return 1
    fi
}
