#!/usr/bin/env bash
# test_install_fs.sh - Tests for scripts/lib/install-fs.sh

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib/install-fs.sh"

# Build a source tree and an already-installed destination holding different
# content, so every assertion can tell "was replaced" from "was left alone".
make_fixture() {
    local tmp="$1"
    mkdir -p "$tmp/src/contents" "$tmp/dest"
    printf 'new-greeter\n' > "$tmp/src/metadata.json"
    printf 'body\n' > "$tmp/src/contents/Main.qml"
    printf 'old-greeter\n' > "$tmp/dest/metadata.json"
}

test_atomic_replace_tree_swaps_in_the_new_tree() {
    local tmp status
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    atomic_replace_tree "$tmp/src" "$tmp/dest" metadata.json
    status=$?

    assert_status 0 "$status" "replacing a healthy tree should succeed"
    assert_eq "new-greeter" "$(cat "$tmp/dest/metadata.json")" "destination should hold the new tree"
    assert_file_exists "$tmp/dest/contents/Main.qml"
}

test_atomic_replace_tree_keeps_destination_when_copy_is_incomplete() {
    local tmp status
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    # The source is missing a file the installer requires. The destination is
    # the only working copy the user has, so it must survive untouched.
    atomic_replace_tree "$tmp/src" "$tmp/dest" does-not-exist.json
    status=$?

    assert_status 1 "$status" "an incomplete source should be rejected"
    assert_eq "old-greeter" "$(cat "$tmp/dest/metadata.json")" "destination should be left untouched"
}

test_atomic_replace_tree_keeps_destination_when_source_is_missing() {
    local tmp status
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    atomic_replace_tree "$tmp/absent" "$tmp/dest"
    status=$?

    assert_status 1 "$status" "a missing source should be rejected"
    assert_eq "old-greeter" "$(cat "$tmp/dest/metadata.json")" "destination should be left untouched"
}

test_atomic_replace_tree_creates_a_missing_destination() {
    local tmp status
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    atomic_replace_tree "$tmp/src" "$tmp/fresh/nested/dest" metadata.json
    status=$?

    assert_status 0 "$status" "a fresh install should succeed"
    assert_eq "new-greeter" "$(cat "$tmp/fresh/nested/dest/metadata.json")" "destination should be created"
}

test_atomic_replace_tree_leaves_no_staging_directories() {
    local tmp status leftovers
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    atomic_replace_tree "$tmp/src" "$tmp/dest" metadata.json
    status=$?
    assert_status 0 "$status" "replacing a healthy tree should succeed"

    atomic_replace_tree "$tmp/src" "$tmp/dest" does-not-exist.json >/dev/null 2>&1

    leftovers="$(compgen -G "$tmp/.dest.*" || true)"
    assert_eq "" "$leftovers" "staging directories should not outlive the call"
}

run_tests
