#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
# ==============================================================
#   Caelestia KDE Port - Unified Updater
# ==============================================================

set -uo pipefail

die()  { echo "[FATAL] $*" >&2; exit 1; }
info() { echo "[INFO]  $*"; }
ok()   { echo "[OK]    $*"; }
warn() { echo "[WARN]  $*"; }

section() {
    local title="$1"
    echo
    echo "-------------------------------------------------------------"
    echo "  $title"
    echo "-------------------------------------------------------------"
}

export BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BUNDLE_DIR" || die "Could not enter $BUNDLE_DIR"

section "Step 1 - Source Code Update"

info "Checking dependencies..."
for cmd in git cmake make; do
    if ! command -v "$cmd" &> /dev/null; then
        die "Required command '$cmd' is missing. Please install it first."
    fi
done

if [ -d "$BUNDLE_DIR/.git" ]; then
    info "Fetching remote branches..."
    git -C "$BUNDLE_DIR" fetch origin || warn "Failed to fetch from origin. Network issue?"

    STASHED=0
    # Safely stash uncommitted changes to avoid merge conflicts
    if ! git -C "$BUNDLE_DIR" diff-index --quiet HEAD --; then
        warn "You have uncommitted changes in the repository."
        info "Stashing your local changes..."
        git -C "$BUNDLE_DIR" stash -m "Auto-stash before Caelestia update" || die "Failed to stash changes."
        STASHED=1
    fi

    if [ -n "${1:-}" ]; then
        BRANCH="$1"
        if [[ "$BRANCH" != "main" && "$BRANCH" != "dev" ]]; then
            warn "Branch '$BRANCH' is not allowed. Falling back to main."
            BRANCH="main"
        fi
        info "Using provided branch: $BRANCH"
    else
        if [ -t 1 ]; then
            BRANCHES="main dev"
            echo
            info "Available remote branches (default: main):"
            select BRANCH in $BRANCHES; do
                if [ -z "$REPLY" ]; then
                    BRANCH="main"
                    info "Defaulted to branch: $BRANCH"
                    break
                elif [ -n "$BRANCH" ]; then
                    info "Selected branch: $BRANCH"
                    break
                else
                    warn "Invalid selection. Please enter a valid number or press Enter for main."
                fi
            done
        else
            BRANCH=$(git -C "$BUNDLE_DIR" rev-parse --abbrev-ref HEAD)
            if [ -z "$BRANCH" ] || [ "$BRANCH" == "HEAD" ]; then
                BRANCH="main"
            fi
            info "Auto-detected branch: $BRANCH (GUI Mode)"
        fi
    fi

    if [[ "$BRANCH" != "main" && "$BRANCH" != "dev" ]]; then
        warn "Branch '$BRANCH' is not allowed. Falling back to main."
        BRANCH="main"
    elif ! git -C "$BUNDLE_DIR" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
        warn "Remote branch '$BRANCH' not found. Falling back to main."
        BRANCH="main"
    fi

    info "Checking out $BRANCH..."
    git -C "$BUNDLE_DIR" checkout "$BRANCH" || die "Failed to checkout $BRANCH"

    info "Pulling latest changes for $BRANCH..."
    git -C "$BUNDLE_DIR" pull origin "$BRANCH" || die "Failed to pull from origin/$BRANCH"

    if [[ -f "$BUNDLE_DIR/.gitmodules" ]]; then
        info "Syncing src/dots submodule..."
        git -C "$BUNDLE_DIR" submodule sync -- src/dots >/dev/null 2>&1 || true
        git -C "$BUNDLE_DIR" submodule update --init --recursive src/dots || \
            die "Failed to initialize src/dots submodule"
    fi

    if [ "$STASHED" -eq 1 ]; then
        echo
        warn "Your local uncommitted changes were backed up to the git stash to allow a clean update."
        warn "If you need to recover them, you can manually run 'git stash pop' later."
    fi
else
    warn "Not a git repository. Skipping source code update."
fi

section "Step 2 - Core Updates"

if [ ! -f "$BUNDLE_DIR/scripts/03-deploy-configs.sh" ] || [ ! -f "$BUNDLE_DIR/scripts/08-build-shell.sh" ]; then
    die "Critical internal scripts are missing from $BUNDLE_DIR/scripts/"
fi

# Robust Privilege Escalation for GUI and Terminal
run_elevated() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif [ -t 1 ]; then
        sudo "$@"
    elif command -v ksshaskpass &> /dev/null; then
        SUDO_ASKPASS=$(command -v ksshaskpass) sudo -A "$@"
    elif command -v pkexec &> /dev/null; then
        pkexec "$@"
    else
        die "Cannot elevate privileges. Please install ksshaskpass, pkexec, or run from a terminal."
    fi
}

info "We will deploy core configs and KDE bridges. A password prompt may appear."

# This script deploys Python bridges and mock hyprctl which the shell needs
# Execute normally; any internal sudo calls will trigger prompts automatically
bash "$BUNDLE_DIR/scripts/03-deploy-configs.sh" || die "Config deployment failed."

info "Building Caelestia Shell UI..."
bash "$BUNDLE_DIR/scripts/08-build-shell.sh" || die "Shell build failed."

section "Update Completed Successfully"
echo
info "The core shell and bridge scripts have been updated without touching your personal KDE settings."
echo
echo "Restarting bridge and shell to apply changes..."

if command -v caelestia >/dev/null 2>&1; then
    CAELESTIA_BIN=$(command -v caelestia)
elif [[ -x "$HOME/.local/bin/caelestia" ]]; then
    CAELESTIA_BIN="$HOME/.local/bin/caelestia"
elif [[ -x "/usr/local/bin/caelestia" ]]; then
    CAELESTIA_BIN="/usr/local/bin/caelestia"
elif [[ -x "/usr/bin/caelestia" ]]; then
    CAELESTIA_BIN="/usr/bin/caelestia"
else
    CAELESTIA_BIN="caelestia"
fi

systemctl --user restart qs-kwin-bridge.service 2>/dev/null || true
"$CAELESTIA_BIN" shell -k 2>/dev/null || true
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
SCHEME_FILE="$STATE_DIR/scheme.json"
i=0
while [[ $i -lt 15 && ! -s "$SCHEME_FILE" ]]; do
    sleep 1
    i=$((i + 1))
done
"$CAELESTIA_BIN" shell -d >/dev/null 2>&1 &
echo "Shell restarted successfully!"
echo
echo "If the shell doesn't start, please restart it manually by running: $CAELESTIA_BIN shell -d"
