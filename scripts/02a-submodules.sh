#!/usr/bin/env bash
# 02a-submodules.sh - Initialize git submodules

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

# Initialize submodules
if [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
    info "Initializing submodules..."
    # Prune any submodule configured locally that was removed from .gitmodules
    while IFS= read -r -d '' key; do
        submod="${key#submodule.}"
        submod="${submod%.url}"
        if ! git -C "$BUNDLE_DIR" config --file .gitmodules --get "submodule.${submod}.url" >/dev/null 2>&1; then
            git -C "$BUNDLE_DIR" submodule deinit -f "$submod" >/dev/null 2>&1 || true
            git -C "$BUNDLE_DIR" config --remove-section "submodule.${submod}" >/dev/null 2>&1 || true
            rm -rf "$BUNDLE_DIR/.git/modules/${submod}" 2>/dev/null || true
        fi
    done < <(git -C "$BUNDLE_DIR" config --name-only -z --get-regexp '^submodule\..*\.url' 2>/dev/null || true)
    git -C "$BUNDLE_DIR" submodule sync --recursive >/dev/null 2>&1 || true
    git -C "$BUNDLE_DIR" submodule update --init --recursive --depth 1 --jobs "$(nproc 2>/dev/null || echo 1)" >/dev/null 2>&1 || warn "Failed to initialize all submodules."
fi