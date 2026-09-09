#!/usr/bin/env bash
# un06-revert-shell-rc.sh - restore shell rc files (or the login shell) from
# backup, falling back to stripping the Caelestia env-var lines it added.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

SELECTED_BACKUP="${SELECTED_BACKUP:-}"
SHELL_RC_RESTORED="false"

restore_shell_rc() {
    local key="$1" target="$2"
    local state_file="$SELECTED_BACKUP/shellrc/$key.state"
    local backup_file="$SELECTED_BACKUP/shellrc/$key"
    [[ -f "$state_file" ]] || return 1
    local state
    state="$(cat "$state_file" 2>/dev/null || true)"
    case "$state" in
        present)
            mkdir -p "$(dirname "$target")"
            if [[ -f "$backup_file" ]]; then
                cp "$backup_file" "$target"
                ok "Restored $target from backup"
                return 0
            fi
            ;;
        missing)
            rm -f "$target"
            ok "Removed $target (it did not exist before install)"
            return 0
            ;;
    esac
    return 1
}

if [[ -n "$SELECTED_BACKUP" ]]; then
    restore_shell_rc "bashrc" "$HOME/.bashrc" && SHELL_RC_RESTORED="true"
    restore_shell_rc "zshrc" "$HOME/.zshrc" && SHELL_RC_RESTORED="true"
    restore_shell_rc "fish_config" "$HOME/.config/fish/config.fish" && SHELL_RC_RESTORED="true"
fi

_RESTORE_SHELL=""
if [[ -n "$SELECTED_BACKUP" ]] && [[ -f "$SELECTED_BACKUP/previous_shell.txt" ]]; then
    _PREV_SHELL="$(cat "$SELECTED_BACKUP/previous_shell.txt")"
    if grep -x -q "$_PREV_SHELL" /etc/shells 2>/dev/null; then
        _RESTORE_SHELL="$_PREV_SHELL"
    else
        warn "Previous shell ($_PREV_SHELL) is not listed in /etc/shells. Falling back to bash."
    fi
fi

if [[ -z "$_RESTORE_SHELL" ]]; then
    if command -v bash >/dev/null 2>&1; then
        _RESTORE_SHELL="$(command -v bash)"
    else
        _RESTORE_SHELL="/bin/bash"
    fi
fi

sudo chsh -s "$_RESTORE_SHELL" "$USER" 2>/dev/null || \
    warn "Could not change login shell to $_RESTORE_SHELL. Run: chsh -s $_RESTORE_SHELL"
ok "Login shell reverted to $_RESTORE_SHELL"

if [[ "$SHELL_RC_RESTORED" == "true" ]]; then
    info "Skipped shell rc line cleanup because original rc files were restored exactly from backup."
else
    if [[ -f "$HOME/.bashrc" ]]; then
        sed -i '/export QML2_IMPORT_PATH=.*caelestia\|export CAELESTIA_LIB_DIR=/d' "$HOME/.bashrc" 2>/dev/null || true
        ok "Removed Caelestia env vars from ~/.bashrc"
    fi
    if [[ -f "$HOME/.config/fish/config.fish" ]]; then
        sed -i '/QML2_IMPORT_PATH\|CAELESTIA_LIB_DIR/d' "$HOME/.config/fish/config.fish" 2>/dev/null || true
        ok "Removed Caelestia env vars from fish config"
    fi
    if [[ -f "$HOME/.zshrc" ]]; then
        sed -i '/QML2_IMPORT_PATH\|CAELESTIA_LIB_DIR/d' "$HOME/.zshrc" 2>/dev/null || true
        ok "Removed Caelestia env vars from ~/.zshrc"
    fi
fi
