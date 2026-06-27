#!/bin/bash

# Ensure we fail on error
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "[INFO] Updating caelestia-shell in $DIR"
echo "--------------------------------------------------------"

echo "[STAGE 1] Syncing from Git..."
if ! git pull --rebase; then
    echo "[WARNING] git pull --rebase failed! Attempting fetch and hard reset..."
    git fetch origin
    git reset --hard origin/main
fi

echo "--------------------------------------------------------"
echo "[STAGE 2] Building Caelestia..."

# Attempt an incremental build
if ! (cmake -B build && cmake --build build -j$(nproc)); then
    echo "[WARNING] Incremental build failed. Performing full clean rebuild..."
    rm -rf build
    cmake -B build
    cmake --build build -j$(nproc)
fi

echo "--------------------------------------------------------"
echo "[STAGE 3] Installing via pkexec..."
if pkexec cmake --install "$DIR/build"; then
    echo "--------------------------------------------------------"
    echo "[SUCCESS] Update complete! Please restart Caelestia."
else
    echo "--------------------------------------------------------"
    echo "[ERROR] Installation failed."
    exit 1
fi
