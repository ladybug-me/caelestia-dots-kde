#!/bin/bash

# Strict mode, as required of everything under scripts/.
#
# pipefail is the one that changes behaviour here: the Ollama installer is
# fetched with `curl | sh`, and without it a failed download pipes nothing into
# a shell that exits 0 quite happily. The script would then carry on to enable a
# service for a package that was never installed, and die there instead, with an
# error pointing at the wrong step.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/prompt.sh"

# Harmonious HSL colors for elegant premium styling output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

section() {
    local title="$1"
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE} ${title}${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

section "Ollama AI Setup for Caelestia"

# 1. Install Ollama
section "Step 1/4 - Install Ollama"
curl -fsSL https://ollama.com/install.sh | sh  # ci:allow-curl-pipe

# 2. Enable and start the systemd service
section "Step 2/4 - Enable and Start Ollama Daemon"
sudo systemctl enable --now ollama
echo -e "${GREEN}Ollama daemon is now running in the background.${NC}"

# 3. Prompt user to download models
section "Step 3/4 - Model Selection"
echo -e "Caelestia's AI Assistant requires at least one model. Here are some popular options:"

MODEL_CHOICE="$(choose "Select models to download:" "llama3 (Meta's model, ~4.7GB)" "phi3 (lightweight and fast, ~2.3GB)" "gemma (Google's model, ~5.2GB)" "mistral (all-rounder, ~4.1GB)" "All of the above" "Skip for now" || true)"

pull_model() {
    echo -e "${BLUE}Pulling $1...${NC}"
    ollama pull "$1"
}

case "$MODEL_CHOICE" in
    llama3*)  pull_model "llama3" ;;
    phi3*)    pull_model "phi3" ;;
    gemma*)   pull_model "gemma" ;;
    mistral*) pull_model "mistral" ;;
    "All of the above")
        pull_model "llama3"
        pull_model "phi3"
        pull_model "gemma"
        pull_model "mistral"
        ;;
    *)
        echo -e "${YELLOW}Skipping model download. You can download models later using 'ollama pull <model>'.${NC}"
        ;;
esac

# 4. Final configuration and setup
section "Step 4/4 - Finalize Setup"
echo -e "Setting up autostart for Ollama with Caelestia Shell."
# Note: Since the systemd service is enabled globally, it will start automatically on boot.
# If a user-level service is preferred in the future, we can configure systemd --user.

echo -e "\n${GREEN}===================================================${NC}"
echo -e "${GREEN}          Ollama Setup Completed Successfully!      ${NC}"
echo -e "${GREEN}===================================================${NC}"
echo -e "Caelestia's AI assistant is now ready to use."
echo -e "Open the sidebar in the shell and start chatting!"
echo -e "${GREEN}===================================================${NC}"
