#!/usr/bin/env bash
# 03-deploy-configs.sh  Deploy Caelestia configuration files to ~/.config

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
SRC_DIR="$BUNDLE_DIR/src"
DOTS_DIR="$SRC_DIR/dots"
FISH_DIR="$SRC_DIR/dots-extra"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
DEPLOYED_DIR="$CACHE_DIR/deployed"
BACKUP_DIR_FILE="$CACHE_DIR/backup-dir.txt"
if [[ -z "${BACKUP_DIR:-}" ]]; then
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
fi

echo
echo ""
info "Deploying configuration files"
echo ""

mkdir -p "$BACKUP_DIR"
mkdir -p "$DEPLOYED_DIR"

if [[ ! -d "$DOTS_DIR" ]] || [[ -z "$(ls -A "$DOTS_DIR" 2>/dev/null)" ]]; then
    die "Missing src/dots content. Run: git submodule update --init --recursive src/dots"
fi

info "Recording previous login shell..."
getent passwd "$USER" | cut -d: -f7 > "$BACKUP_DIR/previous_shell.txt"

info "Backing up pre-install configs..."
mkdir -p "$BACKUP_DIR/shellrc" "$BACKUP_DIR/.config" "$BACKUP_DIR/local"

# Backup selected config dirs that may be overwritten/removed during install/uninstall
for cfg in btop fastfetch fish foot kitty micro thunar; do
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

config_checksum() {
    local path="$1"

    if [[ ! -e "$path" ]]; then
        printf 'missing\n'
        return
    fi

    if [[ -d "$path" ]]; then
        (
            cd "$path"
            find . -type f -print0 | sort -z | while IFS= read -r -d '' file; do
                sha256sum "$file"
            done
        ) | sha256sum | awk '{print $1}'
    else
        sha256sum "$path" | awk '{print $1}'
    fi
}

deploy_config() {
    local config="$1"
    local source="$2"
    local target="$HOME/.config/$config"
    local stamp="$DEPLOYED_DIR/$config.sha256"

    if [[ ! -d "$source" ]]; then
        return
    fi

    if [[ -e "$target" ]]; then
        local current expected
        current="$(config_checksum "$target")"
        expected=""
        if [[ -f "$stamp" ]]; then
            expected="$(<"$stamp")"
        fi

        if [[ -z "$expected" || "$current" != "$expected" ]]; then
            skip "Preserving locally modified config: $config"
            echo "           Backup: $BACKUP_DIR/.config/$config"
            return
        fi
    fi

    rm -rf "$target"
    cp -a "$source" "$target"
    config_checksum "$target" > "$stamp"
    echo "    Deployed: $config"
}

info "Deploying Caelestia configs..."
for config in btop fastfetch foot kitty micro; do
    deploy_config "$config" "$DOTS_DIR/$config"
done

if [[ "${INSTALL_THUNAR:-false}" == "true" ]]; then
    thunar_source="$DOTS_DIR/thunar"
    thunar_target="$HOME/.config/thunar"
    if [[ -d "$thunar_source" ]]; then
        mkdir -p "$thunar_target"
        for file in thunar-volman.xml uca.xml; do
            if [[ -f "$thunar_source/$file" ]]; then
                cp "$thunar_source/$file" "$thunar_target/$file"
                echo "    Deployed: thunar/$file"
            else
                warn "Missing optional Thunar file: thunar/$file"
            fi
        done
    else
        warn "Thunar integration files unavailable in src/dots/thunar"
    fi
else
    skip "Thunar integration files disabled by user choice"
fi

info "Deploying extra configs..."
for config in fish fastfetch; do
    if [[ "$config" == "fish" && "${INSTALL_FISH:-true}" != "true" ]]; then
        skip "fish config deployment disabled by user choice"
        continue
    fi

    deploy_config "$config" "$FISH_DIR/$config"
done

# Backup existing starship config
if [[ -f "$HOME/.config/starship.toml" ]]; then
    mkdir -p "$BACKUP_DIR/.config"
    cp "$HOME/.config/starship.toml" "$BACKUP_DIR/.config/starship.toml"
fi

# Deploy starship.toml unless the previous Caelestia copy was locally edited.
if [[ -f "$DOTS_DIR/starship.toml" ]]; then
    mkdir -p "$HOME/.config"
    starship_target="$HOME/.config/starship.toml"
    starship_stamp="$DEPLOYED_DIR/starship.toml.sha256"
    if [[ -e "$starship_target" ]]; then
        starship_current="$(config_checksum "$starship_target")"
        starship_expected=""
        if [[ -f "$starship_stamp" ]]; then
            starship_expected="$(<"$starship_stamp")"
        fi
        if [[ -z "$starship_expected" || "$starship_current" != "$starship_expected" ]]; then
            skip "Preserving locally modified config: starship.toml"
            echo "           Backup: $BACKUP_DIR/.config/starship.toml"
        else
            cp "$DOTS_DIR/starship.toml" "$starship_target"
            config_checksum "$starship_target" > "$starship_stamp"
            echo "    Deployed: starship.toml"
        fi
    else
        cp "$DOTS_DIR/starship.toml" "$starship_target"
        config_checksum "$starship_target" > "$starship_stamp"
        echo "    Deployed: starship.toml"
    fi
fi

#  Deploy Bridge Files 
info "Deploying bridge files (bin, applications, systemd, kwin script)..."
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
            cp --remove-destination "$file" "$HOME/.local/bin/" 2>/dev/null || true
        fi
    done
fi

# Update desktop database
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
ok "Bridge files deployed."

if [[ "${APPLY_LOCKSCREEN:-true}" != "false" ]]; then
    info "Configuring KDE Lock Screen to use Caelestia..."
    WALLPAPER_STAMP="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/wallpaper-plugin-installed"
    PLUGIN_OK=false
    if [[ "${CAELESTIA_WALLPAPER_PLUGIN_INSTALLED:-false}" == "true" ]]; then
        PLUGIN_OK=true
    elif command -v kpackagetool6 >/dev/null 2>&1 \
        && kpackagetool6 --list -t Plasma/Wallpaper 2>/dev/null \
        | grep -q "net.dosowisko.PlasmaApplicationWallpaper"; then
        PLUGIN_OK=true
    elif ! command -v kpackagetool6 >/dev/null 2>&1 && [[ -f "$WALLPAPER_STAMP" ]]; then
        PLUGIN_OK=true
    fi

    if $PLUGIN_OK && command -v kwriteconfig6 >/dev/null 2>&1; then
        kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin net.dosowisko.PlasmaApplicationWallpaper
        kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key command "quickshell -p $HOME/.config/quickshell/caelestia/lockscreen.qml"
        kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group net.dosowisko.PlasmaApplicationWallpaper --group General --key fps 1
        kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key alwaysShowClock false
        kwriteconfig6 --file kscreenlockerrc --group Greeter --group LnF --group General --key showMediaControls false
        ok "KDE Lock Screen configured."
    elif ! $PLUGIN_OK; then
        warn "plasma-wallpaper-application plugin not installed. Skipping KDE Lock Screen configuration."
    else
        warn "KDE config tools not found. Skipping KDE Lock Screen configuration."
    fi
else
    skip "KDE Lock Screen configuration disabled by user choice."
fi

ok "Config deployment complete."
