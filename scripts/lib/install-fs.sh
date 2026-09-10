#!/usr/bin/env bash
# install-fs.sh - Filesystem helpers for the install/update step scripts.
#
# Source from a step script (the helpers define functions only, so sourcing is
# idempotent):
#
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/install-fs.sh"
#
#   atomic_replace_tree  Swap a directory for a new copy without a window
#                        where the destination is missing or half-written
#
# These helpers never log; callers decide what to tell the user.

# atomic_replace_tree <src-dir> <dest-dir> [required-relative-path]
#
# Replace <dest-dir> with a copy of <src-dir>. The new tree is staged and
# validated next to the destination first, so a failure (missing source,
# partial copy, a required file that never arrived) leaves the existing
# destination exactly as it was. Without this, an interrupted copy strands the
# user with no working install - the failure mode reported for the lock screen
# greeter, where `rm -rf` deleted the live tree before anything had confirmed
# the replacement could be written.
#
# Returns 0 on success, 1 on failure. On failure <dest-dir> is untouched.
atomic_replace_tree() {
    local src="$1" dest="$2" required="${3:-}"

    if [[ ! -d "$src" ]]; then
        return 1
    fi

    local parent base staging previous
    parent="$(dirname -- "$dest")"
    base="$(basename -- "$dest")"

    mkdir -p -- "$parent" || return 1

    # Stage beside the destination so the final swap is a rename on the same
    # filesystem, not a cross-device copy that can fail halfway.
    staging="$(mktemp -d -- "$parent/.$base.incoming.XXXXXX")" || return 1
    if ! cp -R -- "$src/." "$staging/"; then
        rm -rf -- "$staging"
        return 1
    fi

    if [[ -n "$required" && ! -e "$staging/$required" ]]; then
        rm -rf -- "$staging"
        return 1
    fi

    previous="$parent/.$base.previous.$$"
    rm -rf -- "$previous"

    local had_dest=0
    if [[ -e "$dest" ]]; then
        had_dest=1
        if ! mv -- "$dest" "$previous"; then
            rm -rf -- "$staging"
            return 1
        fi
    fi

    if ! mv -- "$staging" "$dest"; then
        rm -rf -- "$staging"
        if [[ "$had_dest" -eq 1 ]]; then
            mv -- "$previous" "$dest" || true
        fi
        return 1
    fi

    if [[ "$had_dest" -eq 1 ]]; then
        rm -rf -- "$previous"
    fi
    return 0
}
