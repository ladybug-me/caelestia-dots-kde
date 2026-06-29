#!/usr/bin/env bash
# Shared UI primitives for the Caelestia installer and uninstaller.

if [[ -n "${CAELESTIA_UI_LOADED:-}" ]]; then
    return 0
fi
CAELESTIA_UI_LOADED=1

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
WHITE="\033[1;37m"

ui_die() {
    echo -e "${RED}[ERROR] $*${RST}" >&2
    exit 1
}

ui_info() {
    echo -e "${BLUE}[INFO]  $*${RST}"
}

ui_ok() {
    echo -e "${GREEN}[OK]    $*${RST}"
}

ui_warn() {
    echo -e "${YELLOW}[WARN]  $*${RST}"
}

ui_skip() {
    echo -e "${DIM}[SKIP]  $*${RST}"
}

ui_separator() {
    local color="${1:-$BLUE}"
    local width="${2:-53}"
    local line
    line="$(printf '%*s' "$width" '' | tr ' ' '-')"
    echo -e "${color}${line}${RST}"
}

ui_section() {
    local title="$1"
    local subtitle="${2:-}"
    local color="${3:-$BLUE}"

    echo
    ui_separator "$color"
    if [[ -n "$subtitle" ]]; then
        echo -e "${color}  ${BOLD}${title}${RST} ${DIM}${subtitle}${RST}"
    else
        echo -e "${color}  ${BOLD}${title}${RST}"
    fi
    ui_separator "$color"
}

ui_prompt_yes_no() {
    local prompt="$1"
    local response

    while true; do
        read -r -p "$prompt [y/n]: " response || continue
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) ui_warn "Please enter y or n." ;;
        esac
    done
}

ui_prompt_choice() {
    local prompt="$1"
    local default="${2:-}"
    local response

    while true; do
        if [[ -n "$default" ]]; then
            read -r -p "$prompt [$default]: " response || continue
        else
            read -r -p "$prompt: " response || continue
        fi

        if [[ -n "$response" ]]; then
            printf '%s\n' "$response"
            return 0
        fi
    done
}

ui_banner() {
    echo
    ui_separator
    echo -e "${BOLD}Caelestia KDE Port${RST}"
    echo -e "Unified installer and uninstaller for the KDE Plasma port."
    echo -e "Original Hyprland dots: fufexan/dotfiles"
    echo -e "KDE port and modifications: ladybug-me"
    ui_separator
    echo
    echo -e "Existing configs are backed up automatically before changes."
    echo
}
