#!/usr/bin/env bash
# submodules.sh - Shared helpers for git submodule maintenance.

# prune_removed_submodules DIR
#
# Remove every submodule that is still registered in .git/config (local clone
# state) but is no longer listed in .gitmodules (i.e. it was deleted upstream).
#
# git-submodule deinit fails with "No submodule mapping found in .gitmodules"
# once the entry has been removed from that file, so the command is allowed to
# fail.  The important cleanup steps — removing the cached entry from
# .git/config and the module cache under .git/modules/<name> — are performed
# explicitly afterwards.  The worktree directory is also removed because deinit
# only empties it; it does not delete it.
prune_removed_submodules() {
    local dir="$1"

    while IFS= read -r -d '' key; do
        local submod="${key#submodule.}"
        submod="${submod%.url}"
        if ! git -C "$dir" config --file .gitmodules --get "submodule.${submod}.url" \
                >/dev/null 2>&1; then
            # Resolve the worktree path before deinit removes any knowledge of it.
            local wt_path
            wt_path=$(git -C "$dir" config --get "submodule.${submod}.path" 2>/dev/null \
                || echo "$submod")

            # deinit may fail when .gitmodules no longer knows the path; || true is
            # intentional — the manual steps below do the real work.
            git -C "$dir" submodule deinit -f "$submod" >/dev/null 2>&1 || true

            # Remove the stale .git/config section.
            git -C "$dir" config --remove-section "submodule.${submod}" \
                >/dev/null 2>&1 || true

            # Remove the cached module objects.
            rm -rf "$dir/.git/modules/${submod}"

            # Remove the leftover worktree checkout (deinit only empties, never
            # deletes the directory).
            rm -rf "${dir:?}/${wt_path:?}"
        fi
    done < <(git -C "$dir" config --name-only -z \
        --get-regexp '^submodule\..*\.url' 2>/dev/null || true)
}
