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
    git -C "$BUNDLE_DIR" submodule update --init --recursive --depth 1 --jobs "$(nproc 2>/dev/null || echo 1)" >/dev/null 2>&1 || true
fi

# That update is one way to get the content, and the one that fails most
# quietly: a shallow fetch can miss the recorded commit, and a checkout that is
# not a repository cannot run it at all. What matters is whether the content is
# there afterwards, so that is what decides this step's status. A failure of
# this particular command is not a warning when another route works, and the
# step failing quietly here used to surface as 03-deploy-configs.sh complaining
# about missing files several steps later.
#
# src/dots holds the configuration files 03 deploys: without it there is nothing
# to install, so failing to fetch it is fatal.
if ! submodule_has_content "$BUNDLE_DIR/src/dots"; then
    info "src/dots is empty; fetching it another way."
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
fi

ok "src/dots ready."

# The icon set only affects a monochrome icon theme, which 08-build-shell.sh
# warns about on its own, so a missing one must not stop an install.
if ! submodule_has_content "$BUNDLE_DIR/src/yet-another-monochrome-icon-set"; then
    info "src/yet-another-monochrome-icon-set is empty; fetching it another way."
    if ensure_submodule_content "$BUNDLE_DIR" "src/yet-another-monochrome-icon-set"; then
        ok "Icon set ready."
    else
        warn "Icon set could not be fetched; the monochrome icon theme will be missing."
    fi
fi
