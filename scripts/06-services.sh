#!/usr/bin/env bash
# 07-services.sh — Enable systemd user services and reload KWin.

echo
echo "════════════════════════════════════════"
echo "  Step 6/11 — Services & KWin"
echo "════════════════════════════════════════"

# ── qs-kwin-bridge systemd service ────────────────────────────────────────────
if [[ -f "$HOME/.config/systemd/user/qs-kwin-bridge.service" ]] && \
   [[ -s "$HOME/.config/systemd/user/qs-kwin-bridge.service" ]]; then
    echo "  Enabling qs-kwin-bridge service..."
    systemctl --user daemon-reload
    systemctl --user enable --now qs-kwin-bridge.service 2>/dev/null || true
    echo "  [OK]  qs-kwin-bridge enabled."
else
    echo "  [SKIP] qs-kwin-bridge.service is empty/missing — skipping."
fi

# ── ydotoold (on-screen keyboard key injection) ───────────────────────────────
# ydotoold needs access to /dev/uinput. Add a udev rule to allow the 'input'
# group to access it, then add the user to that group.
echo "  Setting up ydotoold (OSK key injection daemon)..."

# Create udev rule for uinput group access
if [[ ! -f /etc/udev/rules.d/80-uinput.rules ]]; then
    echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/80-uinput.rules > /dev/null
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true
    echo "  [OK]  udev rule for uinput created."
fi

# Add user to 'input' group (takes effect on next login)
if ! groups "$USER" | grep -q '\binput\b'; then
    sudo usermod -aG input "$USER"
    echo "  [OK]  Added $USER to 'input' group (takes effect on next login)."
else
    echo "  [OK]  $USER already in 'input' group."
fi

# Add NOPASSWD sudo rule so ydotoold can be started without password / group refresh
# This allows ydotoold to open /dev/uinput as root, bypassing the 'input' group requirement
# until the user logs out and back in.
SUDOERS_FILE="/etc/sudoers.d/ydotoold-nopasswd"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo "$USER ALL=(root) NOPASSWD: /usr/bin/ydotoold" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    echo "  [OK]  sudoers NOPASSWD rule added for ydotoold."
else
    # Update it with the current username
    echo "$USER ALL=(root) NOPASSWD: /usr/bin/ydotoold" | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    echo "  [OK]  sudoers NOPASSWD rule updated for $USER."
fi

# Also fix /dev/uinput permissions immediately (without needing udev reload)
sudo chmod 660 /dev/uinput 2>/dev/null || true
sudo chgrp input /dev/uinput 2>/dev/null || true

# Deploy ydotoold-wrapper script to ~/.local/bin
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/ydotoold-wrapper" << 'WRAPPER'
#!/bin/bash
# ydotoold-wrapper — starts ydotoold via sudo with uinput access
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

# ── Reload KWin and KGlobalAccel ─────────────────────────────────────────────
echo "  Reloading KWin..."
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

echo "  Restarting plasma-kglobalaccel..."
systemctl --user restart plasma-kglobalaccel.service 2>/dev/null || true

echo "[OK]  Services configured."
