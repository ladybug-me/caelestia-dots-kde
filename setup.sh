#!/usr/bin/env bash
# ==============================================================
#   Caelestia KDE Port - Unified Installer
#
#   Original Hyprland dots: Caelestia
#   KDE port and modifications: ladybug-me
#   Installer behavior: idempotent and safe for reruns
# ==============================================================

set -uo pipefail

# Hide cursor immediately for cleaner output
tput civis 2>/dev/null || true

# -- Paths ---------------------------------------------------------------------
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$BUNDLE_DIR/scripts"
export BUNDLE_DIR
export INSTALL_START_EPOCH="$(date +%s)"

normalize_line_endings_first() {
    export BASE_DISTRO="unknown"
    local -a crlf_files=()
    local convert_choice=""

    if [[ -f /etc/os-release ]]; then
       # shellcheck disable=SC1091
        . /etc/os-release
        case "$ID" in
            arch|cachyos|endeavouros|manjaro|artix)
                BASE_DISTRO="arch"
                ;;
            fedora|nobara|bazzite|rhel|centos|almalinux|rocky)
                BASE_DISTRO="fedora"
                ;;
            *)
                if echo "${ID_LIKE:-}" | grep -iq "arch"; then
                    BASE_DISTRO="arch"
                elif echo "${ID_LIKE:-}" | grep -iq "fedora"; then
                    BASE_DISTRO="fedora"
                fi
                ;;
        esac
    fi

    if [[ "$BASE_DISTRO" == "unknown" ]]; then
        if command -v pacman >/dev/null 2>&1; then
            BASE_DISTRO="arch"
        elif command -v dnf >/dev/null 2>&1; then
            BASE_DISTRO="fedora"
        fi
    fi
    mapfile -t crlf_files < <(
        find "$BUNDLE_DIR" -path "$BUNDLE_DIR/.git" -prune -o -type f -print0 | \
            xargs -0 grep -Il $'\r' 2>/dev/null || true
    )

    if (( ${#crlf_files[@]} == 0 )); then
        return 0
    fi

    echo "[WARN]  Detected ${#crlf_files[@]} file(s) with CRLF line endings."
    while true; do
        read -r -p "Convert all files under this repo to LF with dos2unix? [Y/n]: " convert_choice
        convert_choice="${convert_choice:-y}"

        case "${convert_choice,,}" in
            y|yes)
                if ! command -v dos2unix >/dev/null 2>&1; then
                    echo "[WARN]  dos2unix is not installed. Attempting to install it now..."
                    case "$BASE_DISTRO" in
                        arch)
                            sudo pacman -S --needed --noconfirm dos2unix || return 1
                            ;;
                        fedora)
                            sudo dnf install -y dos2unix || return 1
                            ;;
                        *)
                            echo "[WARN]  Could not detect distro for automatic dos2unix installation."
                            return 1
                            ;;
                    esac
                    echo "[OK]    dos2unix installed."
                fi

                (
                    cd "$BUNDLE_DIR" || exit 1
                    printf '%s\0' "${crlf_files[@]}" | xargs -0 -r dos2unix --
                ) || return 1

                echo "[OK]    Line endings normalized to LF."
                return 0
                ;;
            n|no)
                echo "[WARN]  Skipping line ending normalization by user choice."
                return 0
                ;;
            *)
                echo "Please answer with y or n."
                ;;
        esac
    done
}

if ! normalize_line_endings_first; then
    echo "[FATAL] Line ending normalization step failed. Aborting installer." >&2
    exit 1
fi

BIN="$BUNDLE_DIR/caelestia-install"

if [[ "${CAELESTIA_TMUX_MASTER:-0}" == "0" ]]; then
    echo -n "Compiling Caelestia installer"
    {
        while true; do
            printf "."
            sleep 0.5
            printf "."
            sleep 0.5
            printf "."
            sleep 0.5
            printf "\b\b\b   \b\b\b"
        done
    } &
    SPINNER_PID=$!

    # Check and install requirements
    MISSING_PKGS=()
    if ! command -v g++ >/dev/null 2>&1; then
        MISSING_PKGS+=("g++")
    fi
    if ! command -v cmake >/dev/null 2>&1; then
        MISSING_PKGS+=("cmake")
    fi
    if ! command -v make >/dev/null 2>&1; then
        MISSING_PKGS+=("make")
    fi
    if ! command -v tmux >/dev/null 2>&1; then
        MISSING_PKGS+=("tmux")
    fi

    if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
        kill $SPINNER_PID 2>/dev/null || true
        echo ""
        echo "Missing build tools: ${MISSING_PKGS[*]}. Installing..."
        if [[ "$BASE_DISTRO" == "arch" ]]; then
            sudo pacman -S --needed --noconfirm base-devel cmake tmux
        elif [[ "$BASE_DISTRO" == "fedora" ]]; then
            sudo dnf install -y gcc-c++ cmake make tmux
        else
            echo "Could not auto-install build tools. Please install manually: ${MISSING_PKGS[*]}"
            exit 1
        fi
        echo -n "Compiling Caelestia installer"
        {
            while true; do
                printf "."
                sleep 0.5
                printf "."
                sleep 0.5
                printf "."
                sleep 0.5
                printf "\b\b\b   \b\b\b"
            done
        } &
        SPINNER_PID=$!
    fi

    BUILD_DIR="$BUNDLE_DIR/installer/build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    (
        cd "$BUILD_DIR" || exit 1
        cmake -DCMAKE_BUILD_TYPE=Release .. >/dev/null 2>&1 || exit 1
        make -j"$(nproc 2>/dev/null || echo 1)" >/dev/null 2>&1 || exit 1
    ) || {
        kill $SPINNER_PID 2>/dev/null || true
        echo ""
        echo "[FATAL] Failed to build the Caelestia installer." >&2
        exit 1
    }
    
    kill $SPINNER_PID 2>/dev/null || true
    wait $SPINNER_PID 2>/dev/null || true
    echo ""

    rm -f "$BIN"
    cp "$BUILD_DIR/caelestia-install" "$BIN" || {
        echo "[FATAL] Failed to copy the compiled Caelestia installer to $BIN." >&2
        exit 1
    }
fi

cleanup_install_state() {
    tput cnorm 2>/dev/null || true
    if [[ -f /tmp/caelestia_inhibit.pid ]]; then
        kill -9 "$(cat /tmp/caelestia_inhibit.pid)" 2>/dev/null || true
    fi
    if [[ -f /tmp/caelestia_kde_inhibit.cookie ]]; then
        qdbus6 org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver.UnInhibit "$(cat /tmp/caelestia_kde_inhibit.cookie)" 2>/dev/null || true
    fi
    rm -f /tmp/caelestia_inhibit.pid /tmp/caelestia_kde_inhibit.cookie
    
    if [[ -n "${TMUX:-}" && "${CAELESTIA_TMUX_MASTER:-0}" == "1" ]]; then
        tmux kill-session -t caelestia_install 2>/dev/null || true
        rm -f /tmp/caelestia_cmd /tmp/caelestia_status
    fi
}
trap cleanup_install_state EXIT

if [[ -z "${TMUX:-}" && "${CAELESTIA_NO_TMUX:-0}" == "0" ]]; then
    # Kill any stale session first
    tmux kill-session -t caelestia_install 2>/dev/null || true
    
    export CAELESTIA_TMUX_MASTER=1
    rm -f /tmp/caelestia_cmd /tmp/caelestia_status
    mkfifo /tmp/caelestia_cmd
    mkfifo /tmp/caelestia_status
    
    tmux new-session -d -s caelestia_install "bash \"$0\" $@"
    tmux set-option -t caelestia_install mouse on
    
    tmux attach-session -t caelestia_install
    exit $?
fi

"$BIN" "$@"
exit $?
