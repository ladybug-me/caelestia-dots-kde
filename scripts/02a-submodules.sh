#!/usr/bin/env bash
# 02a-submodules.sh - Initialize git submodules

set -euo pipefail

dots_dir="$BUNDLE_DIR/src/dots"

if [[ -d "$dots_dir/fish" || -d "$dots_dir/hypr" ]]; then
    echo "[OK]    src/dots submodule already initialized."
    exit 0
fi

if command -v git >/dev/null 2>&1 && \
   git -C "$BUNDLE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
   [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
    echo "[INFO]  Initializing src/dots submodule..."
    git -C "$BUNDLE_DIR" submodule sync -- src/dots >/dev/null 2>&1 || true
    if git -C "$BUNDLE_DIR" submodule update --init --recursive src/dots; then
        echo "[OK]    Submodules initialized."
    else
        echo "[FATAL] Failed to initialize src/dots submodule." >&2
        exit 1
    fi
fi

if [[ ! -d "$dots_dir/fish" && ! -d "$dots_dir/hypr" ]]; then
    echo "[FATAL] Missing src/dots content. Run: git submodule update --init --recursive src/dots" >&2
    exit 1
fi
