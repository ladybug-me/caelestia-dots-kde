#!/usr/bin/env bash
# submodules.sh - Shared helpers for git submodule maintenance.

# submodule_has_content DIR
#
# True when the submodule working tree at DIR exists and is not empty. An
# initialised-but-unfetched submodule is an empty directory, which is the state
# a checkout is left in when the fetch never happened, and the state the
# installer has to notice before it deploys anything from it.
submodule_has_content() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    [[ -n "$(ls -A "$dir" 2>/dev/null)" ]]
}

# submodule_name_for_path DIR PATH
#
# Print the name .gitmodules gives the submodule checked out at PATH, e.g.
# `caelestia` for `src/dots`. Reads the file rather than the repository, so it
# works in a checkout that is not a git repository at all.
submodule_name_for_path() {
    local dir="$1" path="$2" key name recorded

    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        name="${key#submodule.}"
        name="${name%.path}"
        recorded="$(git -C "$dir" config --file .gitmodules --get "submodule.${name}.path" 2>/dev/null || true)"
        if [[ "$recorded" == "$path" ]]; then
            printf '%s\n' "$name"
            return 0
        fi
    done < <(git -C "$dir" config --file .gitmodules --name-only \
        --get-regexp '^submodule\..*\.path$' 2>/dev/null || true)

    return 1
}

# submodule_url DIR PATH
#
# Print the URL .gitmodules records for the submodule at PATH, empty when there
# is none to find.
submodule_url() {
    local dir="$1" path="$2" name

    name="$(submodule_name_for_path "$dir" "$path")" || return 0
    [[ -n "$name" ]] || return 0
    git -C "$dir" config --file .gitmodules --get "submodule.${name}.url" 2>/dev/null || true
}

# fetch_submodule_by_clone DIR PATH
#
# Put the submodule at PATH in place by cloning its URL, for the cases
# git-submodule itself cannot handle: a checkout that is not a repository, one
# where the submodule was never registered, or a registration git refuses to
# use. The URL comes from .gitmodules, which is the one place that survives all
# of those. The clone is stripped of its .git directory so the result is content
# in the parent's working tree rather than a nested repository.
fetch_submodule_by_clone() {
    local dir="$1" path="$2" url tmp

    url="$(submodule_url "$dir" "$path")"
    [[ -n "$url" ]] || return 1
    command -v git >/dev/null 2>&1 || return 1

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/caelestia-submodule.XXXXXX")" || return 1
    if ! git clone --quiet --depth 1 -- "$url" "$tmp" >/dev/null 2>&1; then
        rm -rf "$tmp"
        return 1
    fi

    rm -rf "${dir:?}/${path:?}"
    mkdir -p "${dir:?}/${path:?}"
    if ! cp -a "$tmp/." "$dir/$path/"; then
        rm -rf "$tmp"
        return 1
    fi

    rm -rf "$dir/$path/.git" "$tmp"
    return 0
}

# ensure_submodule_content DIR PATH
#
# Make sure the submodule at PATH has its content, and put it there if it does
# not. Returns 1 when the content is still missing afterwards, so the caller can
# decide whether that is fatal.
#
# The steps go from the ordinary to the blunt, because each one covers a state
# the previous one cannot: a fetch that never ran, a URL cached in .git/config
# that has since changed upstream (sync rewrites it), a checkout whose module
# cache is in the way (force), and finally a checkout where git-submodule cannot
# be used at all.
ensure_submodule_content() {
    local dir="$1" path="$2"

    submodule_has_content "$dir/$path" && return 0

    git -C "$dir" submodule update --init --recursive -- "$path" >/dev/null 2>&1 || true
    submodule_has_content "$dir/$path" && return 0

    git -C "$dir" submodule sync --recursive -- "$path" >/dev/null 2>&1 || true
    git -C "$dir" submodule update --init --recursive -- "$path" >/dev/null 2>&1 || true
    submodule_has_content "$dir/$path" && return 0

    git -C "$dir" submodule update --init --recursive --force -- "$path" >/dev/null 2>&1 || true
    submodule_has_content "$dir/$path" && return 0

    fetch_submodule_by_clone "$dir" "$path" >/dev/null 2>&1 || true
    submodule_has_content "$dir/$path"
}

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
