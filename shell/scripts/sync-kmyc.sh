#!/bin/bash

# Syncs or modifies kde-material-you-colors configuration

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

# If the first argument is a hex color (e.g. #ff0000), use the legacy positional format
if [[ "$1" == "#"* ]]; then
    update_or_uncomment "color" "$1"
    update_or_uncomment "scheme_variant" "$2"
    update_or_uncomment "light" "$3"
    exit 0
fi

# Modern argument parsing for arbitrary key-value sets
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --set)
            if [ -n "$2" ] && [ -n "$3" ]; then
                update_or_uncomment "$2" "$3"
                shift 3
            else
                echo "Error: --set requires KEY and VALUE"
                exit 1
            fi
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done
