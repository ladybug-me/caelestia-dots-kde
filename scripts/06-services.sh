#!/usr/bin/env bash
# 06-services.sh  Enable systemd user services and reload KWin.

set -euo pipefail

echo
echo ""
echo "  Step 6/11  Services & KWin"
echo ""

if systemctl --user is-enabled --quiet qs-kwin-bridge.service 2>/dev/null || \
   systemctl --user is-active --quiet qs-kwin-bridge.service 2>/dev/null; then
    echo "  Disabling legacy qs-kwin-bridge service..."
    systemctl --user disable --now qs-kwin-bridge.service 2>/dev/null || true
fi

echo "  Clearing legacy KWin workspace shortcuts to avoid QML conflicts..."
for i in $(seq 1 10); do
    kwriteconfig6 --file kglobalshortcutsrc --group "kwin" --key "Switch to Desktop $i" "none,none,Switch to Desktop $i"
    kwriteconfig6 --file kglobalshortcutsrc --group "kwin" --key "Window to Desktop $i" "none,none,Move Window to Desktop $i"
done

echo "  Disabling legacy quickshell-kde-bridge KWin script..."
kwriteconfig6 --file kwinrc --group "Plugins" --key "quickshell-kde-bridgeEnabled" "false"

echo "  Ensuring KWin has 5 virtual desktops..."
kwriteconfig6 --file kwinrc --group "Desktops" --key "Number" "5"
kwriteconfig6 --file kwinrc --group "Desktops" --key "Rows" "1"
for i in $(seq 1 5); do
    kwriteconfig6 --file kwinrc --group "Desktops" --key "Name_$i" "Desktop $i"
done

#  ydotoold (on-screen keyboard key injection)
# ydotoold needs access to /dev/uinput. Add a udev rule to allow the 'input'
# group to access it, then add the user to that group.
echo "  Applying system-level configurations (requires root)..."
sudo bash -s -- "$USER" << 'EOF'
TARGET_USER="$1"

if systemctl is-enabled --quiet keyd.service 2>/dev/null || \
   systemctl is-active --quiet keyd.service 2>/dev/null; then
    echo "  Disabling legacy keyd service..."
    systemctl disable --now keyd.service 2>/dev/null || true
fi

echo "  Setting up ydotoold (OSK key injection daemon)..."

if [[ ! -f /etc/udev/rules.d/80-uinput.rules ]]; then
    echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' > /etc/udev/rules.d/80-uinput.rules
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    echo "  [OK]  udev rule for uinput created."
fi

if ! groups "$TARGET_USER" | grep -q '\binput\b'; then
    usermod -aG input "$TARGET_USER"
    echo "  [OK]  Added $TARGET_USER to 'input' group (takes effect on next login)."
else
    echo "  [OK]  $TARGET_USER already in 'input' group."
fi

SUDOERS_FILE="/etc/sudoers.d/ydotoold-nopasswd"
EXPECTED_RULE="$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/ydotoold"
if [[ ! -f "$SUDOERS_FILE" ]] || ! grep -qF "$EXPECTED_RULE" "$SUDOERS_FILE" 2>/dev/null; then
    echo "$EXPECTED_RULE" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    echo "  [OK]  sudoers NOPASSWD rule configured for ydotoold."
else
    echo "  [OK]  sudoers NOPASSWD rule already up to date."
fi

if [[ -e /dev/uinput ]]; then
    UINPUT_PERMS=$(stat -c "%a" /dev/uinput 2>/dev/null)
    UINPUT_GROUP=$(stat -c "%G" /dev/uinput 2>/dev/null)
    if [[ "$UINPUT_PERMS" != *"660" ]] || [[ "$UINPUT_GROUP" != "input" ]]; then
        chmod 660 /dev/uinput 2>/dev/null || true
        chgrp input /dev/uinput 2>/dev/null || true
    fi
fi
EOF

# Deploy ydotoold-wrapper script to ~/.local/bin
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/ydotoold-wrapper" << 'WRAPPER'
#!/bin/bash
# ydotoold-wrapper  starts ydotoold via sudo with uinput access
SOCKET="${YDOTOOL_SOCKET:-/run/user/$(id -u)/.ydotool_socket}"
if [ -S "$SOCKET" ] && pidof ydotoold > /dev/null 2>&1; then
    exit 0
fi
exec sudo /usr/bin/ydotoold \
    --socket-path="$SOCKET" \
    --socket-perm=0666
WRAPPER
chmod +x "$HOME/.local/bin/ydotoold-wrapper"
echo "  [OK]  ydotoold-wrapper deployed to ~/.local/bin."

# Deploy and enable ydotoold systemd user service
if [[ -f "${BUNDLE_DIR:-$(dirname "$(dirname "$0")")}/src/systemd/ydotoold.service" ]]; then
    SVCFILE="${BUNDLE_DIR:-$(dirname "$(dirname "$0")")}/src/systemd/ydotoold.service"
    mkdir -p "$HOME/.config/systemd/user"
    cp "$SVCFILE" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    systemctl --user enable ydotoold.service 2>/dev/null || true
    # Try to start it now (will succeed because of the sudoers rule above)
    systemctl --user start ydotoold.service 2>/dev/null || \
        echo "  [INFO] ydotoold will start on next login."
    echo "  [OK]  ydotoold service configured."
fi

echo "[OK]  Services configured."
