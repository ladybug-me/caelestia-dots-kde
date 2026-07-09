#!/usr/bin/env bash
# 03-deploy-configs.sh  Deploy Caelestia configuration files to ~/.config

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
SRC_DIR="$BUNDLE_DIR/src"
DOTS_DIR="$SRC_DIR/dots"
FISH_DIR="$SRC_DIR/dots-extra"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
BACKUP_DIR_FILE="$CACHE_DIR/backup-dir.txt"
BACKUP_DIR=""

if [[ -f "$BACKUP_DIR_FILE" ]]; then
    BACKUP_DIR="$(cat "$BACKUP_DIR_FILE" 2>/dev/null || true)"
fi

# Only reuse the cached backup dir if it belongs to *this* bundle's backups and matches the timestamp format.
if [[ -n "$BACKUP_DIR" ]]; then
    case "$BACKUP_DIR" in
        "$BUNDLE_DIR/backups/"[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]) ;; 
        *) BACKUP_DIR="" ;; 
    esac
fi

if [[ -n "$BACKUP_DIR" ]] && [[ ! -d "$BACKUP_DIR" ]]; then
    BACKUP_DIR=""
fi

if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$BUNDLE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
fi

echo
echo ""
echo "  Step 3/11  Config Deployment"
echo ""

mkdir -p "$BACKUP_DIR"

if [[ ! -d "$DOTS_DIR/fish" && ! -d "$DOTS_DIR/hypr" ]]; then
    echo "  [ERR] Missing src/dots content. Run: git submodule update --init --recursive src/dots"
    exit 1
fi

echo "  Recording previous login shell..."
getent passwd "$USER" | cut -d: -f7 > "$BACKUP_DIR/previous_shell.txt"

echo "  Backing up pre-install configs..."
mkdir -p "$BACKUP_DIR/shellrc" "$BACKUP_DIR/.config" "$BACKUP_DIR/local"

# Backup selected config dirs that may be overwritten/removed during install/uninstall
for cfg in btop fastfetch fish foot hypr kitty micro thunar; do
    if [[ -e "$HOME/.config/$cfg" ]]; then
        cp -a "$HOME/.config/$cfg" "$BACKUP_DIR/.config/$cfg" 2>/dev/null || true
    fi
done

# Backup Konsole config/profiles (system tweaks may modify these)
if [[ -f "$HOME/.config/konsolerc" ]]; then
    cp -a "$HOME/.config/konsolerc" "$BACKUP_DIR/.config/konsolerc" 2>/dev/null || true
fi
if [[ -d "$HOME/.local/share/konsole" ]]; then
    cp -a "$HOME/.local/share/konsole" "$BACKUP_DIR/local/konsole" 2>/dev/null || true
fi

backup_shell_rc() {
    local src="$1"
    local key="$2"
    if [[ -f "$src" ]]; then
        cp "$src" "$BACKUP_DIR/shellrc/$key"
        printf 'present\n' > "$BACKUP_DIR/shellrc/$key.state"
    else
        printf 'missing\n' > "$BACKUP_DIR/shellrc/$key.state"
    fi
}

backup_shell_rc "$HOME/.bashrc" "bashrc"
backup_shell_rc "$HOME/.zshrc" "zshrc"
backup_shell_rc "$HOME/.config/fish/config.fish" "fish_config"

echo "  Deploying Caelestia configs..."
for config in btop fastfetch foot hypr kitty micro thunar; do
    if [[ -d "$DOTS_DIR/$config" ]]; then
        # Remove
        rm -rf "$HOME/.config/$config"
        # Deploy
        cp -r "$DOTS_DIR/$config" "$HOME/.config/$config"
        echo "    Deployed: $config"
    fi
done

echo "  Deploying extra configs..."
if [[ -d "$FISH_DIR/fish" ]]; then
    # Remove
    rm -rf "$HOME/.config/fish"
    # Deploy
    cp -r "$FISH_DIR/fish" "$HOME/.config/fish"
    echo "    Deployed: fish"
fi

# Backup existing starship config
if [[ -f "$HOME/.config/starship.toml" ]]; then
    mkdir -p "$BACKUP_DIR/.config"
    cp "$HOME/.config/starship.toml" "$BACKUP_DIR/.config/starship.toml"
fi

# Deploy starship.toml
if [[ -f "$DOTS_DIR/starship.toml" ]]; then
    mkdir -p "$HOME/.config"
    cp "$DOTS_DIR/starship.toml" "$HOME/.config/starship.toml"
    echo "    Deployed: starship.toml"
fi

#  Deploy Bridge Files 
echo "  Deploying bridge files (bin, applications, systemd, kwin script)..."
mkdir -p \
    "$HOME/.local/bin" \
    "$HOME/.local/share/applications" \
    "$HOME/.config/systemd/user" \
    "$HOME/.local/share/kwin/scripts"

# bin scripts
if [[ -d "$SRC_DIR/bin" ]]; then
    # Copy scripts, but skip C++ source files and build files
    for file in "$SRC_DIR/bin/"*; do
        if [[ ! "$file" == *.cpp && ! "$file" == *CMakeLists.txt && ! -d "$file" ]]; then
            cp "$file" "$HOME/.local/bin/" 2>/dev/null || true
        fi
    done
    
    chmod +x "$HOME/.local/bin/kcolorpicker" \
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
