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

test_snapshot_dir_copies_the_tree_and_reports_the_path() {
    local tmp status dest
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    dest="$(snapshot_dir "$tmp/src" "$tmp/backups" "quickshell-caelestia" 3)"
    status=$?

    assert_status 0 "$status" "snapshotting an existing directory should succeed"
    assert_eq "new-greeter" "$(cat "$dest/metadata.json")" "snapshot should hold a copy of the source"
    assert_eq "$tmp/backups" "$(dirname "$dest")" "snapshot should live under the requested root"
    assert_contains "$(basename "$dest")" "quickshell-caelestia-" "snapshot name should carry the requested prefix"
}

test_snapshot_dir_reports_nothing_when_there_is_nothing_to_snapshot() {
    local tmp status dest
    tmp="$(new_tmpdir)"

    dest="$(snapshot_dir "$tmp/absent" "$tmp/backups" "quickshell-caelestia" 3)"
    status=$?

    assert_status 1 "$status" "a missing source directory is not an error worth a snapshot"
    assert_eq "" "$dest" "no path should be reported when nothing was copied"
}

test_snapshot_dir_keeps_only_the_requested_number_of_snapshots() {
    local tmp status i remaining
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    for i in 1 2 3 4 5; do
        printf 'revision-%s\n' "$i" > "$tmp/src/metadata.json"
        snapshot_dir "$tmp/src" "$tmp/backups" "quickshell-caelestia" 3 >/dev/null
    done
    status=$?

    assert_status 0 "$status" "repeated snapshots should succeed"
    remaining="$(compgen -G "$tmp/backups/quickshell-caelestia-*" | wc -l | tr -d ' ')"
    assert_eq "3" "$remaining" "pruning should keep exactly three snapshots"
}

test_snapshot_dir_keeps_the_newest_snapshot_when_pruning() {
    local tmp newest
    tmp="$(new_tmpdir)"
    make_fixture "$tmp"

    snapshot_dir "$tmp/src" "$tmp/backups" "quickshell-caelestia" 2 >/dev/null
    printf 'revision-2\n' > "$tmp/src/metadata.json"
    newest="$(snapshot_dir "$tmp/src" "$tmp/backups" "quickshell-caelestia" 2)"

    assert_file_exists "$newest"
    assert_eq "revision-2" "$(cat "$newest/metadata.json")" "pruning should never remove the newest snapshot"
}

run_tests
