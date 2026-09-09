#!/usr/bin/env bash
# un00-stop-services.sh - stop/disable Caelestia's user+system services and
# kill any running shell process.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

for svc in qs-kwin-bridge cliphist ydotoold kde-material-you-colors; do
    if systemctl --user is-enabled --quiet "${svc}.service" 2>/dev/null ||
       systemctl --user is-active  --quiet "${svc}.service" 2>/dev/null; then
        systemctl --user disable --now "${svc}.service" 2>/dev/null || true
        ok "Disabled user service: $svc"
    else
        skip "User service not active: $svc"
    fi
done

if systemctl --user is-enabled --quiet "caelestia-update-checker.timer" 2>/dev/null ||
   systemctl --user is-active  --quiet "caelestia-update-checker.timer" 2>/dev/null; then
    systemctl --user disable --now "caelestia-update-checker.timer" 2>/dev/null || true
    systemctl --user disable --now "caelestia-update-checker.service" 2>/dev/null || true
    ok "Disabled user timer: caelestia-update-checker"
fi

if systemctl is-enabled --quiet keyd 2>/dev/null ||
   systemctl is-active  --quiet keyd 2>/dev/null; then
    sudo systemctl disable --now keyd 2>/dev/null || true
    ok "Disabled system service: keyd"
else
    skip "keyd not active"
fi

pkill -f "caelestia shell" 2>/dev/null || true
pkill -f "quickshell"      2>/dev/null || true
ok "Stopped any running shell processes"
