#!/usr/bin/env bash
export PATH="$HOME/.local/bin:$PATH"
# ==============================================================
#   Caelestia KDE Port - Unified Updater
# ==============================================================

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/scripts/lib/privileges.sh"

section() {
    local title="$1"
    echo
    echo "-------------------------------------------------------------"
    echo "  $title"
    echo "-------------------------------------------------------------"
}

export BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BUNDLE_DIR" || die "Could not enter $BUNDLE_DIR"

# Prevent concurrent update runs from racing on git/CMake/config writes.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/caelestia-update.lock"
flock -n 9 || { echo "Another Caelestia update is already running."; exit 1; }

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

# Restore the install-time menu choices (default shell, lockscreen plugin,
# fish config, ...) that setup.sh persisted to install.env. A fresh update
# process has none of these set, so the deploy/tweak scripts would otherwise
# fall back to hardcoded defaults and silently revert the user's explicit
# install-time decisions.
if [ -f "$HOME/.config/caelestia-kde/install.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$HOME/.config/caelestia-kde/install.env"
    set +a
fi

# Root credentials are no longer requested up front. Every step that can need
# them now checks first, so an update with nothing to install asks for nothing;
# the first step that does need root prompts once, and the helper keeps that
# credential warm for the rest of the run - including GUI launches with no
# terminal, through an askpass helper.
trap 'caelestia_stop_sudo_keepalive' EXIT

# Apply config updates and rebuild the shell UI.  The native C++ plugin
# backend talks directly to KWin/Wayland — no Python daemon or mock
# hyprctl binary is involved.
bash "$BUNDLE_DIR/scripts/03-deploy-configs.sh" || die "Config deployment failed."

info "Building Caelestia Shell UI..."
bash "$BUNDLE_DIR/scripts/08-build-shell.sh" || die "Shell build failed."

# Re-apply idempotent system tweaks (KDE settings, CLI patches, etc.)
# so they survive package upgrades that may have overwritten patches.
info "Re-applying system tweaks..."
bash "$BUNDLE_DIR/scripts/09-system-tweaks.sh" || warn "System tweaks step reported errors (non-fatal)."

caelestia_stop_sudo_keepalive

section "Update Completed Successfully"
echo
info "The core shell and bridge scripts have been updated."
info "System tweaks (OSD, desktops, CLI patches) have been re-applied to keep KDE in sync."
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

# Resolve a reliable way to talk to the running shell instance.
# Prefer the (now-patched) CLI; fall back to the path-based IPC wrapper.
SHELL_IPC=""
if [[ -x "$HOME/.local/bin/caelestia-shell-ipc" ]]; then
    SHELL_IPC="$HOME/.local/bin/caelestia-shell-ipc"
fi

# Kill the running shell – try CLI first, then the IPC wrapper, then pkill.
if "$CAELESTIA_BIN" shell -k 2>/dev/null; then
    : # CLI succeeded
elif [[ -n "$SHELL_IPC" ]] && "$SHELL_IPC" quit 2>/dev/null; then
    : # IPC wrapper succeeded
else
    pkill -f "quickshell.*caelestia/shell.qml" 2>/dev/null || true
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
SCHEME_FILE="$STATE_DIR/scheme.json"
i=0
while [[ $i -lt 15 && ! -s "$SCHEME_FILE" ]]; do
    sleep 1
    i=$((i + 1))
done

# Start the shell. The IPC wrapper is preferred over the CLI here because it
# starts the shell as a transient user service: the CLI's `shell -d`
# daemonizes, which points the shell's stdio at /dev/null, and every
# application launched from the shell then inherits a stdout that goes
# nowhere. Vesktop deadlocks when a call starts in exactly that state
# (issue #402, reproducible with `vesktop >/dev/null 2>&1`).
if [[ -n "$SHELL_IPC" ]]; then
    "$SHELL_IPC" start 2>/dev/null &
elif command -v systemd-run >/dev/null 2>&1; then
    QUICKSHELL_PATH="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null || echo quickshell)"
    export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml"
    export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"
    systemd-run --user --quiet --collect --unit=caelestia-shell \
        --description="Caelestia Shell" \
        -- "$QUICKSHELL_PATH" -n -p "$HOME/.config/quickshell/caelestia/shell.qml" &
elif command -v "$CAELESTIA_BIN" >/dev/null 2>&1; then
    "$CAELESTIA_BIN" shell -d >/dev/null 2>&1 &
else
    QUICKSHELL_PATH="$(command -v quickshell 2>/dev/null || command -v qs 2>/dev/null || echo quickshell)"
    export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml"
    export CAELESTIA_LIB_DIR="$HOME/.local/lib/caelestia"
    stdbuf -oL -eL "$QUICKSHELL_PATH" -d -n -p "$HOME/.config/quickshell/caelestia/shell.qml" >/dev/null 2>&1 &
fi

echo "Shell restarted successfully!"
echo
echo "If the shell doesn't start, please restart it manually by running: $CAELESTIA_BIN shell -d"
