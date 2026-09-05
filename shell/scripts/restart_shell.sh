#!/bin/bash

# Restart the same systemd user service that KDE uses for Caelestia
# XDG autostart. This keeps the restart environment identical to login startup.

if command -v systemctl >/dev/null 2>&1; then
    exec systemctl --user restart app-caelestiashell@autostart.service
fi

exit 1

