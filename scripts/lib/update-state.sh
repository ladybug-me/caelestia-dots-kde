#!/usr/bin/env bash
# update-state.sh - Record which revision of the shell is actually installed.
#
# Source from the build/update scripts:
#
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/update-state.sh"
#
#   record_installed_revision   Write .current_commit/.update_branch/.current_version
#
# These helpers never log; callers decide what to tell the user.

# record_installed_revision <bundle-dir> <config-dir>
#
# Record the revision the installed shell artifacts came from, so the Updates
# page and caelestia-check-updates describe what the user is actually running:
#
#   .current_commit   commit the artifacts were built from
#   .update_branch    branch that commit came from
#   .current_version  VERSION from that commit's .github/version.env
#
# Returns 1 without touching anything when there is nothing truthful to record:
#
#   - CAELESTIA_SKIP_BUILD=1: the checkout moved (a revert, or a skip-build
#     update) but the shell on screen did not, because this same flag stopped
#     the build. Writing the new revision here would make every version readout
#     claim a state the user cannot see (#651).
#   - <bundle-dir> is not a git checkout: there is no revision to name.
#
# The version is read from the working tree first and from the commit second,
# because the updater uses a sparse checkout that omits .github/version.env.
#
# It is recorded at all because the Updates page resolves unrecognized commits
# through its bare cache repo, which only mirrors origin branches: a commit
# that exists only in the local checkout would otherwise show as "unknown".
record_installed_revision() {
    local bundle="$1" config="$2"

    if [[ "${CAELESTIA_SKIP_BUILD:-0}" == "1" ]]; then
        return 1
    fi

    if [[ ! -d "$bundle/.git" ]]; then
        return 1
    fi

    mkdir -p -- "$config" || return 1

    git -C "$bundle" rev-parse HEAD > "$config/.current_commit" 2>/dev/null || {
        rm -f -- "$config/.current_commit"
        return 1
    }
    git -C "$bundle" rev-parse --abbrev-ref HEAD > "$config/.update_branch" 2>/dev/null || true

    if [[ -f "$bundle/.github/version.env" ]]; then
        cp -- "$bundle/.github/version.env" "$config/.current_version" 2>/dev/null || true
    else
        git -C "$bundle" show HEAD:.github/version.env > "$config/.current_version" 2>/dev/null || true
    fi

    return 0
}
