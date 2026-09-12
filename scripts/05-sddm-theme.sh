#!/usr/bin/env bash
# 05-sddm-theme.sh  Install the Caelestia SDDM greeter theme.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/privileges.sh"

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"
SRC_DIR="$BUNDLE_DIR/src/sddm"

if [[ "${INSTALL_SDDM:-true}" != "true" ]]; then
    skip "SDDM theme not selected."
    exit 0
fi

echo
echo ""
info "Installing Caelestia SDDM theme"
echo ""

THEME_NAME="caelestia"
INSTALL_DIR="/usr/share/sddm/themes/$THEME_NAME"
SYNC_SCRIPT="$INSTALL_DIR/scripts/sync.sh"

VARIANT="${SDDM_THEME_VARIANT:-full}"
case "$VARIANT" in
    full|mini) ;;
    *) die "Unknown SDDM theme variant: $VARIANT" ;;
esac

THEME_SOURCE="$SRC_DIR/themes/$VARIANT"
FONT_SOURCE="$BUNDLE_DIR/src/kde/shells/caelestia.desktop/contents/fonts/GoogleSansFlex.ttf"

if [[ ! -d "$THEME_SOURCE" ]]; then
    die "SDDM theme source not found at $THEME_SOURCE"
fi

ALL_OK=true

if [[ "${BASE_DISTRO:-}" == "arch" ]]; then
    SDDM_DEPS=(sddm qt6-declarative qt6-5compat qt6-svg qt6-multimedia)
    MISSING=()
    for pkg in "${SDDM_DEPS[@]}"; do
        if ! pacman -Qq "$pkg" &>/dev/null; then
            MISSING+=("$pkg")
        fi
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        info "Installing SDDM dependencies: ${MISSING[*]}"
        caelestia_sudo pacman -S --noconfirm "${MISSING[@]}"
    fi
    ok "Dependencies met."
elif [[ "${BASE_DISTRO:-}" == "fedora" ]]; then
    SDDM_DEPS=(sddm qt6-qtdeclarative qt6-qt5compat qt6-qtsvg qt6-qtmultimedia)
    MISSING=()
    for pkg in "${SDDM_DEPS[@]}"; do
        if ! rpm -q "$pkg" &>/dev/null; then
            MISSING+=("$pkg")
        fi
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        info "Installing SDDM dependencies: ${MISSING[*]}"
        caelestia_sudo dnf install -y "${MISSING[@]}"
    fi
    ok "Dependencies met."
elif [[ "${BASE_DISTRO:-}" == "debian" ]]; then
    SDDM_DEPS=(sddm qml6-module-qtquick qt6-5compat-dev libqt6svg6 qt6-multimedia-dev)
    MISSING=()
    for pkg in "${SDDM_DEPS[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null 2>&1; then
            MISSING+=("$pkg")
        fi
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        info "Installing SDDM dependencies: ${MISSING[*]}"
        caelestia_sudo apt-get install -y "${MISSING[@]}"
    fi
    ok "Dependencies met."
else
    warn "Unsupported distribution ($BASE_DISTRO). SDDM Qt6 dependencies must be installed manually."
    ALL_OK=false
fi

if [[ -d "$INSTALL_DIR" ]]; then
    caelestia_sudo rm -rf "$INSTALL_DIR"
fi

caelestia_sudo mkdir -p "$INSTALL_DIR/scripts"
caelestia_sudo cp -r "$THEME_SOURCE"/* "$INSTALL_DIR/"
caelestia_sudo cp "$SRC_DIR/sync.sh" "$INSTALL_DIR/scripts/"

caelestia_sudo mkdir -p "$INSTALL_DIR/assets/google-sans-flex"
if [[ -f "$FONT_SOURCE" ]]; then
    caelestia_sudo cp "$FONT_SOURCE" "$INSTALL_DIR/assets/google-sans-flex/GoogleSansFlex.ttf"
else
    warn "GoogleSansFlex.ttf not found at $FONT_SOURCE, theme text may not render correctly."
    ALL_OK=false
fi

# mini reuses full's shape components (coupled by design, keep in sync)
if [[ "$VARIANT" == "mini" ]]; then
    if [[ -d "$SRC_DIR/themes/full/components/shapes" ]]; then
        caelestia_sudo mkdir -p "$INSTALL_DIR/components/shapes"
        caelestia_sudo cp -r "$SRC_DIR/themes/full/components/shapes"/* "$INSTALL_DIR/components/shapes/"
    else
        warn "Shape components not found at $SRC_DIR/themes/full/components/shapes, mini theme will not render correctly."
        ALL_OK=false
    fi
fi

caelestia_sudo find "$INSTALL_DIR" -type d -exec chmod 755 {} +
caelestia_sudo find "$INSTALL_DIR" -type f -exec chmod 644 {} +
caelestia_sudo chmod 755 "$SYNC_SCRIPT"
ok "Theme files installed to $INSTALL_DIR ($VARIANT variant)"

mkdir -p "$HOME/.config/caelestia/templates"
if [[ -f "$THEME_SOURCE/theme.conf.template" ]]; then
    cp "$THEME_SOURCE/theme.conf.template" "$HOME/.config/caelestia/templates/sddm-theme.conf"
    ok "Template config created."
fi

caelestia_sudo mkdir -p /etc/sddm.conf.d
cat <<'DROPIN' | caelestia_sudo tee /etc/sddm.conf.d/caelestia.conf >/dev/null
[General]
GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1

[Theme]
Current=caelestia
DROPIN
ok "SDDM config drop-in created."

POSTHOOK_CMD="sudo $SYNC_SCRIPT --posthook"
CLI_JSON="$HOME/.config/caelestia/cli.json"

if command -v python3 &>/dev/null; then
    python3 - "$CLI_JSON" "$POSTHOOK_CMD" <<'PYEOF'
import json, sys, os
cli_path, hook_cmd = sys.argv[1], sys.argv[2]
config = {}
if os.path.exists(cli_path):
    with open(cli_path) as f:
        config = json.load(f)
for section in ("wallpaper", "theme"):
    if section not in config:
        config[section] = {}
    existing = config[section].get("postHook", "")
    if hook_cmd in existing:
        pass
    elif existing:
        config[section]["postHook"] = existing + " && " + hook_cmd
    else:
        config[section]["postHook"] = hook_cmd
os.makedirs(os.path.dirname(cli_path), exist_ok=True)
with open(cli_path, "w") as f:
    json.dump(config, f, indent=4)
PYEOF
    ok "Posthook registered in cli.json"
else
    warn "python3 not found, skipping posthook registration. Wallpaper and color changes will not auto-sync to SDDM."
    ALL_OK=false
fi

SUDOERS_FILE="/etc/sudoers.d/caelestia-sddm-sync"
if ! caelestia_sudo_quiet test -f "$SUDOERS_FILE"; then
    echo "$USER ALL=(root) NOPASSWD: $SYNC_SCRIPT" | caelestia_sudo tee "$SUDOERS_FILE" >/dev/null
    caelestia_sudo chmod 440 "$SUDOERS_FILE"
    ok "Sudoers drop-in created."
fi

if sync_output="$(caelestia_sudo "$SYNC_SCRIPT" 2>&1)"; then
    ok "Initial sync complete."
else
    warn "Initial sync had warnings (non-fatal):"
    # The sync's output is the only place the reason is written down, so it is
    # echoed here rather than left in the step's exit code. Its markers are
    # relabelled on the way through: the installer turns any "[WARN]" inside a
    # step's output into a WARN status for the whole step, and a nested command's
    # warning is not what this step is reporting.
    if [[ -n "$sync_output" ]]; then
        printf '%s\n' "$sync_output" | sed -e 's/\[WARN\]/warning:/g' -e 's/\[ERR\]/error:/g' -e 's/^/  /'
    fi
    ALL_OK=false
fi

# Non-fatal problems are reported through the [WARN] markers in this step's
# output, which the TUI turns into a WARN status. The exit code stays 0 so a
# theme that did install is not reported as FAILED and offered for retry.
if [[ "$ALL_OK" == "true" ]]; then
    ok "SDDM theme installed."
else
    warn "SDDM theme installed with warnings. Review the output above."
fi
