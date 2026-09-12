#!/bin/bash

# Restart the shell through the same systemd user service that KDE uses for
# Caelestia XDG autostart. Restarting that unit keeps the restart environment
# identical to login startup, which is the whole point of going through it.
#
# Do not replace this with the CLI's `caelestia shell -d`: that daemonises,
# which points the shell's stdio at /dev/null, and every application launched
# from the shell then inherits a stdout that goes nowhere. Vesktop deadlocks
# when a call starts in exactly that state (issue #402, reproducible with
# `vesktop >/dev/null 2>&1`).
#
# Callers: the shell's own restart actions (PluginsPage, AppearancePage,
# Toggles) and update.sh.

if command -v systemctl >/dev/null 2>&1; then
    exec systemctl --user restart app-caelestiashell@autostart.service
fi

exit 1

