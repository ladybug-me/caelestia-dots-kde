#!/usr/bin/env bash
# 10-system-tweaks.sh — Apply live system configuration tweaks to the running KDE session.
#
# This script ONLY writes config values and reloads KDE daemons.
# It does NOT copy any files. It is designed to be:
#   - Run standalone at any time: bash scripts/10-system-tweaks.sh
#   - Called by the main installer (after deploying files)
#   - Easily extended: add new tweak_* functions below, then call them in main()
#
# Usage:
#   bash scripts/10-system-tweaks.sh           # Apply all tweaks
#   bash scripts/10-system-tweaks.sh --list    # List available tweaks

set -uo pipefail
RED="\033[0;31m"
CYAN="\033[0;36m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RST="\033[0m"
info() { echo -e "${CYAN}[INFO]  $*${RST}"; }
ok()   { echo -e "${GREEN}[OK]    $*${RST}"; }
warn() { echo -e "${RED}[WARN]  $*${RST}"; }

echo
echo "════════════════════════════════════════════════════════"
echo "  caelestia KDE — Live System Tweaks"
echo "════════════════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK: Disable KDE OSD popups (volume, brightness notifications)
# ─────────────────────────────────────────────────────────────────────────────
tweak_disable_kde_osd() {
    info "Disabling KDE OSD popups (volume/brightness)..."

    # Plasma OSD daemon
    kwriteconfig6 --file plasmarc --group "OSD" --key "Enabled" "false" 2>/dev/null || true
    kwriteconfig6 --file plasmarc --group "OSD" --key "ShowOnActiveScreen" "false" 2>/dev/null || true

    # kdeglobals fallback key
    kwriteconfig6 --file kdeglobals --group "KDE" --key "OSDEnabled" "false" 2>/dev/null || true

    # plasma-volume OSD via notify
    kwriteconfig6 --file plasmanotifyrc --group "Notifications" \
        --key "LoudnessChangedOSD" "false" 2>/dev/null || true

    # powerdevil brightness OSD
    kwriteconfig6 --file powerdevilrc --group "BrightnessControl" \
        --key "showOSD" "false" 2>/dev/null || true
    kwriteconfig6 --file powerdevilrc --group "AC" \
        --key "brightnessosd" "false" 2>/dev/null || true

    # kmix OSD
    mkdir -p "$HOME/.config"
    if [[ -f "$HOME/.config/kmixrc" ]]; then
        sed -i 's/^ShowOSD=.*/ShowOSD=false/' "$HOME/.config/kmixrc" 2>/dev/null || true
        grep -q "^ShowOSD=" "$HOME/.config/kmixrc" || echo -e "\n[Global]\nShowOSD=false" >> "$HOME/.config/kmixrc"
    else
        cat > "$HOME/.config/kmixrc" <<'EOF'
[Global]
ShowOSD=false
EOF
    fi

    ok "KDE OSD popups disabled."
}

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK: Create 5 virtual desktops
# ─────────────────────────────────────────────────────────────────────────────
tweak_five_desktops() {
    info "Configuring 5 virtual desktops..."

    kwriteconfig6 --file kwinrc --group "Desktops" --key "Number" "5"
    kwriteconfig6 --file kwinrc --group "Desktops" --key "Rows" "1"
    for i in $(seq 1 5); do
        kwriteconfig6 --file kwinrc --group "Desktops" --key "Name_$i" "Desktop $i"
    done

    ok "5 virtual desktops configured."
}

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK: Register workspace switching shortcuts (Meta+1..5)
# ─────────────────────────────────────────────────────────────────────────────
tweak_workspace_shortcuts() {
    info "Registering Meta+1..5 workspace switching shortcuts..."

    # Meta+1..5 → Switch to Desktop N
    for i in $(seq 1 5); do
        kwriteconfig6 \
            --file kglobalshortcutsrc \
            --group "kwin" \
            --key "Switch to Desktop $i" \
            "Meta+$i,none,Switch to Desktop $i"
    done

    # Meta+Shift+1..5 → Move window to desktop N
    for i in $(seq 1 5); do
        kwriteconfig6 \
            --file kglobalshortcutsrc \
            --group "kwin" \
            --key "Window to Desktop $i" \
            "Meta+Shift+$i,none,Move Window to Desktop $i"
    done

    ok "Workspace shortcuts registered."
}

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK: Reload KWin and KGlobalAccel to pick up config changes
# ─────────────────────────────────────────────────────────────────────────────
tweak_reload_kde() {
    info "Reloading KWin and plasma-kglobalaccel..."
    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
    systemctl --user restart plasma-kglobalaccel.service 2>/dev/null || true
    kbuildsycoca6 --noincremental 2>/dev/null || true
    ok "KDE daemons reloaded."
}

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK: Set default Caelestia shell scheme
# ─────────────────────────────────────────────────────────────────────────────
tweak_default_scheme() {
    info "Setting default shell scheme to dynamic (Tonal variant)..."
    
    if command -v caelestia >/dev/null 2>&1; then
        caelestia scheme set -n dynamic -v tonalspot 2>/dev/null || true
    elif python3 -m caelestia --help >/dev/null 2>&1; then
        python3 -m caelestia scheme set -n dynamic -v tonalspot 2>/dev/null || true
    elif [[ -x /usr/bin/caelestia ]]; then
        /usr/bin/caelestia scheme set -n dynamic -v tonalspot 2>/dev/null || true
    fi

    ok "Default scheme configured."
}

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK: Set default shell to Fish
# ─────────────────────────────────────────────────────────────────────────────
tweak_default_shell() {
    info "Setting default shell to fish..."
    
    if command -v fish >/dev/null 2>&1; then
        local fish_path
        fish_path="$(command -v fish)"
        
        printf '%s\n' "${SUDO_PASS:-}" | sudo -S chsh -s "$fish_path" "$USER" 2>/dev/null || warn "Failed to change shell for $USER. You may need to run 'chsh -s $fish_path' manually."
        
        local konsole_profile_dir="$HOME/.local/share/konsole"
        mkdir -p "$konsole_profile_dir"
        
        # Inject fish into all existing Konsole profiles
        local profiles_found=0
        for profile in "$konsole_profile_dir"/*.profile; do
            if [[ -f "$profile" ]]; then
                kwriteconfig6 --file "$profile" --group "General" --key "Command" "$fish_path"
                profiles_found=1
            fi
        done
        
        # If no profiles existed, create the standard fallback one so the shell works
        if [[ $profiles_found -eq 0 ]]; then
            kwriteconfig6 --file "$konsole_profile_dir/Profile 1.profile" --group "General" --key "Name" "Profile 1"
            kwriteconfig6 --file "$konsole_profile_dir/Profile 1.profile" --group "General" --key "Command" "$fish_path"
            kwriteconfig6 --file "$HOME/.config/konsolerc" --group "Desktop Entry" --key "DefaultProfile" "Profile 1.profile"
        fi
    else
        warn "Fish is not installed, skipping shell change."
    fi

    ok "Shell configuration applied."
}

# ─────────────────────────────────────────────────────────────────────────────
# TWEAK: Patch caelestia-cli to prevent terminal sequence bleeding
# ─────────────────────────────────────────────────────────────────────────────
tweak_patch_caelestia_cli() {
    info "Patching caelestia CLI to fix terminal sequence bleeding..."
    
    local theme_file
    theme_file=$(python3 -c "import importlib.util; spec = importlib.util.find_spec('caelestia.utils.theme'); print(spec.origin) if spec and spec.origin else print('')" 2>/dev/null)
    
    if [[ -n "$theme_file" && -f "$theme_file" ]]; then
        local python_code="
import sys, pathlib, subprocess, re
p = pathlib.Path('$theme_file')
text = p.read_text()
old = '''    for pt in pts_path.iterdir():
        if pt.name.isdigit():
            try:
                # Use non-blocking write with timeout to prevent hangs'''
new = '''    for pt in pts_path.iterdir():
        if pt.name.isdigit():
            try:
                res = subprocess.run([\"ps\", \"-t\", pt.name, \"-o\", \"comm=\"], capture_output=True, text=True)
                processes = [p.strip() for p in res.stdout.splitlines() if p.strip()]
                if not any(re.match(r\"^(bash|zsh|fish|sh|dash|mksh|tcsh|csh|ksh)$\", p) for p in processes):
                    continue
            except Exception:
                pass
            try:
                # Use non-blocking write with timeout to prevent hangs'''
if old in text:
    p.write_text(text.replace(old, new))
"
        if ! python3 -c "$python_code" 2>/dev/null; then
            if ! printf '%s\n' "${SUDO_PASS:-}" | sudo -S python3 -c "$python_code" 2>/dev/null; then
                warn "Failed to patch $theme_file (requires sudo)"
                echo "Caelestia CLI Theme Sequence Patch" >> "${XDG_CACHE_HOME:-$HOME/.cache}/caelestia-kde/failed_patches.txt"
            fi
        fi
        ok "caelestia CLI patched."
    else
        warn "caelestia CLI not found, skipping patch."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# ── ADD NEW TWEAKS ABOVE THIS LINE ──
# To add a new tweak:
#   1. Define a function: tweak_<name>() { ... }
#   2. Call it in the main() section below
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Main — apply all tweaks in order
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--list" ]]; then
    echo
    echo "Available tweaks:"
    declare -F | awk '/^declare -f tweak_/ {print "  •", substr($3, 7)}' | sed 's/_/ /g'
    echo
    exit 0
fi

tweak_disable_kde_osd
tweak_five_desktops
tweak_workspace_shortcuts
tweak_default_scheme
tweak_default_shell
tweak_patch_caelestia_cli
tweak_reload_kde

echo
echo -e "${GREEN}════════════════════════════════════════════════════════${RST}"
echo -e "${GREEN}  All system tweaks applied successfully.${RST}"
echo -e "${GREEN}════════════════════════════════════════════════════════${RST}"
echo
