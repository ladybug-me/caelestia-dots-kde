#!/bin/bash
# Install Ollama and pull the models the Caelestia assistant should start with.
#
# Non-interactive on purpose: Nexus (Settings -> AI) runs this through pkexec,
# where there is no terminal to answer a prompt, so the model list arrives as an
# argument instead of a menu (issues #654, #656).
#
#   sudo bash ollama_setup.sh                          # llama3
#   sudo bash ollama_setup.sh --models llama3,phi3
#   sudo bash ollama_setup.sh --no-models              # daemon only
#
# Installing and starting the daemon needs root. The caller elevates (pkexec or
# sudo); when this runs unprivileged from a terminal, each command goes through
# sudo instead, which is the one path that can prompt on a TTY.
#
# Strict mode, as required of everything that drives the installer:
# pipefail is the one that changes behaviour here. The Ollama installer is
# fetched with `curl | sh`, and without it a failed download pipes nothing into
# a shell that exits 0 quite happily. The script would then carry on to enable a
# service for a package that was never installed, and die there instead, with an
# error pointing at the wrong step.
set -euo pipefail

# pkexec hands the script a minimal PATH without /usr/local/bin, which is where
# the Ollama installer drops the binary - `ollama pull` below would then not be
# found even though the install just succeeded.
export PATH="/usr/local/bin:$PATH"

# llama3 is the model aiconfig.hpp ships as the default, so the assistant has
# something to talk to as soon as the install finishes.
MODELS=("llama3")

usage() {
    echo "Usage: ollama_setup.sh [--models model[,model...]] [--no-models]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --models)
            if [[ $# -lt 2 ]]; then
                echo "--models needs a value" >&2
                usage >&2
                exit 2
            fi
            IFS=',' read -r -a MODELS <<< "$2"
            shift 2
            ;;
        --no-models)
            MODELS=()
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

as_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 1. Install Ollama. The upstream installer writes to /usr/local, so it needs
# root even when the pipeline itself runs as the caller.
echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | as_root sh  # ci:allow-curl-pipe

# 2. Enable and start the systemd service
echo "Starting the Ollama daemon..."
as_root systemctl enable --now ollama

# 3. Pull the requested models through the daemon, which owns the model store -
# not through the home directory of whoever happened to run this.
echo "Preparing models..."
if [[ ${#MODELS[@]} -eq 0 ]]; then
    echo "No models requested. Pull one later with: ollama pull <model>"
else
    # systemctl returns as soon as the unit is started, which is a moment before
    # the daemon is actually listening, and `ollama pull` needs the daemon.
    for _ in {1..10}; do
        ollama list >/dev/null 2>&1 && break
        sleep 1
    done
    for model in "${MODELS[@]}"; do
        [[ -n "$model" ]] || continue
        echo "Pulling $model..."
        ollama pull "$model"
    done
fi

echo "Ollama is ready. The daemon is enabled, so it starts on boot."
