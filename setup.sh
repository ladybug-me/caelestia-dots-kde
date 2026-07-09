#!/usr/bin/env bash
# ==============================================================
#   Caelestia KDE Port - Unified Installer
#
#   Original Hyprland dots: Caelestia
#   KDE port and modifications: ladybug-me
#   Installer behavior: idempotent and safe for reruns
# ==============================================================

set -uo pipefail

# -- Paths ---------------------------------------------------------------------
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BUNDLE_DIR/scripts"
export BUNDLE_DIR

normalize_line_endings_first() {
    local base_distro="unknown"
    local -a crlf_files=()
    local convert_choice=""

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "$ID" in
            arch|cachyos|endeavouros|manjaro|artix)
                base_distro="arch"
                ;;
            fedora|nobara|bazzite|rhel|centos|almalinux|rocky)
                base_distro="fedora"
                ;;
            *)
                if echo "${ID_LIKE:-}" | grep -iq "arch"; then
                    base_distro="arch"
                elif echo "${ID_LIKE:-}" | grep -iq "fedora"; then
                    base_distro="fedora"
                fi
                ;;
        esac
    fi

    if [[ "$base_distro" == "unknown" ]]; then
        if command -v pacman >/dev/null 2>&1; then
            base_distro="arch"
        elif command -v dnf >/dev/null 2>&1; then
            base_distro="fedora"
        fi
    fi
    mapfile -t crlf_files < <(
        find "$BUNDLE_DIR" -path "$BUNDLE_DIR/.git" -prune -o -type f -print0 | \
            xargs -0 grep -Il $'\r' 2>/dev/null || true
    )

    if (( ${#crlf_files[@]} == 0 )); then
        echo "[OK]    Line ending check: no CRLF files detected under bundle directory."
        return 0
    fi

    echo "[WARN]  Detected ${#crlf_files[@]} file(s) with CRLF line endings."
    while true; do
        read -r -p "Convert all files under this repo to LF with dos2unix? [Y/n]: " convert_choice
        convert_choice="${convert_choice:-y}"

        case "${convert_choice,,}" in
            y|yes)
                if ! command -v dos2unix >/dev/null 2>&1; then
                    echo "[WARN]  dos2unix is not installed. Attempting to install it now..."
                    case "$base_distro" in
                        arch)
                            sudo pacman -S --needed --noconfirm dos2unix || return 1
                            ;;
                        fedora)
                            sudo dnf install -y dos2unix || return 1
                            ;;
                        *)
                            echo "[WARN]  Could not detect distro for automatic dos2unix installation."
                            return 1
                            ;;
                    esac
                    echo "[OK]    dos2unix installed."
                fi

                (
                    cd "$BUNDLE_DIR" || exit 1
                    printf '%s\0' "${crlf_files[@]}" | xargs -0 -r dos2unix --
                ) || return 1

                echo "[OK]    Line endings normalized to LF."
                return 0
                ;;
            n|no)
                echo "[WARN]  Skipping line ending normalization by user choice."
                return 0
                ;;
            *)
                echo "Please answer with y or n."
                ;;
        esac
    done
}

if ! normalize_line_endings_first; then
    echo "[FATAL] Line ending normalization step failed. Aborting installer." >&2
    exit 1
fi

# -- Download/Cache Configuration -----------------------------------------------
export CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
export BUILDDIR="$CACHE_DIR/makepkg-build"
export PKGDEST="$CACHE_DIR/makepkg-packages"
export SRCDEST="$CACHE_DIR/makepkg-sources"
export SRCPKGDEST="$CACHE_DIR/makepkg-srcpackages"

# Ensure cache subdirectories exist
mkdir -p "$CACHE_DIR" "$BUILDDIR" "$PKGDEST" "$SRCDEST" "$SRCPKGDEST"
rm -f "$CACHE_DIR/failed_steps.txt" "$CACHE_DIR/failed_packages.txt"

# -- Colors --------------------------------------------------------------------
RST="\033[0m"
BOLD="\033[1m"
PURPLE="\033[38;5;135m"
BLUE="\033[38;5;75m"
CYAN="\033[38;5;87m"
PINK="\033[38;5;213m"
GREEN="\033[38;5;84m"
RED="\033[38;5;196m"
YELLOW="\033[38;5;220m"

die()  { echo -e "${RED}[FATAL] $*${RST}" >&2; exit 1; }
info() { echo -e "${BLUE}[INFO]  $*${RST}"; }
ok()   { echo -e "${GREEN}[OK]    $*${RST}"; }
warn() { echo -e "${YELLOW}[WARN]  $*${RST}"; }

# Track total installer runtime.
INSTALL_START_EPOCH="$(date +%s)"
export INSTALL_START_EPOCH

ensure_dots_content() {
    local dots_dir="$BUNDLE_DIR/src/dots"

    if [[ -d "$dots_dir/fish" || -d "$dots_dir/hypr" ]]; then
        return 0
    fi

    if command -v git >/dev/null 2>&1 && \
       git -C "$BUNDLE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
       [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
        info "Initializing src/dots submodule..."
        git -C "$BUNDLE_DIR" submodule sync -- src/dots >/dev/null 2>&1 || true
        git -C "$BUNDLE_DIR" submodule update --init --recursive src/dots || \
            die "Failed to initialize src/dots submodule."
    fi

    [[ -d "$dots_dir/fish" || -d "$dots_dir/hypr" ]] || \
        die "Missing src/dots content. Run: git submodule update --init --recursive src/dots"
}

KDE_INHIBIT_COOKIE=""
SYSTEMD_INHIBIT_PID=""

cleanup_install_state() {
    if [[ -n "$SYSTEMD_INHIBIT_PID" ]] && kill -0 "$SYSTEMD_INHIBIT_PID" 2>/dev/null; then
        kill "$SYSTEMD_INHIBIT_PID" 2>/dev/null || true
        wait "$SYSTEMD_INHIBIT_PID" 2>/dev/null || true
    fi

    if [[ -n "$KDE_INHIBIT_COOKIE" ]] && command -v qdbus6 >/dev/null 2>&1; then
        qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.UnInhibit "$KDE_INHIBIT_COOKIE" 2>/dev/null || true
    fi

    if [[ -n "${SUDO_PASS:-}" ]]; then
        printf '%s\n' "$SUDO_PASS" | sudo -S rm -f /etc/sudoers.d/caelestia-installer-temp 2>/dev/null || true
    else
        sudo rm -f /etc/sudoers.d/caelestia-installer-temp 2>/dev/null || true
    fi
}

enable_install_awake_guard() {
    local inhibitor_cookie=""

    if command -v qdbus6 >/dev/null 2>&1; then
        inhibitor_cookie="$(qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.Inhibit \
            "Caelestia Installer" "Installation in progress" 2>/dev/null || true)"
        if [[ "$inhibitor_cookie" =~ ^[0-9]+$ ]]; then
            KDE_INHIBIT_COOKIE="$inhibitor_cookie"
            info "KDE idle inhibition enabled for this install session."
        else
            warn "Could not enable KDE ScreenSaver inhibit (continuing)."
        fi
    else
        warn "qdbus6 not found; KDE ScreenSaver inhibit unavailable (continuing)."
    fi

    if command -v systemd-inhibit >/dev/null 2>&1; then
        systemd-inhibit --what=idle:sleep --who="Caelestia Installer" --why="Installation in progress" \
            bash -c 'while :; do sleep 600; done' >/dev/null 2>&1 &
        SYSTEMD_INHIBIT_PID="$!"
        if ! kill -0 "$SYSTEMD_INHIBIT_PID" 2>/dev/null; then
            SYSTEMD_INHIBIT_PID=""
            warn "Could not enable systemd idle/sleep inhibitor (continuing)."
        else
            info "System idle/sleep inhibition enabled for this install session."
        fi
    else
        warn "systemd-inhibit not found; logind sleep inhibitor unavailable (continuing)."
    fi
}

trap cleanup_install_state EXIT
# -- Pre-flight checks and OS detection -----------------------------------------
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

# -- Step runner ----------------------------------------------------------------
# Runs a step script. On failure prints a warning and prompts for retry/ignore/exit.
run_step() {
    local name="$1" script="$2"
    while true; do
        echo
        info "Running: $name"
        
        # Refresh sudo timeout
        printf '%s\n' "${SUDO_PASS:-}" | sudo -S -v &>/dev/null || true
        
        if bash "$script"; then
            ok "$name - done"
            break
        else
            warn "$name - encountered errors"
            echo -e "${YELLOW}What would you like to do? [r]etry, [i]gnore, [e]xit:${RST} "
            read -r -t 60 step_action || step_action="i"
            case "${step_action,,}" in
                r|retry)
                    info "Retrying $name..."
                    ;;
                e|exit)
                    die "Aborting installation."
                    ;;
                *)
                    info "Ignoring error and continuing..."
                    echo "$name" >> "$CACHE_DIR/failed_steps.txt"
                    break
                    ;;
            esac
        fi
    done
}

# Prompt helper: ask a yes/no question with validation and default.
ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local answer

    while true; do
        if [[ "$default" == "y" ]]; then
            read -r -p "$prompt [Y/n]: " answer
            answer="${answer:-y}"
        else
            read -r -p "$prompt [y/N]: " answer
            answer="${answer:-n}"
        fi

        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)
                echo -e "${YELLOW}Please answer with y or n.${RST}"
                ;;
        esac
    done
}

# Installer questionnaire: collect all user config choices up front.
collect_installer_preferences() {
    while true; do
        echo
        echo -e "${CYAN}+------------------------------------------------------------+${RST}"
        echo -e "${CYAN}|                  Installer Configuration                   |${RST}"
        echo -e "${CYAN}+------------------------------------------------------------+${RST}"
        echo

        echo -e "${BOLD}General${RST}"
        if ask_yes_no "Enable automatic package transaction confirmation" "y"; then
            export CONFIRM_ARG="--noconfirm"
        else
            export CONFIRM_ARG=""
        fi

        if ask_yes_no "Remove downloaded packages/build cache after successful install" "n"; then
            export REMOVE_CACHE="true"
        else
            export REMOVE_CACHE="false"
        fi

        echo
        echo -e "${BOLD}KDE Tiling${RST}"
        echo -e "${YELLOW}Note: Polonium currently has a known issue where window buttons may not respond.${RST}"
        if ask_yes_no "Enable Polonium tiling plugin" "n"; then
            export POLONIUM_ENABLED="true"
        else
            export POLONIUM_ENABLED="false"
        fi

        echo
        echo -e "${BOLD}Theming${RST}"
        echo -e "${YELLOW}These options can overwrite parts of your current KDE theme setup.${RST}"

        if ask_yes_no "Apply Darkly theme (Plasma style, window decorations, Kvantum, cursors)" "y"; then
            export APPLY_DARKLY="true"
        else
            export APPLY_DARKLY="false"
        fi

        if ask_yes_no "Enable Material You colors (kde-material-you-colors daemon)" "y"; then
            export APPLY_MATERIAL_YOU="true"
        else
            export APPLY_MATERIAL_YOU="false"
        fi

        if ask_yes_no "Apply included custom fonts" "y"; then
            export APPLY_FONTS="true"
        else
            export APPLY_FONTS="false"
        fi

        echo
        echo -e "${CYAN}+------------------------------------------------------------+${RST}"
        echo -e "${CYAN}|                       Configuration                        |${RST}"
        echo -e "${CYAN}+------------------------------------------------------------+${RST}"
        printf "  %-44s %s\n" "Base distro:" "$BASE_DISTRO"
        if [[ -n "$CONFIRM_ARG" ]]; then
            printf "  %-44s %s\n" "Auto package confirmation:" "enabled"
        else
            printf "  %-44s %s\n" "Auto package confirmation:" "disabled"
        fi
        printf "  %-44s %s\n" "Remove cache after install:" "$REMOVE_CACHE"
        printf "  %-44s %s\n" "Enable Polonium:" "$POLONIUM_ENABLED"
        printf "  %-44s %s\n" "Apply Darkly theme:" "$APPLY_DARKLY"
        printf "  %-44s %s\n" "Enable Material You colors:" "$APPLY_MATERIAL_YOU"
        printf "  %-44s %s\n" "Apply included fonts:" "$APPLY_FONTS"

        echo
        if ask_yes_no "Proceed with these settings" "y"; then
            break
        fi

        echo -e "${YELLOW}Restarting configuration wizard...${RST}"
    done
}

# =============================================================
#  BANNER
# ==============================================================
bash "$SCRIPTS_DIR/00-banner.sh"

# =============================================================
#  ASK USER PREFERENCES (all prompts up front)
# =============================================================
collect_installer_preferences

# Keep display/idle timers inhibited while installer runs so long steps are not interrupted.
enable_install_awake_guard

# =============================================================
#  ONE-TIME SUDO PASSWORD (kept alive for the full install)
# ==============================================================
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

# =============================================================
#  STEP 0 - System update (after configuration + auth)
# =============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    echo -e "${CYAN}  Step 0/11 - System Update (pacman -Syu)${RST}"
else
    echo -e "${CYAN}  Step 0/11 - System Update (dnf upgrade)${RST}"
fi
echo -e "${CYAN}---------------------------------------------${RST}"
echo
if [[ "$BASE_DISTRO" == "arch" ]]; then
    info "Running sudo pacman -Syu now that configuration is complete..."
    if sudo pacman -Syu --noconfirm; then
        ok "System is up to date."
    else
        warn "pacman -Syu encountered errors. Continuing anyway..."
    fi
else
    info "Running sudo dnf upgrade --refresh -y now that configuration is complete..."
    if sudo dnf upgrade --refresh -y; then
        ok "System is up to date."
    else
        warn "dnf upgrade encountered errors. Continuing anyway..."
    fi
fi

# =============================================================
#  STEP 1 - Ensure prerequisites
# =============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    echo -e "${CYAN}  Step 1/11 - Prerequisites (yay)${RST}"
else
    echo -e "${CYAN}  Step 1/11 - Prerequisites (dnf, yq, createrepo_c)${RST}"
fi
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Ensure prerequisites" "$SCRIPTS_DIR/01-ensure-prereqs.sh"

# ==============================================================
#  STEP 2 - Packages (PKGBUILDs + supplemental)
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 2/11 - Package Installation${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Package installation" "$SCRIPTS_DIR/02-packages.sh"

# ==============================================================
#  STEP 3 - Backup and Deploy configs
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 3/11 - Config Deployment${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Backup KDE Settings" "$SCRIPTS_DIR/00-backup-themes.sh"
ensure_dots_content
run_step "Config deployment" "$SCRIPTS_DIR/03-deploy-configs.sh"

# ==============================================================
#  STEP 4 - Apply KDE settings (Darkly, Kvantum, polonium)
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 4/11 - KDE Settings${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "KDE settings" "$SCRIPTS_DIR/04-deploy-kde.sh"

# ==============================================================
#  STEP 5 - Keyboard shortcuts & workspaces
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 5/11 - Keyboard Shortcuts and Workspaces${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Keyboard shortcuts" "$BUNDLE_DIR/src/keyboardshortcuts/register.sh"

# ==============================================================
#  STEP 6 - Services
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 6/11 - Services${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Services" "$SCRIPTS_DIR/06-services.sh"

# ==============================================================
#  STEP 7 - Install KDE extra apps (kvantum, darkly, kde-material-you-colors)
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 7/11 - KDE Theme Apps${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "KDE theme apps" "$SCRIPTS_DIR/07-kde-apps.sh"

# ==============================================================
#  STEP 8 - Build and Install Caelestia Shell
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 8/11 - Build Caelestia Shell${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Build Caelestia Shell" "$SCRIPTS_DIR/08-build-shell.sh"

# ==============================================================
#  STEP 9 - Apply live system tweaks
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 9/11 - System Tweaks${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "System tweaks" "$SCRIPTS_DIR/09-system-tweaks.sh"

# ==============================================================
#  STEP 10 - Autostart (Quickshell + kde-material-you-colors)
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 10/11 - Autostart${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Autostart" "$SCRIPTS_DIR/10-autostart.sh"

# ==============================================================
#  CLEANUP CACHE
# ==============================================================
if [[ "${REMOVE_CACHE:-}" == "true" ]]; then
    echo
    info "Cleaning up downloaded packages and build files..."
    rm -rf "$CACHE_DIR"
    ok "Downloaded packages and build files removed."
fi

# ==============================================================
#  STEP 11 - Finalize (summary + logout instructions)
# ==============================================================
echo
echo -e "${CYAN}---------------------------------------------${RST}"
echo -e "${CYAN}  Step 11/11 - Finalize${RST}"
echo -e "${CYAN}---------------------------------------------${RST}"
run_step "Finalize" "$SCRIPTS_DIR/11-finalize.sh"
