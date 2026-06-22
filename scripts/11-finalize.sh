#!/usr/bin/env bash
# 09-finalize.sh — Final step: installation summary and instructions.

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RST="\033[0m"

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RST}"
echo -e "${GREEN}║${RST}                                                            ${GREEN}║${RST}"
echo -e "${GREEN}║${RST}  ${GREEN}✅  Installation complete!${RST}                                ${GREEN}║${RST}"
echo -e "${GREEN}║                                                            ║${RST}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde"
FAILED_STEPS_FILE="$CACHE_DIR/failed_steps.txt"
FAILED_PKGS_FILE="$CACHE_DIR/failed_packages.txt"
FAILED_PATCHES_FILE="$CACHE_DIR/failed_patches.txt"

check_step() {
    local step_name="$1"
    local desc="$2"
    if [ -f "$FAILED_STEPS_FILE" ] && grep -qF "$step_name" "$FAILED_STEPS_FILE"; then
        printf "${GREEN}║${RST}  ${RED}❌${RST} %-54s ${GREEN}║${RST}\n" "$desc"
    else
        printf "${GREEN}║${RST}  ${GREEN}✅${RST} %-54s ${GREEN}║${RST}\n" "$desc"
    fi
}

check_patch() {
    local patch_name="$1"
    local desc="$2"
    if [ -f "$FAILED_PATCHES_FILE" ] && grep -qF "$patch_name" "$FAILED_PATCHES_FILE"; then
        printf "${GREEN}║${RST}  ${RED}❌${RST} %-54s ${GREEN}║${RST}\n" "$desc"
    else
        printf "${GREEN}║${RST}  ${GREEN}✅${RST} %-54s ${GREEN}║${RST}\n" "$desc"
    fi
}

echo -e "${GREEN}║${RST}  What was set up:                                          ${GREEN}║${RST}"

if [[ "$BASE_DISTRO" == "arch" ]]; then
    printf "${GREEN}║${RST}  ${GREEN}✅${RST} %-54s ${GREEN}║${RST}\n" "System updated (pacman -Syu)"
else
    printf "${GREEN}║${RST}  ${GREEN}✅${RST} %-54s ${GREEN}║${RST}\n" "System updated (dnf upgrade)"
fi

check_step "Package installation" "Packages installed (PKGBUILDs + fonts + deps)"
check_step "Config deployment" "Configs (repo-base + KDE overrides, clean deploy)"
check_step "KDE settings" "Darkly theme + Kvantum + Default wallpaper"
check_step "System tweaks" "5 virtual desktops + KDE OSDs disabled"
check_step "Keyboard shortcuts" "Keyboard shortcuts (Kde native + keyd)"
check_step "Autostart" "Quickshell + kde-material-you-colors autostart"
check_step "Build Caelestia Shell" "Caelestia Shell Built and Installed"

echo -e "${GREEN}║${RST}                                                            ${GREEN}║${RST}"
echo -e "${GREEN}║${RST}  Patches applied:                                          ${GREEN}║${RST}"
check_patch "Caelestia CLI Hyprctl Mock Patch" "Caelestia CLI Hyprctl Mock Patch"
check_patch "Caelestia CLI Record/Dolphin Patch" "Caelestia CLI Record/Dolphin Patch"
check_patch "Caelestia CLI Theme Sequence Patch" "Caelestia CLI Theme Sequence Patch"

echo -e "${GREEN}║${RST}                                                            ${GREEN}║${RST}"

if [ -f "$FAILED_PKGS_FILE" ] && [ -s "$FAILED_PKGS_FILE" ]; then
    echo -e "${GREEN}║${RST}  ${RED}⚠ Failed Packages:${RST}                                     ${GREEN}║${RST}"
    while read -r pkg; do
        if [ -n "$pkg" ]; then
            printf "${GREEN}║${RST}    - ${RED}%-52s${RST} ${GREEN}║${RST}\n" "$pkg"
        fi
    done < "$FAILED_PKGS_FILE"
    echo -e "${GREEN}║${RST}                                                          ${GREEN}║${RST}"
fi

if [ -f "$FAILED_STEPS_FILE" ] && grep -qF "Build Caelestia Shell" "$FAILED_STEPS_FILE"; then
    echo -e "${GREEN}║${RST}  ${RED}⚠ SHELL BUILD FAILED!${RST}                                  ${GREEN}║${RST}"
    echo -e "${GREEN}║${RST}    Please check the terminal output / logs.              ${GREEN}║${RST}"
    echo -e "${GREEN}║${RST}    You may need to install missing dependencies          ${GREEN}║${RST}"
    echo -e "${GREEN}║${RST}    manually and re-run ./setup.sh.                       ${GREEN}║${RST}"
    echo -e "${GREEN}║${RST}                                                           ${GREEN}║${RST}"
fi

echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RST}"
echo

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo -e "${YELLOW}  ⚠  ACTION REQUIRED — Please do the following:${RST}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"
echo
echo -e "  ${MAGENTA}1. LOG OUT now${RST} and log back in."
echo -e "     A fresh login is required to fully apply all KDE and"
echo -e "     Quickshell changes."
echo -e "  ${YELLOW}WARNING:${RST}If a kernel update occured, ${YELLOW}===reboot===${RST} immediately."
echo
echo -e "  ${MAGENTA}2. REMOVE ALL KDE PANELS${RST} after logging back in."
echo -e "     Right-click the panel → \"Panel configuration\" → remove"
echo -e "     every existing KDE panel for optimal behaviour with"
echo -e "     the Quickshell bar."
echo

echo -e "  ${MAGENTA}3. TO ENTER EDIT MODE NEXT TIME${RST}"
echo -e "     Press Super+D → \"Right Click on Desktop\" → Enter Edit mode"
echo
echo -e "${CYAN}  You can re-run this installer at any time — it is idempotent.${RST}"
echo
echo -e "${CYAN}  Shortcuts not working or other problems? Check the troubleshooting steps on github."
echo -e

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
