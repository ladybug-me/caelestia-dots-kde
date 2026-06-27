#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║        Caelestia KDE Port — Uninstaller                      ║
# ║                                                              ║
# ║  Reverses every action performed by setup.sh.                ║
# ║  Restores backups where they exist; removes files that       ║
# ║  have no prior version to restore.                           ║
# ╚══════════════════════════════════════════════════════════════╝

set -uo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
RST="\033[0m"
BOLD="\033[1m"
PURPLE="\033[38;5;135m"
BLUE="\033[38;5;75m"
CYAN="\033[38;5;87m"
PINK="\033[38;5;213m"
GREEN="\033[38;5;84m"
RED="\033[38;5;196m"
YELLOW="\033[38;5;220m"
DIM="\033[2m"

die()  { echo -e "${RED} ☄️  [FATAL] $*${RST}" >&2; exit 1; }
info() { echo -e "${BLUE} 🔭 [INFO]  $*${RST}"; }
ok()   { echo -e "${GREEN} ✨ [OK]    $*${RST}"; }
warn() { echo -e "${YELLOW} ⚠️  [WARN]  $*${RST}"; }
skip() { echo -e "${DIM} 💨 [SKIP]  $*${RST}"; }

# ── OS detection ───────────────────────────────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        arch|cachyos|endeavouros|manjaro|artix) BASE_DISTRO="arch" ;;
        fedora|nobara|bazzite|rhel|centos|almalinux|rocky) BASE_DISTRO="fedora" ;;
        *)
            if echo "${ID_LIKE:-}" | grep -iq "arch"; then BASE_DISTRO="arch"
            elif echo "${ID_LIKE:-}" | grep -iq "fedora"; then BASE_DISTRO="fedora"
            else BASE_DISTRO="unknown"; fi
            ;;
    esac
else
    BASE_DISTRO="unknown"
fi

if [[ "$BASE_DISTRO" == "unknown" ]]; then
    echo -e "${YELLOW}Could not detect distribution. Select base:${RST}"
    echo "  1) Arch-based   2) Fedora-based   3) Exit"
    read -r -p "Choice [1-3]: " _dc
    case "$_dc" in
        1) BASE_DISTRO="arch" ;;
        2) BASE_DISTRO="fedora" ;;
        *) die "Exiting." ;;
    esac
fi

# ── Banner ─────────────────────────────────────────────────────────────────────
echo -e "${PURPLE}${BOLD}"
cat << 'EOF'
 ✧･ﾟ: *✧･ﾟ:*  Caelestia KDE Port  *:･ﾟ✧*:･ﾟ✧
EOF
echo -ne "${BLUE}"
cat << 'EOF'
     __  __       _           __        ____
    / / / /____  (_)___  ____/ /_____ _/ / /
   / / / / __ \ / / __ \/ ___/ __/ __ `/ / /
  / /_/ / / / // / / / (__  ) /_/ /_/ / / /
  \____/_/ /_//_/_/ /_/____/\__/\__,_/_/_/

EOF
echo -e "${RST}"
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${RST}"
echo -e "${CYAN}║${RST}  ${BOLD}${PURPLE}🌌 Caelestia Uninstaller${RST}                                        ${CYAN}║${RST}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${RST}"
echo
echo -e " ${YELLOW}⚠️  This will remove the Caelestia KDE shell and config files.${RST}"
echo -e " ${BLUE}🔭 Backups (in $BUNDLE_DIR/backups/) will be offered for restoration.${RST}"
echo

# ── Sudo setup ─────────────────────────────────────────────────────────────────
while true; do
    IFS= read -s -p "Enter your sudo password: " SUDO_PASS; echo
    sudo -k
    if printf '%s\n' "$SUDO_PASS" | sudo -S -v &>/dev/null; then break
    else echo -e "${RED}Incorrect password, try again.${RST}"; fi
done
export SUDO_PASS

# Keepalive loop
(while true; do printf '%s\n' "$SUDO_PASS" | sudo -S -v; sleep 55; done) 2>/dev/null &
_SUDO_LOOP=$!
trap 'kill $_SUDO_LOOP 2>/dev/null; true' EXIT

# ── Confirmation ───────────────────────────────────────────────────────────────
echo
echo -e "${RED}Are you sure you want to uninstall Caelestia KDE? [y/N]:${RST} "
read -r _confirm
[[ "${_confirm,,}" == "y" || "${_confirm,,}" == "yes" ]] || die "Uninstall cancelled."

echo
echo -e "${YELLOW}Remove installed packages as well? This will uninstall${RST}"
echo -e "${YELLOW}tools like fish, foot, btop, fastfetch, and others.${RST}"
echo -e "Remove packages? [y/N]: "
read -r _remove_pkgs
REMOVE_PACKAGES=false
[[ "${_remove_pkgs,,}" == "y" || "${_remove_pkgs,,}" == "yes" ]] && REMOVE_PACKAGES=true

# ── Backup Selection ───────────────────────────────────────────────────────────
SELECTED_BACKUP=""
if [[ -d "$BUNDLE_DIR/backups" ]]; then
    mapfile -t backups < <(ls -dt "$BUNDLE_DIR"/backups/[0-9]*_[0-9]* 2>/dev/null)
    if [[ ${#backups[@]} -gt 0 ]]; then
        echo
        echo -e "${CYAN}Available backups to restore from:${RST}"
        for i in "${!backups[@]}"; do
            bname="$(basename "${backups[$i]}")"
            formatted_date=$(echo "$bname" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
            
            tag=""
            if [[ -f "${backups[$i]}/config/quickshell/caelestia/shell.qml" ]]; then
                if diff -qr "${backups[$i]}/config/quickshell/caelestia" "$BUNDLE_DIR/src/dots/quickshell/caelestia" >/dev/null 2>&1; then
                    tag="${CYAN} [Caelestia]${RST}"
                else
                    tag="${YELLOW} [Caelestia (Modified)]${RST}"
                fi
            fi
            
            if [[ -f "${backups[$i]}/previous_shell.txt" ]]; then
                prev_shell="$(cat "${backups[$i]}/previous_shell.txt")"
                prev_shell_name="$(basename "$prev_shell")"
                tag="${tag}${CYAN} [Shell: ${prev_shell_name}]${RST}"
            fi
            
            echo -e "  $((i+1))) $formatted_date$tag"
        done
        echo "  0) None (Do not restore from backup)"
        
        while true; do
            read -r -p "Select a backup to restore [1]: " _bsel
            _bsel="${_bsel:-1}"
            if [[ "$_bsel" == "0" ]]; then
                SELECTED_BACKUP=""
                break
            elif [[ "$_bsel" -ge 1 ]] && [[ "$_bsel" -le "${#backups[@]}" ]]; then
                SELECTED_BACKUP="${backups[$((_bsel-1))]}"
                if [[ -f "$SELECTED_BACKUP/config/quickshell/caelestia/shell.qml" ]]; then
                    echo
                    warn "The selected backup contains Caelestia configurations."
                    echo -e "${YELLOW} ⚠️  Restoring this backup will NOT revert to a clean KDE desktop!${RST}"
                    echo -e "${YELLOW}    Instead, it will restore a previous Caelestia state.${RST}"
                    read -r -p "Are you sure you want to restore this backup? [y/N]: " _cwarn
                    if [[ "${_cwarn,,}" != "y" && "${_cwarn,,}" != "yes" ]]; then
                        echo -e "${DIM} 💨 Backup selection cancelled. Please select again.${RST}"
                        continue
                    fi
                fi
                break
            else
                echo -e "${RED}Invalid selection.${RST}"
            fi
        done
    fi
fi

# ── Helper: restore a config dir/file from backup ─────────────────────────────
restore_or_remove() {
    local name="$1"           # e.g. "fish"
    local target="$2"         # full destination path
    local backup_subdir="$3"  # "config" or "local"
    local backup_dir="$SELECTED_BACKUP"

    rm -rf "$target"

    if [[ -n "$backup_dir" ]] && [[ -e "$backup_dir/$backup_subdir/$name" ]]; then
        cp -r "$backup_dir/$backup_subdir/$name" "$target"
        ok "Restored $name from backup"
    else
        skip "No backup for $name — removed without restore"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Stop and disable all services
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 1 — Stop & disable services${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

for svc in qs-kwin-bridge cliphist ydotoold kde-material-you-colors; do
    if systemctl --user is-enabled --quiet "${svc}.service" 2>/dev/null ||
       systemctl --user is-active  --quiet "${svc}.service" 2>/dev/null; then
        systemctl --user disable --now "${svc}.service" 2>/dev/null || true
        ok "Disabled user service: $svc"
    else
        skip "User service not active: $svc"
    fi
done

# Stop and disable keyd (system service)
if systemctl is-enabled --quiet keyd 2>/dev/null ||
   systemctl is-active  --quiet keyd 2>/dev/null; then
    printf '%s\n' "$SUDO_PASS" | sudo -S systemctl disable --now keyd 2>/dev/null || true
    ok "Disabled system service: keyd"
else
    skip "keyd not active"
fi

# Kill any running Caelestia / Quickshell processes
pkill -f "caelestia shell" 2>/dev/null || true
pkill -f "quickshell"      2>/dev/null || true
ok "Stopped any running shell processes"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — Remove service files
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 2 — Remove service & autostart files${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

USER_SYSTEMD="$HOME/.config/systemd/user"

for svc_file in \
    "$USER_SYSTEMD/qs-kwin-bridge.service" \
    "$USER_SYSTEMD/cliphist.service" \
    "$USER_SYSTEMD/ydotoold.service" \
    "$USER_SYSTEMD/kde-material-you-colors.service"
do
    if [[ -f "$svc_file" ]]; then
        rm -f "$svc_file"
        ok "Removed: $svc_file"
    fi
done

# Autostart desktop entry
if [[ -f "$HOME/.config/autostart/caelestiashell.desktop" ]]; then
    rm -f "$HOME/.config/autostart/caelestiashell.desktop"
    ok "Removed autostart entry: caelestiashell.desktop"
fi

systemctl --user daemon-reload 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — Remove installed shell files
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 3 — Remove shell installation${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

# Quickshell config (QML files)
if [[ -d "$HOME/.config/quickshell/caelestia" ]]; then
    rm -rf "$HOME/.config/quickshell/caelestia"
    ok "Removed ~/.config/quickshell/caelestia"
fi

# Native plugin library
if [[ -d "$HOME/.local/lib/caelestia" ]]; then
    rm -rf "$HOME/.local/lib/caelestia"
    ok "Removed ~/.local/lib/caelestia"
fi

# QML module tree (remove only caelestia-specific entries to be safe)
for qml_mod in Caelestia M3Shapes; do
    if [[ -d "$HOME/.local/lib/qt6/qml/$qml_mod" ]]; then
        rm -rf "$HOME/.local/lib/qt6/qml/$qml_mod"
        ok "Removed QML module: $qml_mod"
    fi
done

# Legacy share path
if [[ -d "$HOME/.local/share/caelestia-shell" ]]; then
    rm -rf "$HOME/.local/share/caelestia-shell"
    ok "Removed ~/.local/share/caelestia-shell"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — Remove bridge scripts from ~/.local/bin
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 4 — Remove bridge scripts${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

for f in \
    "$HOME/.local/bin/hyprctl" \
    "$HOME/.local/bin/kcolorpicker" \
    "$HOME/.local/bin/qs-kwin-bridge.py" \
    "$HOME/.local/bin/caelestia-shortcuts" \
    "$HOME/.local/bin/caelestia-record" \
    "$HOME/.local/bin/ydotoold-wrapper"
do
    if [[ -f "$f" ]]; then
        rm -f "$f"
        ok "Removed: $f"
    fi
done

# KWin bridge script
if [[ -d "$HOME/.local/share/kwin/scripts/quickshell-kde-bridge" ]]; then
    rm -rf "$HOME/.local/share/kwin/scripts/quickshell-kde-bridge"
    ok "Removed KWin script: quickshell-kde-bridge"
fi

# Desktop entries deployed from src/keyboardshortcuts/applications/
if [[ -d "$BUNDLE_DIR/src/keyboardshortcuts/applications" ]]; then
    for df in "$BUNDLE_DIR/src/keyboardshortcuts/applications/"*.desktop; do
        [[ -f "$df" ]] || continue
        target="$HOME/.local/share/applications/$(basename "$df")"
        if [[ -f "$target" ]]; then
            rm -f "$target"
            ok "Removed desktop entry: $(basename "$target")"
        fi
    done
    update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5 — Restore / remove config directories
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 5 — Restore / remove config directories${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

for cfg in btop fastfetch fish foot hypr kitty micro nvim rofi thunar uwsm zed zen vscode; do
    if [[ -e "$HOME/.config/$cfg" ]]; then
        restore_or_remove "$cfg" "$HOME/.config/$cfg" "config"
    fi
done

# starship.toml
if [[ -f "$HOME/.config/starship.toml" ]]; then
    restore_or_remove "starship.toml" "$HOME/.config/starship.toml" "config"
fi

# kmixrc (written fresh by installer — just remove it)
if [[ -f "$HOME/.config/kmixrc" ]]; then
    rm -f "$HOME/.config/kmixrc"
    ok "Removed ~/.config/kmixrc"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6 — Revert KDE settings
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 6 — Revert KDE settings${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

# Re-enable KDE OSDs
kwriteconfig6 --file plasmarc         --group "OSD"              --key "Enabled"            "true"  2>/dev/null || true
kwriteconfig6 --file plasmarc         --group "OSD"              --key "ShowOnActiveScreen"  "true"  2>/dev/null || true
kwriteconfig6 --file kdeglobals       --group "KDE"              --key "OSDEnabled"          "true"  2>/dev/null || true
kwriteconfig6 --file plasmanotifyrc   --group "Notifications"    --key "LoudnessChangedOSD" "true"  2>/dev/null || true
kwriteconfig6 --file powerdevilrc     --group "BrightnessControl"--key "showOSD"            "true"  2>/dev/null || true
kwriteconfig6 --file powerdevilrc     --group "AC"               --key "brightnessosd"       "true"  2>/dev/null || true
ok "Re-enabled KDE OSD notifications"

# ── Restore KDE Theme Settings ──────────────────────────────────────────────────
if [[ -n "$SELECTED_BACKUP" ]]; then
    info "Restoring core KDE configuration files from backup..."
    for kde_cfg in kdeglobals ksplashrc plasmarc kwinrc kcminputrc plasma-org.kde.plasma.desktop-appletsrc; do
        if [[ -f "$SELECTED_BACKUP/config/$kde_cfg" ]]; then
            cp "$SELECTED_BACKUP/config/$kde_cfg" "$HOME/.config/$kde_cfg"
        fi
    done
    ok "Restored core KDE configuration files (including wallpaper and splash)."
else
    BACKUP_FILE="$HOME/.config/caelestia-theme-backup.conf"
    if [[ -f "$BACKUP_FILE" ]]; then
        info "Restoring KDE themes from $BACKUP_FILE..."
        while IFS='=' read -r key val; do
            if [[ -n "$key" && -n "$val" ]]; then
                cfg_file=$(echo "$key" | cut -d'|' -f1)
                cfg_group=$(echo "$key" | cut -d'|' -f2)
                cfg_key=$(echo "$key" | cut -d'|' -f3)
                cfg_decoded_val=$(echo "$val" | base64 -d)
                kwriteconfig6 --file "$cfg_file" --group "$cfg_group" --key "$cfg_key" "$cfg_decoded_val" 2>/dev/null || true
            fi
        done < "$BACKUP_FILE"
        ok "Restored previous KDE theme settings."
    else
        info "No theme backup found. Reverting to default Breeze theme..."
        kwriteconfig6 --file plasmarc --group "Theme" --key "name" "default"  2>/dev/null || true
        kwriteconfig6 --file kdeglobals --group "KDE"     --key "widgetStyle"  "Breeze" 2>/dev/null || true
        kwriteconfig6 --file kdeglobals --group "General" --key "ColorScheme"  "BreezeLight" 2>/dev/null || true
        kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "library" "org.kde.breeze" 2>/dev/null || true
        kwriteconfig6 --file kwinrc --group "org.kde.kdecoration2" --key "theme"   "@breeze"        2>/dev/null || true
        kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "breeze_cursors" 2>/dev/null || true
        ok "Reset KDE theme settings to Breeze."
    fi
fi

# Disable Caelestia KWin plugins
kwriteconfig6 --file kwinrc --group "Plugins" --key "quickshell-kde-bridgeEnabled" "false" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "Plugins" --key "poloniumEnabled"              "false" 2>/dev/null || true
ok "Disabled KWin plugins: quickshell-kde-bridge, polonium"

# Restore desktop count to 1 (KDE default)
kwriteconfig6 --file kwinrc --group "Desktops" --key "Number" "1" 2>/dev/null || true
kwriteconfig6 --file kwinrc --group "Desktops" --key "Rows"   "1" 2>/dev/null || true
for i in $(seq 1 5); do
    kwriteconfig6 --file kwinrc --group "Desktops" --key "Name_$i" "Desktop $i" 2>/dev/null || true
done
ok "Restored desktop count to 1"

# Remove workspace shortcuts added by the installer
for i in $(seq 1 5); do
    kwriteconfig6 --file kglobalshortcutsrc --group "kwin" \
        --key "Switch to Desktop $i"  "none,none,Switch to Desktop $i"          2>/dev/null || true
    kwriteconfig6 --file kglobalshortcutsrc --group "kwin" \
        --key "Window to Desktop $i"  "none,none,Move Window to Desktop $i"     2>/dev/null || true
done
ok "Cleared installer workspace shortcuts from kglobalshortcutsrc"

# Restore backed-up kglobalshortcutsrc if available
_bk_dir="$SELECTED_BACKUP"
if [[ -n "$_bk_dir" ]] && [[ -f "$_bk_dir/config/kglobalshortcutsrc" ]]; then
    cp "$_bk_dir/config/kglobalshortcutsrc" "$HOME/.config/kglobalshortcutsrc"
    ok "Restored kglobalshortcutsrc from backup"
elif ls "$BUNDLE_DIR/backups/kglobalshortcutsrc_"* >/dev/null 2>&1; then
    _bk_file="$(ls -t "$BUNDLE_DIR/backups/kglobalshortcutsrc_"* 2>/dev/null | head -1)"
    if [[ -f "$_bk_file" ]]; then
        cp "$_bk_file" "$HOME/.config/kglobalshortcutsrc"
        ok "Restored kglobalshortcutsrc from $( basename "$_bk_file")"
    fi
fi

# Clean up generated Konsole profiles
rm -f "$HOME/.local/share/konsole/MaterialYou.colorscheme"
rm -f "$HOME/.local/share/konsole/MaterialYouAlt.colorscheme"
rm -f "$HOME/.local/share/konsole/TempMyou.profile"
rm -f "$HOME/.local/share/color-schemes/MaterialYou"*.colors
ok "Removed Konsole profiles generated by Caelestia"

# Restore Konsole config if backed up
if [[ -n "$_bk_dir" ]]; then
    if [[ -f "$_bk_dir/config/konsolerc" ]]; then
        cp "$_bk_dir/config/konsolerc" "$HOME/.config/konsolerc"
        ok "Restored konsolerc from backup"
    fi
    if [[ -d "$_bk_dir/local/konsole" ]]; then
        rm -rf "$HOME/.local/share/konsole"
        cp -r  "$_bk_dir/local/konsole" "$HOME/.local/share/konsole"
        ok "Restored ~/.local/share/konsole from backup"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7 — Revert shell changes
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 7 — Revert shell changes${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

# Revert login shell
_RESTORE_SHELL=""
if [[ -n "$SELECTED_BACKUP" ]] && [[ -f "$SELECTED_BACKUP/previous_shell.txt" ]]; then
    _PREV_SHELL="$(cat "$SELECTED_BACKUP/previous_shell.txt")"
    if grep -x -q "$_PREV_SHELL" /etc/shells 2>/dev/null; then
        _RESTORE_SHELL="$_PREV_SHELL"
    else
        warn "Previous shell ($_PREV_SHELL) is not listed in /etc/shells. Falling back to bash."
    fi
fi

if [[ -z "$_RESTORE_SHELL" ]]; then
    if command -v bash >/dev/null 2>&1; then
        _RESTORE_SHELL="$(command -v bash)"
    else
        _RESTORE_SHELL="/bin/bash"
    fi
fi

if [[ -n "$_RESTORE_SHELL" ]]; then
    printf '%s\n' "$SUDO_PASS" | sudo -S chsh -s "$_RESTORE_SHELL" "$USER" 2>/dev/null || \
        warn "Could not change login shell to $_RESTORE_SHELL. Run: chsh -s $_RESTORE_SHELL"
    ok "Login shell reverted to $_RESTORE_SHELL"
fi

# Remove env var lines appended to ~/.bashrc by the installer
if [[ -f "$HOME/.bashrc" ]]; then
    sed -i '/export QML2_IMPORT_PATH=.*caelestia\|export CAELESTIA_LIB_DIR=/d' "$HOME/.bashrc" 2>/dev/null || true
    ok "Removed Caelestia env vars from ~/.bashrc"
fi

# Remove env var lines appended to fish config
if [[ -f "$HOME/.config/fish/config.fish" ]]; then
    sed -i '/QML2_IMPORT_PATH\|CAELESTIA_LIB_DIR/d' "$HOME/.config/fish/config.fish" 2>/dev/null || true
    ok "Removed Caelestia env vars from fish config"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8 — Remove system-level files (keyd, udev, sudoers, symlinks)
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 8 — Remove system-level files${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

# keyd config
if [[ -f /etc/keyd/quickshell.conf ]]; then
    printf '%s\n' "$SUDO_PASS" | sudo -S rm -f /etc/keyd/quickshell.conf
    ok "Removed /etc/keyd/quickshell.conf"
    # Remove the directory only if it's now empty
    printf '%s\n' "$SUDO_PASS" | sudo -S rmdir /etc/keyd 2>/dev/null || true
fi

# udev rule for uinput
if [[ -f /etc/udev/rules.d/80-uinput.rules ]]; then
    printf '%s\n' "$SUDO_PASS" | sudo -S rm -f /etc/udev/rules.d/80-uinput.rules
    printf '%s\n' "$SUDO_PASS" | sudo -S udevadm control --reload-rules 2>/dev/null || true
    ok "Removed udev rule: 80-uinput.rules"
fi

# sudoers file for ydotoold
if [[ -f /etc/sudoers.d/ydotoold-nopasswd ]]; then
    printf '%s\n' "$SUDO_PASS" | sudo -S rm -f /etc/sudoers.d/ydotoold-nopasswd
    ok "Removed sudoers rule: ydotoold-nopasswd"
fi

# Compatibility symlinks
for link in /usr/local/bin/sass /usr/local/bin/qdbus6 /usr/local/bin/caelestia; do
    if [[ -L "$link" ]]; then
        printf '%s\n' "$SUDO_PASS" | sudo -S rm -f "$link"
        ok "Removed symlink: $link"
    fi
done

# Remove the user from the 'input' group if it was added by the installer
if groups "$USER" | grep -q '\binput\b'; then
    printf '%s\n' "$SUDO_PASS" | sudo -S gpasswd -d "$USER" input 2>/dev/null || \
        warn "Could not remove $USER from input group. Run: sudo gpasswd -d $USER input"
    ok "Removed $USER from 'input' group (takes effect on next login)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 9 — Remove packages (optional)
# ══════════════════════════════════════════════════════════════════════════════
if [[ "$REMOVE_PACKAGES" == "true" ]]; then
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
    echo -e "${CYAN}  Step 9 — Remove packages${RST}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

    ARCH_PACKAGES=(
        caelestia-cli quickshell-git
        cmake ninja
        wl-clipboard cliphist inotify-tools app2unit wireplumber trash-cli
        jq aubio lm_sensors libcava libqalculate
        foot fish eza fastfetch starship btop
        adw-gtk-theme papirus-icon-theme
        ttf-jetbrains-mono-nerd ttf-material-symbols-variable
        ttf-rubik-vf ttf-cascadia-code-nerd darkly
        swappy brightnessctl ddcutil imagemagick
        tesseract tesseract-data-eng satty spectacle sassc
        kvantum kvantum-qt5 kde-material-you-colors
        keyd
    )

    FEDORA_PACKAGES=(
        quickshell-git caelestia-cli
        cmake ninja-build
        wl-clipboard cliphist inotify-tools app2unit wireplumber trash-cli
        jq aubio lm_sensors lm_sensors-devel libcava libcava-devel libqalculate libqalculate-devel
        foot fish eza fastfetch starship btop
        adw-gtk3-theme google-rubik-fonts papirus-icon-theme
        swappy brightnessctl ddcutil imagemagick
        tesseract tesseract-langpack-eng spectacle
        fuzzel satty slurp grim sassc
        ffmpeg gpu-screen-recorder
        qt6-qtdeclarative qt6-qtdeclarative-devel
        qt6-qtsvg qt6-qtsvg-devel qt6-qtshadertools-devel
        pipewire-devel aubio-devel
        dbus-devel dbus-glib-devel python3-devel
        kvantum kde-material-you-colors
        keyd
    )

    if [[ "$BASE_DISTRO" == "arch" ]]; then
        warn "The following packages will be removed:"
        printf '  %s\n' "${ARCH_PACKAGES[@]}"
        echo
        read -r -p "Proceed? [y/N]: " _pkg_confirm
        if [[ "${_pkg_confirm,,}" == "y" || "${_pkg_confirm,,}" == "yes" ]]; then
            # Remove packages that are actually installed; ignore errors for missing ones
            mapfile -t _installed < <(yay -Qq "${ARCH_PACKAGES[@]}" 2>/dev/null)
            if [[ ${#_installed[@]} -gt 0 ]]; then
                yay -Rns --noconfirm "${_installed[@]}" 2>/dev/null || \
                    warn "Some packages could not be removed automatically. Check manually."
            fi
            ok "Arch packages removed"
        else
            skip "Package removal skipped"
        fi
    elif [[ "$BASE_DISTRO" == "fedora" ]]; then
        warn "The following packages will be removed:"
        printf '  %s\n' "${FEDORA_PACKAGES[@]}"
        echo
        read -r -p "Proceed? [y/N]: " _pkg_confirm
        if [[ "${_pkg_confirm,,}" == "y" || "${_pkg_confirm,,}" == "yes" ]]; then
            printf '%s\n' "$SUDO_PASS" | sudo -S dnf remove -y "${FEDORA_PACKAGES[@]}" 2>/dev/null || \
                warn "Some packages could not be removed. Check manually."
            ok "Fedora packages removed"
        else
            skip "Package removal skipped"
        fi
    fi

    # Remove caelestia-cli pip package (both global and user)
    if command -v caelestia >/dev/null 2>&1 || python3 -m caelestia --help &>/dev/null 2>&1; then
        printf '%s\n' "$SUDO_PASS" | sudo -S pip3 uninstall -y caelestia 2>/dev/null || true
        pip3 uninstall -y caelestia 2>/dev/null || true
        ok "Removed caelestia pip package"
    fi

    # Remove uv-installed tools
    if command -v uv >/dev/null 2>&1; then
        uv tool uninstall kde-material-you-colors 2>/dev/null || true
        ok "Removed kde-material-you-colors (uv)"
    fi

    # Remove Polonium KWin script if installed
    if command -v kpackagetool6 >/dev/null 2>&1; then
        if kpackagetool6 -t KWin/Script -s polonium >/dev/null 2>&1; then
            kpackagetool6 -t KWin/Script -r polonium 2>/dev/null || true
            ok "Removed Polonium KWin script"
        fi
    fi
else
    skip "Package removal skipped (user chose to keep packages)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 10 — Clean up cache and build artefacts
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 10 — Clean up cache & build artefacts${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

# CMake build dirs inside the repo
for build_dir in "$BUNDLE_DIR/shell/build" "$BUNDLE_DIR/shell/plugin/build"; do
    if [[ -d "$build_dir" ]]; then
        rm -rf "$build_dir"
        ok "Removed build dir: $build_dir"
    fi
done

# Installer cache
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
if [[ -d "$CACHE_DIR" ]]; then
    echo -e "${YELLOW}Remove installer cache at $CACHE_DIR? [y/N]:${RST} "
    read -r _cache_confirm
    if [[ "${_cache_confirm,,}" == "y" || "${_cache_confirm,,}" == "yes" ]]; then
        rm -rf "$CACHE_DIR"
        ok "Removed installer cache"
    else
        skip "Kept installer cache at $CACHE_DIR"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 11 — Reload KDE
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 11 — Reload KDE${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

qdbus6 org.kde.KWin /KWin reconfigure                    2>/dev/null || true
systemctl --user restart plasma-kglobalaccel.service      2>/dev/null || true
kbuildsycoca6 --noincremental                             2>/dev/null || true

if command -v lookandfeeltool >/dev/null 2>&1; then
    lookandfeeltool --apply "org.kde.breeze.desktop" 2>/dev/null || true
fi

ok "KDE reloaded"

# ══════════════════════════════════════════════════════════════════════════════
# Done
# ══════════════════════════════════════════════════════════════════════════════
echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${GREEN}  Caelestia KDE has been uninstalled.${RST}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo
echo -e "  Backups of your original configs are in:  ${BOLD}$BUNDLE_DIR/backups/${RST}"
echo
echo -e "${YELLOW}  Please log out and back in to fully apply all changes.${RST}"
echo

# Prompt user for immediate logout (same behavior as setup finalizer)
read -r -p "Would you like to log out now? (y/N): " response
case "$response" in
    [yY][eE][sS]|[yY])
        echo "Logging out..."
        qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout 2>/dev/null || true
        ;;
    *)
        echo "Exiting script. Please remember to log out manually later."
        ;;
esac
