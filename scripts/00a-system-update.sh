#!/usr/bin/env bash
# 00a-system-update.sh - System update script

set -euo pipefail

if [[ "${BASE_DISTRO:-unknown}" == "arch" ]]; then
    if [[ -n "${CONFIRM_ARG:-}" ]]; then
        sudo pacman -Syu --noconfirm
    else
        sudo pacman -Syu
    fi
elif [[ "${BASE_DISTRO:-unknown}" == "fedora" ]]; then
    if [[ -n "${CONFIRM_ARG:-}" ]]; then
        sudo dnf upgrade --refresh -y
    else
        sudo dnf upgrade --refresh
    fi
else
    echo "[WARN] Distro not set properly, skipping system update."
fi
