#!/usr/bin/env bash
# 02a-submodules.sh - Initialize git submodules

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/submodules.sh"

# Resolve the bundle root the same way the other steps do, so this can also be
# run on its own to repair a checkout that is missing its submodule content.
BUNDLE_DIR="${BUNDLE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Initialize submodules
if [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
    info "Initializing submodules..."
    prune_removed_submodules "$BUNDLE_DIR"
    git -C "$BUNDLE_DIR" submodule sync --recursive >/dev/null 2>&1 || true
    git -C "$BUNDLE_DIR" submodule update --init --recursive --depth 1 --jobs "$(nproc 2>/dev/null || echo 1)" >/dev/null 2>&1 || warn "Failed to initialize all submodules."
fi

# An update that fails quietly leaves this step green and defers the failure to
# whichever step reads the files first, which is 03-deploy-configs.sh several
# steps later and says nothing about submodules. So the content is checked here,
# and fetched another way if the update did not produce it.
#
# src/dots holds the configuration files 03 deploys: without it there is nothing
# to install, so a failure to fetch it is fatal.
if ! submodule_has_content "$BUNDLE_DIR/src/dots"; then
    warn "src/dots is empty; trying to fetch it directly."
    if ! ensure_submodule_content "$BUNDLE_DIR" "src/dots"; then
        err "src/dots is still empty, and the installer cannot deploy without it."
        cat >&2 <<EOF

          Fetch it by hand:

            git -C "$BUNDLE_DIR" submodule update --init --recursive src/dots

          Running this step on its own tries again:

            bash "$BUNDLE_DIR/scripts/02a-submodules.sh"

          A checkout that cannot be written to cannot fetch a submodule. If
          this one is the read-only shared folder, clone the repository to a
          writable directory first and install from there.
EOF
        exit 1
    fi
    ok "src/dots fetched."
fi

# The icon set only affects a monochrome icon theme, which 08-build-shell.sh
# warns about on its own, so a missing one must not stop an install.
if ! submodule_has_content "$BUNDLE_DIR/src/yet-another-monochrome-icon-set"; then
    warn "src/yet-another-monochrome-icon-set is empty; trying to fetch it directly."
    if ensure_submodule_content "$BUNDLE_DIR" "src/yet-another-monochrome-icon-set"; then
        ok "Icon set fetched."
    else
        warn "Icon set could not be fetched; the monochrome icon theme will be missing."
    fi
fi
