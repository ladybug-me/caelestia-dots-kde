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
#   snapshot_dir         Timestamped copy of a directory, pruned to a limit
#   wait_for_nonempty_file  Block until a file the shell writes shows up
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

# snapshot_dir <src-dir> <dest-root> <name-prefix> <keep>
#
# Copy <src-dir> to <dest-root>/<name-prefix>-<timestamp> and prune older
# snapshots so at most <keep> remain. Echoes the snapshot path on success.
#
# Returns 1 without copying anything when <src-dir> does not exist: there is
# nothing to preserve, and creating an empty snapshot would push a real one out
# of the retention window.
snapshot_dir() {
    local src="$1" root="$2" prefix="$3" keep="$4"

    [[ -d "$src" ]] || return 1
    mkdir -p -- "$root" || return 1

    # Snapshots taken within the same second would otherwise collide, and the
    # caller would silently overwrite the one it just took.
    local stamp dest counter
    stamp="$(date +%Y%m%d_%H%M%S)"
    dest="$root/$prefix-$stamp"
    counter=1
    while [[ -e "$dest" ]]; do
        counter=$((counter + 1))
        dest="$root/$prefix-$stamp-$(printf '%02d' "$counter")"
    done

    if ! cp -R -- "$src" "$dest"; then
        rm -rf -- "$dest"
        return 1
    fi

    # Zero-padded in case a caller asks not to prune; the suffix keeps names in
    # creation order so the newest snapshots are the ones that survive.
    local -a existing=()
    shopt -s nullglob
    existing=( "$root"/"$prefix"-* )
    shopt -u nullglob

    local total=${#existing[@]}
    local limit=$keep
    ((limit < 1)) && limit=1
    local index
    for ((index = 0; index < total - limit; index++)); do
        rm -rf -- "${existing[$index]}"
    done

    printf '%s\n' "$dest"
    return 0
}

# wait_for_nonempty_file <path> <timeout-seconds>
#
# Wait for <path> to exist and hold something. Returns 0 as soon as it does,
# 1 once <timeout-seconds> have elapsed without it. A timeout of 0 makes the
# check once and reports what it found, which is what callers want when the
# file is usually already there.
#
# Emptiness counts as absent: the consumers of these files parse them, and a
# zero-byte file left behind by an interrupted write is not usable.
wait_for_nonempty_file() {
    local path="$1" timeout="$2" waited=0

    while :; do
        if [[ -s "$path" ]]; then
            return 0
        fi
        if (( waited >= timeout )); then
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done
}
