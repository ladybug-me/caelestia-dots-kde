#!/bin/bash

# Exit on error
set -e

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
curl -fsSL https://ollama.com/install.sh | sh

# 2. Enable and start the systemd service
section "Step 2/4 - Enable and Start Ollama Daemon"
sudo systemctl enable --now ollama
echo -e "${GREEN}Ollama daemon is now running in the background.${NC}"

# 3. Prompt user to download models
section "Step 3/4 - Model Selection"
echo -e "Caelestia's AI Assistant requires at least one model. Here are some popular options:"
echo -e "  1) llama3  (Meta's highly capable model, ~4.7GB)"
echo -e "  2) phi3    (Microsoft's lightweight and fast model, ~2.3GB)"
echo -e "  3) gemma   (Google's lightweight model, ~5.2GB)"
echo -e "  4) mistral (Solid all-rounder model, ~4.1GB)"
echo -e "  5) All of the above"
echo -e "  6) Skip for now"

read -p "Select models to download [1-6]: " MODEL_CHOICE

pull_model() {
    echo -e "${BLUE}Pulling $1...${NC}"
    ollama pull "$1"
}

case $MODEL_CHOICE in
    1) pull_model "llama3" ;;
    2) pull_model "phi3" ;;
    3) pull_model "gemma" ;;
    4) pull_model "mistral" ;;
    5) 
        pull_model "llama3"
        pull_model "phi3"
        pull_model "gemma"
        pull_model "mistral"
        ;;
    6) echo -e "${YELLOW}Skipping model download. You can download models later using 'ollama pull <model>'.${NC}" ;;
    *) echo -e "${RED}Invalid selection. Skipping model download.${NC}" ;;
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
