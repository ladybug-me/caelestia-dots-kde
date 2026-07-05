#!/usr/bin/env bash
# 11-finalize.sh - Final step: installation summary and operator instructions.

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RST="\033[0m"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
FAILED_STEPS_FILE="$CACHE_DIR/failed_steps.txt"
FAILED_PKGS_FILE="$CACHE_DIR/failed_packages.txt"
FAILED_PATCHES_FILE="$CACHE_DIR/failed_patches.txt"

print_line() {
    echo -e "${GREEN}+--------------------------------------------------------------+${RST}"
}

check_step() {
    local step_name="$1"
    local desc="$2"
    if [ -f "$FAILED_STEPS_FILE" ] && grep -qF "$step_name" "$FAILED_STEPS_FILE"; then
        printf "${GREEN}|${RST} [X] %-56s ${GREEN}|${RST}\n" "$desc"
    else
        printf "${GREEN}|${RST} [OK] %-55s ${GREEN}|${RST}\n" "$desc"
    fi
}

check_patch() {
    local patch_name="$1"
    local desc="$2"
    if [ -f "$FAILED_PATCHES_FILE" ] && grep -qF "$patch_name" "$FAILED_PATCHES_FILE"; then
        printf "${GREEN}|${RST} [X] %-56s ${GREEN}|${RST}\n" "$desc"
    else
        printf "${GREEN}|${RST} [OK] %-55s ${GREEN}|${RST}\n" "$desc"
    fi
}

echo
print_line
printf "${GREEN}|${RST} %-60s ${GREEN}|${RST}\n" "CAELESTIA INSTALLATION SUMMARY"
print_line

if [[ "$BASE_DISTRO" == "arch" ]]; then
    printf "${GREEN}|${RST} [OK] %-55s ${GREEN}|${RST}\n" "System updated (pacman -Syu)"
else
    printf "${GREEN}|${RST} [OK] %-55s ${GREEN}|${RST}\n" "System updated (dnf upgrade)"
fi

check_step "Package installation" "Packages installed (PKGBUILDs + fonts + deps)"
check_step "Config deployment" "Configs (repo-base + KDE overrides, clean deploy)"
check_step "KDE settings" "Darkly theme + Kvantum + default wallpaper"
check_step "System tweaks" "5 virtual desktops + KDE OSDs disabled"
check_step "Keyboard shortcuts" "Keyboard shortcuts (KDE native + keyd)"
check_step "Autostart" "Quickshell + kde-material-you-colors autostart"
check_step "Build Caelestia Shell" "Caelestia shell built and installed"

print_line
printf "${GREEN}|${RST} %-60s ${GREEN}|${RST}\n" "PATCH STATUS"
print_line
check_patch "Caelestia CLI Hyprctl Mock Patch" "Caelestia CLI Hyprctl mock patch"
check_patch "Caelestia CLI Record/Dolphin Patch" "Caelestia CLI record/dolphin patch"
check_patch "Caelestia CLI Theme Sequence Patch" "Caelestia CLI theme sequence patch"

if [ -f "$FAILED_PKGS_FILE" ] && [ -s "$FAILED_PKGS_FILE" ]; then
    print_line
    printf "${GREEN}|${RST} %-60s ${GREEN}|${RST}\n" "FAILED PACKAGES"
    print_line
    while read -r pkg; do
        if [ -n "$pkg" ]; then
            printf "${GREEN}|${RST} - %-58s ${GREEN}|${RST}\n" "$pkg"
        fi
    done < "$FAILED_PKGS_FILE"
fi

if [ -f "$FAILED_STEPS_FILE" ] && grep -qF "Build Caelestia Shell" "$FAILED_STEPS_FILE"; then
    print_line
    printf "${GREEN}|${RST} %-60s ${GREEN}|${RST}\n" "SHELL BUILD FAILED"
    printf "${GREEN}|${RST} %-60s ${GREEN}|${RST}\n" "Review terminal logs and install missing dependencies."
    printf "${GREEN}|${RST} %-60s ${GREEN}|${RST}\n" "Then re-run ./setup.sh."
fi

print_line
echo
echo -e "${YELLOW}Next steps:${RST}"
echo -e "  1) Log out now, then log back in."
echo -e "  2) If a kernel update occurred, reboot immediately."
echo -e "  3) Remove all KDE panels after login (Super+D -> panel config)."
echo -e "  4) To enter desktop edit mode later: Super+D -> right click desktop."
echo
echo -e "${CYAN}You can re-run this installer at any time. It is idempotent.${RST}"
echo -e "${CYAN}Troubleshooting is available in the project documentation.${RST}"
echo

# Cleanup cmake build cache as it contains absolute paths
rm -rf "$(dirname "$0")/../shell/build" "$(dirname "$0")/../shell/plugin/build"

# Prompt user for immediate logout
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
