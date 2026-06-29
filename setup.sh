#!/usr/bin/env bash
# Caelestia KDE Port - Unified Installer
# Original Hyprland dots: Caelestia
# KDE port and modifications: ladybug-me
# Idempotent by design - safe to run multiple times.

set -uo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BUNDLE_DIR/scripts"
export BUNDLE_DIR

source "$SCRIPTS_DIR/00-ui.sh"

die() { ui_die "$@"; }
info() { ui_info "$@"; }
ok() { ui_ok "$@"; }
warn() { ui_warn "$@"; }
section_header() { ui_section "$@"; }
prompt_yes_no() { ui_prompt_yes_no "$@"; }

# ── Download/Cache Configuration ───────────────────────────────────────────────
export CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
export BUILDDIR="$CACHE_DIR/makepkg-build"
export PKGDEST="$CACHE_DIR/makepkg-packages"
export SRCDEST="$CACHE_DIR/makepkg-sources"
export SRCPKGDEST="$CACHE_DIR/makepkg-srcpackages"

# Ensure cache subdirectories exist
mkdir -p "$CACHE_DIR" "$BUILDDIR" "$PKGDEST" "$SRCDEST" "$SRCPKGDEST"
rm -f "$CACHE_DIR/failed_steps.txt" "$CACHE_DIR/failed_packages.txt"

# ── Pre-flight checks & OS Detection ───────────────────────────────────────────
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        arch|cachyos|endeavouros|manjaro|artix)
            export BASE_DISTRO="arch"
            ;;
        fedora|nobara|bazzite|rhel|centos|almalinux|rocky)
            export BASE_DISTRO="fedora"
            ;;
        *)
            if echo "$ID_LIKE" | grep -iq "arch"; then
                export BASE_DISTRO="arch"
            elif echo "$ID_LIKE" | grep -iq "fedora"; then
                export BASE_DISTRO="fedora"
            else
                export BASE_DISTRO="unknown"
            fi
            ;;
    esac
else
    export BASE_DISTRO="unknown"
fi

if [[ "$BASE_DISTRO" == "unknown" ]]; then
    echo -e "${YELLOW}[WARN] Could not automatically detect your distribution base.${RST}"
    echo "Please select your base distribution:"
    echo "  1) Arch-based"
    echo "  2) Fedora"
    echo "  3) Exit"
    read -r -p "Enter choice [1-3]: " distro_choice
    case "$distro_choice" in
        1) export BASE_DISTRO="arch" ;;
        2) export BASE_DISTRO="fedora" ;;
        *) die "Exiting installer." ;;
    esac
fi

if [[ "$BASE_DISTRO" == "arch" ]] && ! command -v pacman >/dev/null 2>&1; then
    die "pacman not found. This installer requires Arch Linux or an Arch-based distro."
elif [[ "$BASE_DISTRO" == "fedora" ]] && ! command -v dnf >/dev/null 2>&1; then
    die "dnf not found. This installer requires Fedora or a Fedora-based distro."
fi

# ══════════════════════════════════════════════════════════════
#  ASK USER PREFERENCES
# ══════════════════════════════════════════════════════════════
echo
section_header "Installer preferences"

# Automatic package confirmation is always enabled.
export CONFIRM_ARG="--noconfirm"

# Defaults requested by project maintainer.
POLONIUM_ENABLED="false"
REMOVE_CACHE="true"
APPLY_DARKLY="true"
APPLY_MATERIAL_YOU="true"
APPLY_FONTS="true"

toggle_bool() {
    local var_name="$1"
    if [[ "${!var_name}" == "true" ]]; then
        printf -v "$var_name" '%s' "false"
    else
        printf -v "$var_name" '%s' "true"
    fi
}

checkbox_mark() {
    if [[ "$1" == "true" ]]; then
        printf '[x]'
    else
        printf '[ ]'
    fi
}

draw_preferences() {
    echo
    ui_separator
    echo "  Configure installation options"
    ui_separator
    printf "  %s Enable Polonium tiling\n" "$(checkbox_mark "$POLONIUM_ENABLED")"
    printf "  %s Remove downloaded packages and build files after installation\n" "$(checkbox_mark "$REMOVE_CACHE")"
    printf "  %s Apply Darkly theme (Plasma, decorations, Kvantum, Bibata cursors)\n" "$(checkbox_mark "$APPLY_DARKLY")"
    printf "  %s Enable Material You colors (kde-material-you-colors daemon)\n" "$(checkbox_mark "$APPLY_MATERIAL_YOU")"
    printf "  %s Apply included custom fonts (lookandfeeltool)\n" "$(checkbox_mark "$APPLY_FONTS")"
    echo
    ui_info "Use Up/Down arrows to move. Press Enter to toggle a checkbox."
    ui_info "Select Continue and press Enter when ready."
}

draw_preferences_tui() {
    local selected="$1"
    local marker

    clear
    ui_separator
    echo "  Configure installation options"
    ui_separator
    echo

    marker="  "
    [[ "$selected" -eq 0 ]] && marker="> "
    printf "%s%s Enable Polonium tiling\n" "$marker" "$(checkbox_mark "$POLONIUM_ENABLED")"

    marker="  "
    [[ "$selected" -eq 1 ]] && marker="> "
    printf "%s%s Remove downloaded packages and build files after installation\n" "$marker" "$(checkbox_mark "$REMOVE_CACHE")"

    marker="  "
    [[ "$selected" -eq 2 ]] && marker="> "
    printf "%s%s Apply Darkly theme (Plasma, decorations, Kvantum, Bibata cursors)\n" "$marker" "$(checkbox_mark "$APPLY_DARKLY")"

    marker="  "
    [[ "$selected" -eq 3 ]] && marker="> "
    printf "%s%s Enable Material You colors (kde-material-you-colors daemon)\n" "$marker" "$(checkbox_mark "$APPLY_MATERIAL_YOU")"

    marker="  "
    [[ "$selected" -eq 4 ]] && marker="> "
    printf "%s%s Apply included custom fonts (lookandfeeltool)\n" "$marker" "$(checkbox_mark "$APPLY_FONTS")"

    marker="  "
    [[ "$selected" -eq 5 ]] && marker="> "
    printf "%s[ ] Continue\n" "$marker"

    echo
    ui_info "Use Up/Down arrows to move. Press Enter to toggle or continue."
}

selected_option=0
max_option=5

tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null || true' RETURN

while true; do
    draw_preferences_tui "$selected_option"

    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn1 key2
        IFS= read -rsn1 key3
        case "$key2$key3" in
            "[A")
                if [[ "$selected_option" -gt 0 ]]; then
                    selected_option=$((selected_option - 1))
                fi
                ;;
            "[B")
                if [[ "$selected_option" -lt "$max_option" ]]; then
                    selected_option=$((selected_option + 1))
                fi
                ;;
        esac
    elif [[ -z "$key" || "$key" == $'\n' ]]; then
        case "$selected_option" in
            0) toggle_bool POLONIUM_ENABLED ;;
            1) toggle_bool REMOVE_CACHE ;;
            2) toggle_bool APPLY_DARKLY ;;
            3) toggle_bool APPLY_MATERIAL_YOU ;;
            4) toggle_bool APPLY_FONTS ;;
            5) break ;;
        esac
    fi
done

tput cnorm 2>/dev/null || true
trap - RETURN
clear
draw_preferences

if [[ "$POLONIUM_ENABLED" == "true" ]]; then
    echo
    ui_warn "Polonium may cause close, maximize, and minimize buttons to be unresponsive."
    ui_warn "You may need to use Alt+F4 to close applications."
    if ! prompt_yes_no "Keep Polonium enabled?"; then
        POLONIUM_ENABLED="false"
    fi
fi

export POLONIUM_ENABLED REMOVE_CACHE APPLY_DARKLY APPLY_MATERIAL_YOU APPLY_FONTS

echo
ui_section "Preference summary"
echo "  Polonium tiling: $POLONIUM_ENABLED"
echo "  Remove downloaded packages/cache: $REMOVE_CACHE"
echo "  Apply Darkly theme: $APPLY_DARKLY"
echo "  Enable Material You colors: $APPLY_MATERIAL_YOU"
echo "  Apply included custom fonts: $APPLY_FONTS"

# ── Step runner ────────────────────────────────────────────────────────────────
# Runs a step script. On failure prints a warning and prompts for retry/ignore/exit.
run_step() {
    local name="$1" script="$2"
    while true; do
        echo
        info "Running: $name"
        
        # Refresh sudo timeout
        printf '%s\n' "${SUDO_PASS:-}" | sudo -S -v &>/dev/null || true
        
        if bash "$script"; then
            ok "$name — done"
            break
        else
            warn "$name — encountered errors"
            while true; do
                echo -e "${YELLOW}Choose an action: [r]etry, [i]gnore, [e]xit:${RST} "
                read -r step_action
                case "${step_action,,}" in
                    r|retry)
                        info "Retrying $name..."
                        break
                        ;;
                    e|exit)
                        die "Aborting installation."
                        ;;
                    i|ignore)
                        info "Ignoring error and continuing..."
                        echo "$name" >> "$CACHE_DIR/failed_steps.txt"
                        break
                        ;;
                    *)
                        ui_warn "Please enter r, i, or e."
                        ;;
                esac
            done
        fi
    done
}

# ══════════════════════════════════════════════════════════════
#  BANNER
# ══════════════════════════════════════════════════════════════
bash "$SCRIPTS_DIR/00-banner.sh"

# ══════════════════════════════════════════════════════════════
#  ONE-TIME SUDO PASSWORD (kept alive for the full install)
# ══════════════════════════════════════════════════════════════
echo -e "${YELLOW}This installer needs sudo for package installation.${RST}"
while true; do
    IFS= read -s -p "Please enter your sudo password: " SUDO_PASS
    echo
    sudo -k
    if printf '%s\n' "$SUDO_PASS" | sudo -S -v &>/dev/null; then
        break
    else
        echo -e "${RED}[ERROR] Incorrect password. Please try again.${RST}"
    fi
done
export SUDO_PASS

# Temporarily grant NOPASSWD to the user to prevent yay/makepkg from prompting
printf '%s\n' "$SUDO_PASS" | sudo -S sh -c "echo '$USER ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/caelestia-installer-temp && chmod 0440 /etc/sudoers.d/caelestia-installer-temp"

trap 'printf "%s\n" "$SUDO_PASS" | sudo -S rm -f /etc/sudoers.d/caelestia-installer-temp 2>/dev/null' EXIT

# ══════════════════════════════════════════════════════════════
#  STEP 0 — System update (first thing after auth)
# ══════════════════════════════════════════════════════════════
echo
if [[ "$BASE_DISTRO" == "arch" ]]; then
    section_header "Step 0 — System Update" "pacman -Syu"
else
    section_header "Step 0 — System Update" "dnf upgrade"
fi
echo
if [[ "$BASE_DISTRO" == "arch" ]]; then
    info "Running sudo pacman -Syu to bring the system up to date first..."
    if sudo pacman -Syu --noconfirm; then
        ok "System is up to date."
    else
        warn "pacman -Syu encountered errors. Continuing anyway..."
    fi
else
    info "Running sudo dnf upgrade --refresh -y to bring the system up to date first..."
    if sudo dnf upgrade --refresh -y; then
        ok "System is up to date."
    else
        warn "dnf upgrade encountered errors. Continuing anyway..."
    fi
fi

# ══════════════════════════════════════════════════════════════
#  STEP 1 — Ensure prerequisites
# ══════════════════════════════════════════════════════════════
if [[ "$BASE_DISTRO" == "arch" ]]; then
    section_header "Step 1/11 — Prerequisites" "yay"
else
    section_header "Step 1/11 — Prerequisites" "dnf, yq, createrepo_c"
fi
run_step "Ensure prerequisites" "$SCRIPTS_DIR/01-ensure-prereqs.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 2 — Packages (PKGBUILDs + supplemental)
# ══════════════════════════════════════════════════════════════
section_header "Step 2/11 — Package Installation"
run_step "Package installation" "$SCRIPTS_DIR/02-packages.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 3 — Backup and Deploy configs
# ══════════════════════════════════════════════════════════════
section_header "Step 3/11 — Config Deployment"
run_step "Backup KDE Themes" "$SCRIPTS_DIR/00-backup-themes.sh"
run_step "Config deployment" "$SCRIPTS_DIR/03-deploy-configs.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 4 — Apply KDE settings (Darkly, Kvantum, polonium)
# ══════════════════════════════════════════════════════════════
section_header "Step 4/11 — KDE Settings"
run_step "KDE settings" "$SCRIPTS_DIR/04-deploy-kde.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 5 — Keyboard shortcuts & workspaces
# ══════════════════════════════════════════════════════════════
section_header "Step 5/11 — Keyboard Shortcuts & Workspaces"
run_step "Keyboard shortcuts" "$BUNDLE_DIR/src/keyboardshortcuts/register.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 6 — Services
# ══════════════════════════════════════════════════════════════
section_header "Step 6/11 — Services"
run_step "Services" "$SCRIPTS_DIR/06-services.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 7 — Install KDE extra apps (kvantum, darkly, kde-material-you-colors)
# ══════════════════════════════════════════════════════════════
section_header "Step 7/11 — KDE Theme Apps"
run_step "KDE theme apps" "$SCRIPTS_DIR/07-kde-apps.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 8 — Build and Install Caelestia Shell
# ══════════════════════════════════════════════════════════════
section_header "Step 8/11 — Build Caelestia Shell"
run_step "Build Caelestia Shell" "$SCRIPTS_DIR/08-build-shell.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 9 — Apply live system tweaks
# ══════════════════════════════════════════════════════════════
section_header "Step 9/11 — System Tweaks"
run_step "System tweaks" "$SCRIPTS_DIR/09-system-tweaks.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 10 — Autostart (Quickshell + kde-material-you-colors)
# ══════════════════════════════════════════════════════════════
section_header "Step 10/11 — Autostart"
run_step "Autostart" "$SCRIPTS_DIR/10-autostart.sh"

# ══════════════════════════════════════════════════════════════
#  CLEANUP CACHE
# ══════════════════════════════════════════════════════════════
if [[ "${REMOVE_CACHE:-}" == "true" ]]; then
    echo
    info "Cleaning up downloaded packages and build files..."
    rm -rf "$CACHE_DIR"
    ok "Downloaded packages and build files removed."
fi

# ══════════════════════════════════════════════════════════════
#  STEP 11 — Finalize (summary + logout instructions)
# ══════════════════════════════════════════════════════════════
section_header "Step 11/11 — Finalize"
run_step "Finalize" "$SCRIPTS_DIR/11-finalize.sh"
