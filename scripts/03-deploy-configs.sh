#!/usr/bin/env bash
# 03-deploy-configs.sh - Deploy Caelestia configuration files to ~/.config

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BUNDLE_DIR/scripts/00-ui.sh"
SRC_DIR="$BUNDLE_DIR/src"
BACKUP_DIR="$BUNDLE_DIR/backups/$(date +%Y%m%d_%H%M%S)"

ui_section "Step 3/11 - Config Deployment"

mkdir -p "$BACKUP_DIR/config" "$BACKUP_DIR/local"

ui_info "Recording previous login shell..."
getent passwd "$USER" | cut -d: -f7 > "$BACKUP_DIR/previous_shell.txt"

ui_info "Backing up the entire ~/.config folder..."
cp -r "$HOME/.config" "$BACKUP_DIR/" 2>/dev/null || true

ui_info "Deploying Caelestia configs..."
for config in btop fastfetch fish foot hypr kitty micro thunar; do
    if [[ -d "$SRC_DIR/dots/$config" ]]; then
        rm -rf "$HOME/.config/$config"
        cp -r "$SRC_DIR/dots/$config" "$HOME/.config/$config"
        ui_ok "Deployed: $config"
    fi
done

# Deploy starship.toml
if [[ -f "$SRC_DIR/dots/starship.toml" ]]; then
    cp "$SRC_DIR/dots/starship.toml" "$HOME/.config/starship.toml"
    ui_ok "Deployed: starship.toml"
fi

ui_info "Backing up Konsole config..."
if [[ -d "$HOME/.local/share/konsole" ]]; then
    cp -r "$HOME/.local/share/konsole" "$BACKUP_DIR/local/" 2>/dev/null || true
fi

ui_info "Deploying bridge files (bin, applications, systemd, kwin script)..."
mkdir -p \
    "$HOME/.local/bin" \
    "$HOME/.local/share/applications" \
    "$HOME/.config/systemd/user" \
    "$HOME/.local/share/kwin/scripts"

# bin scripts
if [[ -d "$SRC_DIR/bin" ]]; then
    cp "$SRC_DIR/bin/"* "$HOME/.local/bin/" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/hyprctl" \
              "$HOME/.local/bin/kcolorpicker" \
              "$HOME/.local/bin/qs-kwin-bridge.py" 2>/dev/null || true
fi

# systemd user service
if [[ -f "$SRC_DIR/systemd/qs-kwin-bridge.service" ]] && \
   [[ -s "$SRC_DIR/systemd/qs-kwin-bridge.service" ]]; then
    cp "$SRC_DIR/systemd/qs-kwin-bridge.service" \
       "$HOME/.config/systemd/user/"
fi

# KWin script
if [[ -d "$SRC_DIR/kwin/quickshell-kde-bridge" ]]; then
    cp -r "$SRC_DIR/kwin/quickshell-kde-bridge" \
          "$HOME/.local/share/kwin/scripts/"
fi

# Update desktop database
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
ui_ok "Bridge files deployed."

ui_ok "Config deployment complete."
