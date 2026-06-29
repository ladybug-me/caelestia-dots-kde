#!/usr/bin/env bash
# 11-finalize.sh - Final step: installation summary and instructions.

BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$BUNDLE_DIR/scripts/00-ui.sh"

ui_section "Step 11/11 - Finalize" "Installation complete" "$GREEN"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
FAILED_STEPS_FILE="$CACHE_DIR/failed_steps.txt"
FAILED_PKGS_FILE="$CACHE_DIR/failed_packages.txt"
FAILED_PATCHES_FILE="$CACHE_DIR/failed_patches.txt"

check_step() {
    local step_name="$1"
    local desc="$2"
    if [ -f "$FAILED_STEPS_FILE" ] && grep -qF "$step_name" "$FAILED_STEPS_FILE"; then
        printf '%-12s %s\n' "[FAILED]" "$desc"
    else
        printf '%-12s %s\n' "[OK]" "$desc"
    fi
}

check_patch() {
    local patch_name="$1"
    local desc="$2"
    if [ -f "$FAILED_PATCHES_FILE" ] && grep -qF "$patch_name" "$FAILED_PATCHES_FILE"; then
        printf '%-12s %s\n' "[FAILED]" "$desc"
    else
        printf '%-12s %s\n' "[OK]" "$desc"
    fi
}

echo "What was set up:"
if [[ "$BASE_DISTRO" == "arch" ]]; then
    printf '%-12s %s\n' "[OK]" "System updated (pacman -Syu)"
else
    printf '%-12s %s\n' "[OK]" "System updated (dnf upgrade)"
fi

check_step "Package installation" "Packages installed (PKGBUILDs + fonts + dependencies)"
check_step "Config deployment" "Configs deployed from repo base and KDE overrides"
check_step "KDE settings" "Darkly theme, Kvantum, and default wallpaper"
check_step "System tweaks" "Virtual desktops and KDE OSD settings"
check_step "Keyboard shortcuts" "Keyboard shortcuts and keyd configuration"
check_step "Autostart" "Quickshell and kde-material-you-colors autostart"
check_step "Build Caelestia Shell" "Caelestia Shell built and installed"

echo
echo "Patches applied:"
check_patch "Caelestia CLI Hyprctl Mock Patch" "Caelestia CLI Hyprctl mock patch"
check_patch "Caelestia CLI Record/Dolphin Patch" "Caelestia CLI record and file manager patch"
check_patch "Caelestia CLI Theme Sequence Patch" "Caelestia CLI theme sequence patch"

echo
if [ -f "$FAILED_PKGS_FILE" ] && [ -s "$FAILED_PKGS_FILE" ]; then
    echo "Failed packages:"
    while read -r pkg; do
        if [ -n "$pkg" ]; then
            printf '  - %s\n' "$pkg"
        fi
    done < "$FAILED_PKGS_FILE"
    echo
fi

if [ -f "$FAILED_STEPS_FILE" ] && grep -qF "Build Caelestia Shell" "$FAILED_STEPS_FILE"; then
    echo "Shell build failed. Review the terminal output and logs."
    echo "You may need to install missing dependencies manually and re-run ./setup.sh."
    echo
fi

ui_section "Action required" "Please complete the following" "$YELLOW"
echo "1. Log out now and log back in."
echo "   A fresh login is required to fully apply all KDE and Quickshell changes."
echo "   If a kernel update occurred, reboot immediately."
echo
echo "2. Remove all KDE panels after logging back in."
echo "   Right-click the panel, open Panel configuration, and remove every existing KDE panel for optimal behavior with the Quickshell bar."
echo
echo "3. To enter edit mode next time, press Super+D, then right-click on the desktop and enter edit mode."
echo
echo "You can re-run this installer at any time; it is idempotent."
echo
echo "Shortcuts not working or other problems? Check the troubleshooting steps on GitHub."
echo

rm -rf "$(dirname "$0")/../shell/build" "$(dirname "$0")/../shell/plugin/build"

read -p "Would you like to log out now? (y/N): " response
case "$response" in
    [yY][eE][sS]|[yY])
        echo "Logging out..."
        qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout 2>/dev/null
        ;;
    *)
        echo "Exiting script. Please remember to log out manually later."
        exit 0
        ;;
esac
