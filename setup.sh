#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║        Caelestia KDE Port — Unified Installer               ║
# ║                                                              ║
# ║  Original Hyprland dots: Caelestia                           ║
# ║  KDE port & modifications: ladybug-me                        ║
# ║                                                              ║
# ║  Idempotent — safe to run multiple times.                    ║
# ╚══════════════════════════════════════════════════════════════╝

set -uo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BUNDLE_DIR/scripts"
export BUNDLE_DIR

# ── Download/Cache Configuration ───────────────────────────────────────────────
export CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
export BUILDDIR="$CACHE_DIR/makepkg-build"
export PKGDEST="$CACHE_DIR/makepkg-packages"
export SRCDEST="$CACHE_DIR/makepkg-sources"
export SRCPKGDEST="$CACHE_DIR/makepkg-srcpackages"

# Ensure cache subdirectories exist
mkdir -p "$CACHE_DIR" "$BUILDDIR" "$PKGDEST" "$SRCDEST" "$SRCPKGDEST"
rm -f "$CACHE_DIR/failed_steps.txt" "$CACHE_DIR/failed_packages.txt"

# ── Colors ─────────────────────────────────────────────────────────────────────
RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"
CYAN="\033[0;36m"; RST="\033[0m"

die()  { echo -e "${RED}[FATAL] $*${RST}" >&2; exit 1; }
info() { echo -e "${CYAN}[INFO]  $*${RST}"; }
ok()   { echo -e "${GREEN}[OK]    $*${RST}"; }
warn() { echo -e "${RED}[WARN]  $*${RST}"; }

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
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    echo -e "${CYAN}  Step 0 — System Update (pacman -Syu)${RST}"
else
    echo -e "${CYAN}  Step 0 — System Update (dnf upgrade)${RST}"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
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
#  ASK USER PREFERENCES
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Installer preferences${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

# Polonium tiling WM — ask user
echo
echo -e "${YELLOW}Polonium is a KDE tiling window manager plugin.${RST}"
echo -e "Would you like to enable Polonium tiling? [y/N]: "
read -r -t 15 polonium_answer || polonium_answer="n"
case "${polonium_answer,,}" in
    y|yes)
        echo -e "\n\033[1;5;31m[WARNING] The close button, maximize and minimize buttons will not respond!\033[0m"
        echo -e "\033[1;31mYou will have to use Alt+F4 to close apps (bug of Polonium).\033[0m\n"
        read -r -p "$(echo -e "${YELLOW}Are you sure you still want to enable Polonium? [y/N]: ${RST}")" polonium_confirm
        case "${polonium_confirm,,}" in
            y|yes) export POLONIUM_ENABLED="true";  echo "  → Polonium will be ENABLED." ;;
            *)     export POLONIUM_ENABLED="false"; echo "  → Polonium will be DISABLED." ;;
        esac
        ;;
    *)     export POLONIUM_ENABLED="false"; echo "  → Polonium will be DISABLED (default)." ;;
esac

# Auto-confirm package installation — ask user
echo
echo -e "${YELLOW}Would you like package installation to proceed automatically without confirmation?${RST}"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    echo -e "If you select No, you will be prompted to confirm each pacman/yay transaction. [Y/n]: "
else
    echo -e "If you select No, you will be prompted to confirm each dnf transaction. [Y/n]: "
fi
read -r -t 15 confirm_answer || confirm_answer="y"
case "${confirm_answer,,}" in
    n|no) export CONFIRM_ARG="";            echo "  → Manual confirmation ENABLED." ;;
    *)    export CONFIRM_ARG="--noconfirm"; echo "  → Automated installation ENABLED (--noconfirm)." ;;
esac

# Clean up downloaded package cache and build files — ask user
echo
echo -e "${YELLOW}Would you like to remove the downloaded packages and build files after a successful installation? [y/N]:${RST} "
read -r -t 15 clean_answer || clean_answer="n"
case "${clean_answer,,}" in
    y|yes) export REMOVE_CACHE="true";  echo "  → Downloaded packages/cache will be REMOVED." ;;
    *)     export REMOVE_CACHE="false"; echo "  → Downloaded packages/cache will be KEPT (default)." ;;
esac


# ══════════════════════════════════════════════════════════════
#  STEP 1 — Ensure prerequisites
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    echo -e "${CYAN}  Step 1/11 — Prerequisites (yay)${RST}"
else
    echo -e "${CYAN}  Step 1/11 — Prerequisites (dnf, yq, createrepo_c)${RST}"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "Ensure prerequisites" "$SCRIPTS_DIR/01-ensure-prereqs.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 2 — Packages (PKGBUILDs + supplemental)
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 2/11 — Package Installation${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "Package installation" "$SCRIPTS_DIR/02-packages.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 3 — Deploy configs
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 3/11 — Config Deployment${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "Config deployment" "$SCRIPTS_DIR/03-deploy-configs.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 4 — Apply KDE settings (Darkly, Kvantum, polonium)
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 4/11 — KDE Settings${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "KDE settings" "$SCRIPTS_DIR/04-deploy-kde.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 5 — Keyboard shortcuts & workspaces
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 5/11 — Keyboard Shortcuts & Workspaces${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "Keyboard shortcuts" "$BUNDLE_DIR/src/keyboardshortcuts/register.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 6 — Services
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 6/11 — Services${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "Services" "$SCRIPTS_DIR/06-services.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 7 — Install KDE extra apps (kvantum, darkly, kde-material-you-colors)
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 7/11 — KDE Theme Apps${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "KDE theme apps" "$SCRIPTS_DIR/07-kde-apps.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 8 — Build and Install Caelestia Shell
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 8/11 — Build Caelestia Shell${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "Build Caelestia Shell" "$SCRIPTS_DIR/08-build-shell.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 9 — Apply live system tweaks
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 9/11 — System Tweaks${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "System tweaks" "$SCRIPTS_DIR/09-system-tweaks.sh"

# ══════════════════════════════════════════════════════════════
#  STEP 10 — Autostart (Quickshell + kde-material-you-colors)
# ══════════════════════════════════════════════════════════════
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 10/11 — Autostart${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
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
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${CYAN}  Step 11/11 — Finalize${RST}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
run_step "Finalize" "$SCRIPTS_DIR/11-finalize.sh"
