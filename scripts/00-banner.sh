#!/usr/bin/env bash
# 00-banner.sh - Display installer greeting and project credits.

print_banner() {
    local CYAN="\033[38;5;87m"
    local BLUE="\033[38;5;75m"
    local MAGENTA="\033[38;5;135m"
    local WHITE="\033[1;37m"
    local DIM="\033[2m"
    local RST="\033[0m"
    local BOLD="\033[1m"
    local BOX_WIDTH=66

    print_border() {
        printf "%b+%s+%b\n" "$CYAN" "$(printf '%*s' "$BOX_WIDTH" '' | tr ' ' '-')" "$RST"
    }

    print_row() {
        local style="$1"
        local text="$2"
        printf "%b|%b%b%-${BOX_WIDTH}s%b%b|%b\n" "$CYAN" "$RST" "$style" "$text" "$RST" "$CYAN" "$RST"
    }

    echo -e "${MAGENTA}${BOLD}"
    cat << 'EOF'
   _____            _           _   _       
  / ____|          | |         | | (_)      
 | |     __ _  ___ | | ___  ___| |_ _  __ _ 
 | |    / _` |/ _ \| |/ _ \/ __| __| |/ _` |
 | |___| (_| | (_) | |  __/\__ \ |_| | (_| |
  \_____\__,_|\___/|_|\___||___/\__|_|\__,_|
EOF
    echo -e "${RST}"

    print_border
    print_row "$WHITE" " CAELESTIA KDE PORT INSTALLER"
    print_row "$DIM"   " Target platform: KDE Plasma 6"
    print_row "$DIM"   " Original Hyprland dots: caelestia-dots"
    print_row "$DIM"   " KDE port and modifications: ladybug-me"
    print_border
    echo
}

print_banner
