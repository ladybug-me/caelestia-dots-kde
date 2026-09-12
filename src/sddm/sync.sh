#!/usr/bin/env bash
set -euo pipefail

user_path_exists() {
    sudo -H -u "$REAL_USER" test -e "$1" || sudo -H -u "$REAL_USER" test -L "$1"
}

copy_user_file() {
    local src="$1"
    local dest="$2"
    local max_bytes="$3"

    local dest_dir base read_tmp dest_tmp actual_size
    dest_dir="$(dirname -- "$dest")"
    base="$(basename -- "$dest")"

    install -d -o root -g root -m 0755 "$dest_dir"

    read_tmp="$(mktemp)"
    dest_tmp="$(mktemp "$dest_dir/.${base}.tmp.XXXXXX")"

    fail_cleanup() {
        rm -f -- "$read_tmp" "$dest_tmp"
        return 1
    }

    if ! sudo -H -u "$REAL_USER" test -f "$src" || \
        ! sudo -H -u "$REAL_USER" test -r "$src"; then
        fail_cleanup
        return
    fi

    if ! sudo -H -u "$REAL_USER" head -c "$((max_bytes + 1))" -- "$src" | cat > "$read_tmp"; then
        fail_cleanup
        return
    fi

    actual_size="$(stat -c '%s' "$read_tmp")"

    if [[ "$actual_size" -gt "$max_bytes" ]]; then
        echo "WARNING: Skipping oversized file: $src" >&2
        fail_cleanup
        return
    fi

    if ! install -o root -g root -m 0644 "$read_tmp" "$dest_tmp"; then
        fail_cleanup
        return
    fi

    if ! mv -f -- "$dest_tmp" "$dest"; then
        fail_cleanup
        return
    fi

    rm -f -- "$read_tmp"
    return 0
}

sync_optional_user_file() {
    local src="$1"
    local dest="$2"
    local max_bytes="$3"
    local label="$4"

    if copy_user_file "$src" "$dest" "$max_bytes"; then
        echo "✓ Synced $label"
    else
        rm -f -- "$dest"

        if user_path_exists "$src"; then
            echo "WARNING: Skipping unreadable or invalid $label: $src" >&2
        fi
    fi
}

if [[ -n "${SUDO_USER:-}" ]]; then
    REAL_USER="$SUDO_USER"
else
    echo "ERROR: Cannot determine target user. Try running with sudo." >&2
    exit 1
fi

REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
if [[ -z "$REAL_HOME" ]] || [[ "$REAL_HOME" = "/" ]]; then
    echo "ERROR: Could not determine a valid home directory for $REAL_USER." >&2
    exit 1
fi

CAEL_STATE="$REAL_HOME/.local/state/caelestia"
THEME_DIR="/usr/share/sddm/themes/caelestia"

# 1. Generate FRESH colors from the current Caelestia scheme settings FIRST
if [[ "${1:-}" = "--posthook" ]]; then
    : # Skip color generation when run as posthook (--posthook)
    echo "✓ Running as posthook, skipping color generation"
elif command -v caelestia &>/dev/null; then
    mapfile -t SCHEME < <(sudo -H -u "$REAL_USER" caelestia scheme get --name --mode --variant 2>/dev/null)
    NAME="${SCHEME[0]:-}"
    MODE="${SCHEME[1]:-}"
    VARIANT="${SCHEME[2]:-}"
    if [[ -n "$NAME" ]] && [[ -n "$MODE" ]] && [[ -n "$VARIANT" ]]; then
        sudo -H -u "$REAL_USER" caelestia scheme set --name "$NAME" --mode "$MODE" --variant "$VARIANT" 2>/dev/null
        echo "✓ Generated colors for scheme: $NAME/$MODE/$VARIANT"
    else
        echo "Could not read Caelestia scheme, skipping color generation"
    fi
else
    echo "Caelestia CLI not found, skipping color generation"
fi

# 2. Sync avatar files into theme assets so sddm can safely access them without permission issues.
sync_optional_user_file \
    "$REAL_HOME/.face.icon" \
    "$THEME_DIR/assets/avatar.face.icon" \
    "$((5 * 1024 * 1024))" \
    "avatar.face.icon"

sync_optional_user_file \
    "$REAL_HOME/.face" \
    "$THEME_DIR/assets/avatar.face" \
    "$((5 * 1024 * 1024))" \
    "avatar.face"

# 3. Sync Colors
THEME_CONF_SRC="$CAEL_STATE/theme/sddm-theme.conf"
THEME_CONF_DEST="$THEME_DIR/theme.conf"
MAX_THEME_CONF_BYTES=$((1024 * 1024))

if copy_user_file "$THEME_CONF_SRC" "$THEME_CONF_DEST" "$MAX_THEME_CONF_BYTES"; then
    sys_os="Linux"
    if [[ -f /etc/os-release ]]; then
        sys_os=$(grep -oP '^PRETTY_NAME="\K[^"]+' /etc/os-release || grep -oP '^PRETTY_NAME=\K.+' /etc/os-release || echo "Linux")
    fi
    sys_host=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "localhost")

    sys_os_escaped=$(printf '%s' "$sys_os" | sed 's/[\/&]/\\&/g')
    sys_host_escaped=$(printf '%s' "$sys_host" | sed 's/[\/&]/\\&/g')

    sed -i "s/^os=.*/os=$sys_os_escaped/" "$THEME_CONF_DEST"
    sed -i "s/^host=.*/host=$sys_host_escaped/" "$THEME_CONF_DEST"

    chmod 644 "$THEME_CONF_DEST"
    echo "✓ Synced theme.conf"
else
    echo "No theme.conf found, leaving existing theme.conf unchanged."
fi

# 4. Sync Wallpaper LAST
WALLPAPER_SRC="$CAEL_STATE/wallpaper/current"
MAX_WALLPAPER_BYTES=$((50 * 1024 * 1024))
MAX_VIDEO_WALLPAPER_BYTES=$((250 * 1024 * 1024))
WALLPAPER_DEST="$THEME_DIR/assets/background"

if command -v file >/dev/null 2>&1; then
    WALLPAPER_MIME="$(sudo -H -u "$REAL_USER" file -b --mime-type -L "$WALLPAPER_SRC" 2>/dev/null || true)"
    case "$WALLPAPER_MIME" in
        video/webm)       WALLPAPER_DEST="$THEME_DIR/assets/background.webm" ;;
        video/x-matroska) WALLPAPER_DEST="$THEME_DIR/assets/background.mkv" ;;
        video/quicktime)  WALLPAPER_DEST="$THEME_DIR/assets/background.mov" ;;
        video/x-msvideo)  WALLPAPER_DEST="$THEME_DIR/assets/background.avi" ;;
        video/*)
            WALLPAPER_TARGET="$(sudo -H -u "$REAL_USER" readlink -f "$WALLPAPER_SRC" 2>/dev/null || true)"
            TARGET_EXT="$(printf '%s' "${WALLPAPER_TARGET##*.}" | tr '[:upper:]' '[:lower:]')"
            case "$TARGET_EXT" in
                mp4|m4v|webm|mkv|mov|avi) WALLPAPER_DEST="$THEME_DIR/assets/background.$TARGET_EXT" ;;
                *)                        WALLPAPER_DEST="$THEME_DIR/assets/background.mp4" ;;
            esac
            ;;
    esac
fi

MAX_BYTES="$MAX_WALLPAPER_BYTES"
case "$WALLPAPER_DEST" in
    *.mp4|*.m4v|*.webm|*.mkv|*.mov|*.avi) MAX_BYTES="$MAX_VIDEO_WALLPAPER_BYTES" ;;
esac

if copy_user_file "$WALLPAPER_SRC" "$WALLPAPER_DEST" "$MAX_BYTES"; then
    for old in "$THEME_DIR/assets/background" "$THEME_DIR/assets/background."*; do
        if [[ -e "$old" ]] && [[ "$old" != "$WALLPAPER_DEST" ]]; then
            rm -f -- "$old"
        fi
    done
    echo "✓ Synced background"
else
    echo "No readable wallpaper found, leaving existing background unchanged."
fi
