#!/usr/bin/env bash
# un01-remove-units.sh - remove leftover systemd unit files and the shell
# autostart entry.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

USER_SYSTEMD="$HOME/.config/systemd/user"

for svc_file in \
    "$USER_SYSTEMD/qs-kwin-bridge.service" \
    "$USER_SYSTEMD/cliphist.service" \
    "$USER_SYSTEMD/ydotoold.service" \
    "$USER_SYSTEMD/kde-material-you-colors.service" \
    "$USER_SYSTEMD/caelestia-update-checker.service" \
    "$USER_SYSTEMD/caelestia-update-checker.timer"
do
    if [[ -f "$svc_file" ]]; then
        rm -f "$svc_file"
        ok "Removed: $svc_file"
    fi
done

if [[ -f "$HOME/.config/autostart/caelestiashell.desktop" ]]; then
    rm -f "$HOME/.config/autostart/caelestiashell.desktop"
    ok "Removed autostart entry: caelestiashell.desktop"
fi

systemctl --user daemon-reload 2>/dev/null || true
ok "Service files cleaned up."
