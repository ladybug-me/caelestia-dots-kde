#!/usr/bin/env bash
# 02a-submodules.sh - Initialize git submodules

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/submodules.sh"

# Initialize submodules
if [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
    info "Initializing submodules..."
    prune_removed_submodules "$BUNDLE_DIR"
    git -C "$BUNDLE_DIR" submodule sync --recursive >/dev/null 2>&1 || true
    git -C "$BUNDLE_DIR" submodule update --init --recursive --depth 1 --jobs "$(nproc 2>/dev/null || echo 1)" >/dev/null 2>&1 || warn "Failed to initialize all submodules."
fi