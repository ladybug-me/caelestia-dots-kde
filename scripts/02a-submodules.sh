#!/usr/bin/env bash
# 02a-submodules.sh - Initialize git submodules

set -euo pipefail

dots_dir="$BUNDLE_DIR/src/dots"
icons_dir="$BUNDLE_DIR/shell/assets/icons/yet-another-monochrome-icon-set"

if [[ (-d "$dots_dir/fish" || -d "$dots_dir/hypr") && -e "$icons_dir/.git" ]]; then
    echo "[OK]    Submodules already initialized."
    exit 0
fi

if command -v git >/dev/null 2>&1 && \
   git -C "$BUNDLE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
   [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
    echo "[INFO]  Initializing submodules..."
    git -C "$BUNDLE_DIR" submodule sync >/dev/null 2>&1 || true
    if git -C "$BUNDLE_DIR" submodule update --init --recursive; then
        echo "[OK]    Submodules initialized."
    else
        echo "[FATAL] Failed to initialize submodules." >&2
        exit 1
    fi
fi

if [[ ! -d "$dots_dir/fish" && ! -d "$dots_dir/hypr" ]]; then
    echo "[FATAL] Missing src/dots content. Run: git submodule update --init --recursive" >&2
    exit 1
fi

if [[ ! -e "$icons_dir/.git" ]]; then
    echo "[FATAL] Missing yet-another-monochrome-icon-set content. Run: git submodule update --init --recursive" >&2
    exit 1
fi
