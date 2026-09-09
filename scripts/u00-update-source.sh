#!/usr/bin/env bash
# u00-update-source.sh  Fetch, stash, and check out the requested branch

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
cd "$BUNDLE_DIR" || die "Could not enter $BUNDLE_DIR"

for cmd in git cmake make; do
    command -v "$cmd" &>/dev/null || die "Required command '$cmd' is missing. Please install it first."
done

if [[ ! -d "$BUNDLE_DIR/.git" ]]; then
    warn "Not a git repository. Skipping source code update."
    exit 0
fi

info "Fetching remote branches..."
git fetch origin || warn "Failed to fetch from origin. Network issue?"

STASHED=0
if ! git diff-index --quiet HEAD --; then
    warn "You have uncommitted changes in the repository."
    info "Stashing your local changes..."
    git stash -m "Auto-stash before Caelestia update" || die "Failed to stash changes."
    STASHED=1
fi

# UPDATE_BRANCH is set by the installer TUI's branch picker, or forwarded
# from update.sh's optional positional arg for non-interactive callers. With
# neither, keep whatever branch is already checked out.
BRANCH="${UPDATE_BRANCH:-}"
if [[ -z "$BRANCH" ]]; then
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    [[ -z "$BRANCH" || "$BRANCH" == "HEAD" ]] && BRANCH="main"
    info "No branch requested, using current: $BRANCH"
fi

if [[ "$BRANCH" != "main" && "$BRANCH" != "dev" ]]; then
    warn "Branch '$BRANCH' is not allowed. Falling back to main."
    BRANCH="main"
elif ! git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    warn "Remote branch '$BRANCH' not found. Falling back to main."
    BRANCH="main"
fi

info "Checking out $BRANCH..."
git checkout "$BRANCH" || die "Failed to checkout $BRANCH"

info "Pulling latest changes for $BRANCH..."
git pull origin "$BRANCH" || die "Failed to pull from origin/$BRANCH"

if [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
    info "Syncing src/dots submodule..."
    git submodule sync -- src/dots >/dev/null 2>&1 || true
    git submodule update --init --recursive src/dots || die "Failed to initialize src/dots submodule"
fi

if [[ "$STASHED" -eq 1 ]]; then
    warn "Your local uncommitted changes were backed up to the git stash to allow a clean update."
    warn "If you need to recover them, run 'git stash pop' manually."
fi

ok "Source code updated ($BRANCH)."
