#!/usr/bin/env bash
# 00-backup-themes.sh — Backs up current KDE theme settings so uninstall.sh can restore them.

echo "  Backing up current KDE theme configurations..."

BACKUP_FILE="$HOME/.config/caelestia-theme-backup.conf"

# Remove old backup if it exists
rm -f "$BACKUP_FILE"

# Function to read config and append to backup file
backup_config() {
    local file="$1"
    local group="$2"
    local key="$3"
    
    local val=""
    if command -v kreadconfig6 >/dev/null 2>&1; then
        val=$(kreadconfig6 --file "$file" --group "$group" --key "$key" 2>/dev/null)
    fi
    
    if [ -n "$val" ]; then
        local b64_val=$(echo -n "$val" | base64 -w 0)
        echo "${file}|${group}|${key}=${b64_val}" >> "$BACKUP_FILE"
    fi
}

backup_config "plasmarc" "Theme" "name"
backup_config "kdeglobals" "KDE" "widgetStyle"
backup_config "kdeglobals" "General" "ColorScheme"
backup_config "kwinrc" "org.kde.kdecoration2" "library"
backup_config "kwinrc" "org.kde.kdecoration2" "theme"
backup_config "kcminputrc" "Mouse" "cursorTheme"

echo "  [OK]  KDE theme settings backed up to $BACKUP_FILE"
