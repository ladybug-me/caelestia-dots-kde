#!/usr/bin/env bash
# 00-banner.sh - Display the installer greeting and credits.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-ui.sh"

ui_banner
