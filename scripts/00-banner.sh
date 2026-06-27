#!/usr/bin/env bash
# 00-banner.sh — Display the installer greeting and credits.

print_banner() {
    local CYAN="\033[38;5;87m"
    local BLUE="\033[38;5;75m"
    local MAGENTA="\033[38;5;135m"
    local PINK="\033[38;5;213m"
    local YELLOW="\033[38;5;220m"
    local WHITE="\033[1;37m"
    local DIM="\033[2m"
    local RST="\033[0m"
    local BOLD="\033[1m"

    echo -e "${MAGENTA}${BOLD}"
    cat << 'EOF'
 ✧･ﾟ: *✧･ﾟ:*  Caelestia KDE Port  *:･ﾟ✧*:･ﾟ✧
EOF
    echo -ne "${BLUE}"
    cat << 'EOF'
     ______           __          __  _       
    / ____/___ ____  / /__  _____/ /_(_)___ _ 
   / /   / __ `/ _ \/ / _ \/ ___/ __/ / __ `/ 
  / /___/ /_/ /  __/ /  __(__  ) /_/ / /_/ /  
  \____/\__,_/\___/_/\___/____/\__/_/\__,_/   
EOF
    echo -e "${RST}"
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${RST}"
    echo -e "${CYAN}║${RST}                                                                  ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}  ${WHITE}✨ Caelestia rice — KDE Plasma 6 ✨${RST}                             ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}                                                                  ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}  ${MAGENTA}🌌 Original Hyprland dots:${RST} fufexan/dotfiles                     ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}  ${BLUE}🚀 KDE port & modifications:${RST} ladybug-me                        ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}                                                                  ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}  ${DIM}Quickshell KDE bridge, Custom hyrpctl for KDE,${RST}                  ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}  ${DIM}all widgets support, Dino game with kuru kuru, Google lens,${RST}     ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}  ${DIM}custom shortcuts widget, Material You theming and more.${RST}         ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}                                                                  ${CYAN}║${RST}"
    echo -e "${CYAN}║${RST}  ${DIM}Idempotent installer — safe to run multiple times.${RST}              ${CYAN}║${RST}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${RST}"
    echo

    echo -e "  ${DIM}This installer is idempotent — safe to run multiple times.${RST}"
    echo -e "  ${DIM}Existing configs will be backed up to installer folder before any changes.${RST}"
    echo
}

print_banner
