#!/bin/bash
LABEL="$1"
COMMAND="$2"
ICON="$3"

FILE="$HOME/.config/quickshell/caelestia/desktop_shortcuts.json"

# Create file if it doesn't exist
if [ ! -f "$FILE" ]; then
    echo "[]" > "$FILE"
fi

# Use jq to append to the JSON array
jq --arg l "$LABEL" --arg c "$COMMAND" --arg i "$ICON" '. += [{"label": $l, "command": $c, "icon": $i}]' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
