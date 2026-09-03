#!/bin/bash
/usr/bin/caelestia shell -k 2>/dev/null
sleep 1.3

if pgrep -x quickshell > /dev/null; then
    killall -w quickshell 2>/dev/null
fi
if pgrep -x qs > /dev/null; then
    killall -w qs 2>/dev/null
fi

# Wipe the stale Quickshell socket locks
rm -rf "${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell/"*

source /etc/profile
[ -f ~/.profile ] && source ~/.profile
[ -f ~/.bashrc ] && source ~/.bashrc
export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml:$HOME/.config/quickshell/caelestia"
export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"
export QS_NO_RELOAD_POPUP=1
export QS_DROP_EXPENSIVE_FONTS=1
export QS_DISABLE_CRASH_HANDLER=1
export QSG_RENDER_LOOP=threaded
export QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

# Start the shell without handing it (and everything it launches) a stdout that
# goes nowhere. `caelestia shell -d` daemonizes, which points stdio at
# /dev/null, and the callers of this script redirect it there anyway - so a
# restart from the UI used to undo the fix that login gets right, until the
# next login. A transient user service is immune to both: systemd connects its
# stdio to the journal regardless of what this script was started with.
if command -v caelestia-shell-ipc >/dev/null 2>&1; then
    caelestia-shell-ipc start
elif command -v systemd-run >/dev/null 2>&1; then
    QS="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null || echo /usr/bin/quickshell)"
    systemctl --user reset-failed caelestia-shell.service 2>/dev/null || true
    systemd-run --user --quiet --collect --unit=caelestia-shell \
        --description="Caelestia Shell" \
        -- "$QS" -n -p "$HOME/.config/quickshell/caelestia/shell.qml"
else
    /usr/bin/caelestia shell -d
fi
