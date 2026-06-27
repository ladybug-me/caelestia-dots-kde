#!/usr/bin/env bash
# 03-deploy-configs.sh — Deploy Caelestia configuration files to ~/.config

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
SRC_DIR="$BUNDLE_DIR/src"
BACKUP_DIR="$BUNDLE_DIR/backups/$(date +%Y%m%d_%H%M%S)"

echo
echo "════════════════════════════════════════"
echo "  Step 3/11 — Config Deployment"
echo "════════════════════════════════════════"

mkdir -p "$BACKUP_DIR/config" "$BACKUP_DIR/local"

echo "  Recording previous login shell..."
getent passwd "$USER" | cut -d: -f7 > "$BACKUP_DIR/previous_shell.txt"

echo "  Backing up the entire ~/.config folder..."
cp -r "$HOME/.config" "$BACKUP_DIR/" 2>/dev/null || true

echo "  Deploying Caelestia configs..."
for config in btop fastfetch fish foot hypr kitty micro thunar; do
    if [[ -d "$SRC_DIR/dots/$config" ]]; then
        # Remove ((COMMENTED OUT FOR SOME REASON))
        rm -rf "$HOME/.config/$config"
        # Deploy
        cp -r "$SRC_DIR/dots/$config" "$HOME/.config/$config"
        echo "    Deployed: $config"
    fi
done

# Deploy starship.toml
if [[ -f "$SRC_DIR/dots/starship.toml" ]]; then
    cp "$SRC_DIR/dots/starship.toml" "$HOME/.config/starship.toml"
    echo "    Deployed: starship.toml"
fi

# ── Backup Konsole ────────────────────────────────────────────────────────
echo "  Backing up Konsole config..."
# Note: konsolerc is already backed up with the entire ~/.config folder above
if [[ -d "$HOME/.local/share/konsole" ]]; then
    cp -r "$HOME/.local/share/konsole" "$BACKUP_DIR/local/" 2>/dev/null || true
fi

# ── Deploy Bridge Files ───────────────────────────────────────────────
echo "  Deploying bridge files (bin, applications, systemd, kwin script)..."
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
echo "  [OK]  Bridge files deployed."

echo "[OK]  Config deployment complete."
