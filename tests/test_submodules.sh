#!/usr/bin/env bash
# test_submodules.sh - Tests for scripts/lib/submodules.sh

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/submodules.sh"

require_git() {
    if command -v git >/dev/null 2>&1; then
        return 0
    fi
    skip_test "git is not installed"
    return 1
}

# make_repo <dir>
#
# A throwaway checkout with one commit, so git is willing to operate on it.
make_repo() {
    local repo="$1"
    git init -q "$repo"
    git -C "$repo" -c user.email=test@example.com -c user.name=Test \
        commit -q --allow-empty -m "init"
}

# register_submodule <repo> <name> <path>
#
# Reproduces what `git submodule init` leaves behind for a submodule that has
# since been deleted upstream: the local registration in .git/config plus the
# module cache and the worktree checkout on disk. `git submodule deinit` cannot
# clean this up, because it resolves the path through .gitmodules and fails
# once the entry is gone - which is the state prune_removed_submodules exists
# for.
register_submodule() {
    local repo="$1" name="$2" path="$3"
    git -C "$repo" config "submodule.$name.url" "https://example.invalid/$name.git"
    git -C "$repo" config "submodule.$name.path" "$path"
    mkdir -p "$repo/$path" "$repo/.git/modules/$name"
    printf 'stale\n' > "$repo/$path/stale-file"
    printf 'stale\n' > "$repo/.git/modules/$name/stale-file"
}

test_prune_removes_the_worktree_and_registration_of_a_deleted_submodule() {
    require_git || return 0
    local tmp repo status
    tmp="$(new_tmpdir)"
    repo="$tmp/repo"
    make_repo "$repo"
    printf '[submodule "keep"]\n\tpath = keep\n\turl = https://example.invalid/keep.git\n' \
        > "$repo/.gitmodules"
    register_submodule "$repo" keep keep
    register_submodule "$repo" gone gone

    prune_removed_submodules "$repo"
    status=$?

    assert_status 0 "$status" "pruning should succeed"
    assert_file_missing "$repo/gone" "the worktree checkout of the deleted submodule should be removed"
    assert_file_missing "$repo/.git/modules/gone" "the module cache of the deleted submodule should be removed"
    git -C "$repo" config --get submodule.gone.url >/dev/null 2>&1
    assert_status 1 "$?" "the stale .git/config registration should be removed"

    assert_is_dir "$repo/keep" "a submodule still listed in .gitmodules must survive"
    assert_is_dir "$repo/.git/modules/keep" "a live submodule must keep its module cache"
    assert_eq "keep" "$(git -C "$repo" config --get submodule.keep.path)" \
        "a submodule still listed in .gitmodules must keep its registration"
}

test_prune_resolves_the_worktree_path_from_the_local_registration() {
    require_git || return 0
    local tmp repo
    tmp="$(new_tmpdir)"
    repo="$tmp/repo"
    make_repo "$repo"
    : > "$repo/.gitmodules"
    # Name and worktree path differ (a nested submodule), so the path can only
    # come from .git/config.
    register_submodule "$repo" dots src/dots

    prune_removed_submodules "$repo"

    assert_file_missing "$repo/src/dots" "the nested worktree checkout should be removed"
    assert_is_dir "$repo/src" "the parent directory of the checkout must not be removed"
    assert_file_missing "$repo/.git/modules/dots" "the module cache should be removed"
}

test_prune_is_a_no_op_without_local_registrations() {
    require_git || return 0
    local tmp repo status
    tmp="$(new_tmpdir)"
    repo="$tmp/repo"
    make_repo "$repo"
    printf '[submodule "keep"]\n\tpath = keep\n\turl = https://example.invalid/keep.git\n' \
        > "$repo/.gitmodules"
    mkdir -p "$repo/keep"

    prune_removed_submodules "$repo"
    status=$?

    assert_status 0 "$status" "a checkout that was never submodule-initialized should still succeed"
    assert_is_dir "$repo/keep" "a submodule that is not registered locally must not be touched"
}

run_tests
