#!/bin/bash

# Syncs Caelestia shell colors to kde-material-you-colors
# Arguments:
# 1: color (hex e.g. #ff0000)
# 2: variant (0-8)
# 3: light mode (True or False)

COLOR="$1"
VARIANT="$2"
LIGHT="$3"

CONF_DIR="$HOME/.config/kde-material-you-colors"
CONF_FILE="$CONF_DIR/config.conf"

mkdir -p "$CONF_DIR"

if [ ! -f "$CONF_FILE" ]; then
    kde-material-you-colors -c || true
fi

if [ ! -f "$CONF_FILE" ]; then
    touch "$CONF_FILE"
fi

update_or_uncomment() {
    local key="$1"
    local value="$2"
    if grep -E -q "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$CONF_FILE"; then
        sed -i -E "s/^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=.*/${key} = ${value}/" "$CONF_FILE"
    else
        echo "${key} = ${value}" >> "$CONF_FILE"
    fi
}

update_or_uncomment "color" "$COLOR"
update_or_uncomment "scheme_variant" "$VARIANT"
update_or_uncomment "light" "$LIGHT"
