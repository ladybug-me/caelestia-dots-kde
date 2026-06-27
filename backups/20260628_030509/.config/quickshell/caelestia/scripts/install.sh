#!/usr/bin/env bash

# Caelestia Shell Installer
# This script configures, builds, and installs the shell from my fork.
# It also cleans up legacy dynamic library conflicts from old installations.
#
# Usage: install.sh [version]
#   version    Optional version string (e.g., "2.0.2"). Defaults to the latest
#              tag from https://github.com/caelestia-dots/shell if not provided.
#              Note: this only sets the version number for the build; it does
#              not download anything from the upstream repo.

set -euo pipefail

# Harmonious HSL colors for elegant premium styling output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

UPSTREAM_REPO="https://github.com/caelestia-dots/shell"

# Fetch latest version from upstream if not provided
if [ -n "${1:-}" ]; then
    VERSION="$1"
else
    echo -e "${BLUE}Fetching latest upstream tag from ${UPSTREAM_REPO}...${NC}"
    VERSION=$(git ls-remote --tags --sort=-v:refname "$UPSTREAM_REPO" 2>/dev/null | head -1 | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || echo "")
    if [ -z "$VERSION" ]; then
        echo -e "${RED}Error: Failed to fetch latest version from upstream. Please specify a version manually.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Using upstream version tag: v${VERSION}${NC}"
fi

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}           Caelestia Shell Installer                ${NC}"
echo -e "${BLUE}===================================================${NC}"

# 1. Verify working directory
if [ ! -f "CMakeLists.txt" ] || [ ! -d "plugin/src/Caelestia" ]; then
    echo -e "${RED}Error: This script must be run from the root of the caelestia repository directory!${NC}"
    exit 1
fi

# 2. Clean up the build directory for a clean state
echo -e "${BLUE}[1/4] Cleaning up old build files...${NC}"
rm -rf build

# 3. Configure the project with proper root prefix
echo -e "${BLUE}[2/4] Configuring CMake with system prefix (/)...${NC}"

CMAKE_ARGS=(
    -G Ninja
    -DCMAKE_INSTALL_PREFIX=/
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)

if [ -n "${VERSION}" ]; then
    CMAKE_ARGS+=(-DVERSION="${VERSION}")
    echo -e "${YELLOW}Building version: ${VERSION}${NC}"
fi

cmake -B build "${CMAKE_ARGS[@]}"

# 4. Build the project
echo -e "${BLUE}[3/4] Compiling QML and C++ plugins...${NC}"
cmake --build build

echo -e "${BLUE}[4/5] Compiling QMLTermWidget submodule...${NC}"
pushd plugin/src/QMLTermWidget
qmake6 .
make -j$(nproc)
popd

# 5. Clean up hijacked legacy dynamic libraries from /usr/lib
echo -e "${BLUE}[5/5] Cleaning legacy libs and installing system-wide...${NC}"
# In old versions, backing .so libraries were installed directly to component dirs,
# which hijacks the loading of the newly compiled libraries located under Caelestia/lib.
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
        echo -e "${YELLOW}Removing leftover library: $lib${NC}"
        sudo rm -f "$lib"
    fi
done

sudo cmake --install "$(pwd)/build"

echo -e "${YELLOW}Installing QMLTermWidget...${NC}"
pushd plugin/src/QMLTermWidget
sudo make install
popd

echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}          Installation Completed Successfully!      ${NC}"
echo -e "${GREEN}===================================================${NC}"
echo -e "You can now start the shell using:"
echo -e "  ${YELLOW}caelestia shell -d${NC}"
echo -e "Or kill any running shell using:"
echo -e "  ${YELLOW}caelestia shell -k${NC}"
echo -e "${GREEN}===================================================${NC}"