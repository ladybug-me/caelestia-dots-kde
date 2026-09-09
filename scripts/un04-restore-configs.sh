#!/usr/bin/env bash
# un04-restore-configs.sh - restore each app config dir from the selected
# backup (SELECTED_BACKUP, set by the Uninstall picker screen), or remove it
# if no backup was chosen / no per-app backup exists.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

SELECTED_BACKUP="${SELECTED_BACKUP:-}"

restore_or_remove() {
    local name="$1" target="$2" backup_subdir="$3"
    rm -rf "$target"
    if [[ -n "$SELECTED_BACKUP" ]] && [[ -e "$SELECTED_BACKUP/$backup_subdir/$name" ]]; then
        if cp -r "$SELECTED_BACKUP/$backup_subdir/$name" "$target"; then
            ok "Restored $name from backup"
        else
            warn "Failed to restore $name from backup - $target is now missing"
        fi
    else
        skip "No backup for $name - removed without restore"
    fi
}

for cfg in btop fastfetch fish foot hypr kitty micro thunar; do
    if [[ -e "$HOME/.config/$cfg" ]]; then
        restore_or_remove "$cfg" "$HOME/.config/$cfg" ".config"
    fi
done

if [[ -f "$HOME/.config/starship.toml" ]]; then
    restore_or_remove "starship.toml" "$HOME/.config/starship.toml" ".config"
fi

if [[ -f "$HOME/.config/kmixrc" ]]; then
    rm -f "$HOME/.config/kmixrc"
    ok "Removed ~/.config/kmixrc"
fi
