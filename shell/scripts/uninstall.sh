#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}          Caelestia Shell Uninstaller               ${NC}"
echo -e "${BLUE}===================================================${NC}"

if [ ! -f "CMakeLists.txt" ] || [ ! -d "plugin/src/Caelestia" ]; then
    echo -e "${RED}Error: This script must be run from the root of the caelestia repository directory!${NC}"
    exit 1
fi

echo -e "${YELLOW}This will completely remove Caelestia Shell from your system.${NC}"
echo -e "${YELLOW}The following will be deleted:${NC}"
echo -e "  - Installed QML modules (/usr/lib/qt6/qml/Caelestia/)"
echo -e "  - Installed QML modules (/usr/lib/qt6/qml/M3Shapes/)"
echo -e "  - Extras binary (/usr/lib/caelestia/)"
echo -e "  - Shell config (/etc/xdg/quickshell/caelestia/)"
echo -e "  - Build directory (./build/)"
echo
echo -e "${YELLOW}Optionally, user data can also be removed:${NC}"
echo -e "  - User config (~/.config/caelestia/)"
echo -e "  - User cache (~/.cache/caelestia/)"
echo
read -r -p "Are you sure you want to proceed? [y/N] " response
if [[ ! "$response" =~ ^[yY]$ ]]; then
    echo -e "${BLUE}Uninstall cancelled.${NC}"
    exit 0
fi

echo
echo -e "${BLUE}[1/5] Removing installed QML modules...${NC}"
if [ -d "/usr/lib/qt6/qml/Caelestia" ]; then
    sudo rm -rf "/usr/lib/qt6/qml/Caelestia"
    echo -e "${GREEN}  Removed /usr/lib/qt6/qml/Caelestia/${NC}"
fi
if [ -d "/usr/lib/qt6/qml/M3Shapes" ]; then
    sudo rm -rf "/usr/lib/qt6/qml/M3Shapes"
    echo -e "${GREEN}  Removed /usr/lib/qt6/qml/M3Shapes/${NC}"
fi

echo -e "${BLUE}[2/5] Removing extras (version binary)...${NC}"
if [ -d "/usr/lib/caelestia" ]; then
    sudo rm -rf "/usr/lib/caelestia"
    echo -e "${GREEN}  Removed /usr/lib/caelestia/${NC}"
fi

echo -e "${BLUE}[3/5] Removing shell config from /etc...${NC}"
if [ -d "/etc/xdg/quickshell/caelestia" ]; then
    sudo rm -rf "/etc/xdg/quickshell/caelestia"
    echo -e "${GREEN}  Removed /etc/xdg/quickshell/caelestia/${NC}"
fi

echo -e "${BLUE}[4/5] Cleaning up legacy libraries from old installations...${NC}"
legacy_libs=(
    "/usr/lib/qt6/qml/Caelestia/Components/libcaelestia-components.so"
    "/usr/lib/qt6/qml/Caelestia/Config/libcaelestia-config.so"
    "/usr/lib/qt6/qml/Caelestia/Internal/libcaelestia-internal.so"
    "/usr/lib/qt6/qml/Caelestia/Models/libcaelestia-models.so"
    "/usr/lib/qt6/qml/Caelestia/Services/libcaelestia-services.so"
    "/usr/lib/qt6/qml/Caelestia/Blobs/libcaelestia-blobs.so"
    "/usr/lib/qt6/qml/Caelestia/Images/libcaelestia-images.so"
    "/usr/lib/qt6/qml/Caelestia/libcaelestia.so"
)
for lib in "${legacy_libs[@]}"; do
    if [ -f "$lib" ]; then
        echo -e "${YELLOW}  Removing leftover library: $lib${NC}"
        sudo rm -f "$lib"
    fi
done

echo -e "${BLUE}[5/5] Removing local build directory...${NC}"
if [ -d "build" ]; then
    rm -rf build
    echo -e "${GREEN}  Removed ./build/${NC}"
fi

echo
read -r -p "Remove user config directory (~/.config/caelestia/)? [y/N] " response
if [[ "$response" =~ ^[yY]$ ]]; then
    if [ -d "$HOME/.config/caelestia" ]; then
        rm -rf "$HOME/.config/caelestia"
        echo -e "${GREEN}  Removed ~/.config/caelestia/${NC}"
    fi
fi

read -r -p "Remove user cache directory (~/.cache/caelestia/)? [y/N] " response
if [[ "$response" =~ ^[yY]$ ]]; then
    if [ -d "$HOME/.cache/caelestia" ]; then
        rm -rf "$HOME/.cache/caelestia"
        echo -e "${GREEN}  Removed ~/.cache/caelestia/${NC}"
    fi
fi

echo
echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}       Caelestia Shell Successfully Uninstalled!    ${NC}"
echo -e "${GREEN}===================================================${NC}"
echo -e "You may also want to remove the repository itself:"
echo -e "  ${YELLOW}rm -rf $(pwd)${NC}"
