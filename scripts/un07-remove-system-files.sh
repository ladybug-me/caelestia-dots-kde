#!/usr/bin/env bash
# un07-remove-system-files.sh - remove system-level files the installer
# added (keyd config, udev rule, ccache flag, sudoers, symlinks, kwin effect).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

if [[ -f /etc/keyd/quickshell.conf ]]; then
    sudo rm -f /etc/keyd/quickshell.conf
    ok "Removed /etc/keyd/quickshell.conf"
    sudo rmdir /etc/keyd 2>/dev/null || true
fi

if [[ -f /etc/udev/rules.d/80-uinput.rules ]]; then
    sudo rm -f /etc/udev/rules.d/80-uinput.rules
    sudo udevadm control --reload-rules 2>/dev/null || true
    ok "Removed udev rule: 80-uinput.rules"
fi

CCACHE_FLAG="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/ccache-enabled"
if [[ -f "$CCACHE_FLAG" ]] && [[ -f /etc/makepkg.conf ]]; then
    if sudo sed -i 's/\(^\|[[:space:]]\)ccache\([[:space:]]\|$\)/\1!ccache\2/' /etc/makepkg.conf; then
        rm -f "$CCACHE_FLAG"
        ok "Reverted ccache in /etc/makepkg.conf"
    else
        warn "Could not revert ccache in /etc/makepkg.conf; retaining ownership marker."
    fi
fi

if [[ -f /etc/sudoers.d/ydotoold-nopasswd ]]; then
    sudo rm -f /etc/sudoers.d/ydotoold-nopasswd
    ok "Removed sudoers rule: ydotoold-nopasswd"
fi

for link in /usr/local/bin/sass /usr/local/bin/qdbus6 /usr/local/bin/caelestia /usr/local/bin/wl-clip-persist /usr/local/bin/gpu-screen-recorder; do
    if [[ -L "$link" || -f "$link" ]]; then
        sudo rm -f "$link"
        ok "Removed: $link"
    fi
done

for effect_lib in /usr/lib/qt6/plugins/kwin/effects/plugins/kwin_workspace_tracker.so /usr/lib64/qt6/plugins/kwin/effects/plugins/kwin_workspace_tracker.so; do
    if [[ -f "$effect_lib" ]]; then
        sudo rm -f "$effect_lib"
        ok "Removed system KWin effect: $effect_lib"
    fi
done

if [[ -f "$HOME/.cargo/bin/satty" ]]; then
    rm -f "$HOME/.cargo/bin/satty"
    ok "Removed: satty (cargo)"
fi

if groups "$USER" | grep -q '\binput\b'; then
    sudo gpasswd -d "$USER" input 2>/dev/null || \
        warn "Could not remove $USER from input group. Run: sudo gpasswd -d $USER input"
    ok "Removed $USER from 'input' group (takes effect on next login)"
fi
