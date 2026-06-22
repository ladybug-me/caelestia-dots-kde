#!/usr/bin/env bash
# 02-packages.sh — Install all packages: PKGBUILDs/RPMs + supplemental.
# Calls installDP.sh/installDP_fedora.sh for groups, then pkginstall.sh for extras.

BUNDLE_DIR="${BUNDLE_DIR:?BUNDLE_DIR not set}"

echo
echo "════════════════════════════════════════"
echo "  Step 2/11 — Packages"
echo "════════════════════════════════════════"

echo
if [[ "$BASE_DISTRO" == "arch" ]]; then
    echo "--- 2a: Installing from local PKGBUILDs (sdata/arch-dist) ---"
    bash "$BUNDLE_DIR/sdata/arch-dist/installDP.sh"
elif [[ "$BASE_DISTRO" == "fedora" ]]; then
    echo "--- 2a: Installing from local RPMs/groups (sdata/fedora-dist) ---"
    bash "$BUNDLE_DIR/sdata/fedora-dist/installDP_fedora.sh"
fi

#THE FOLLOWING FUNCTIONALITY IS ONLY REQUIRED IF SOME PACKAGE ISN'T AVAILABLE
# echo
# echo "--- 2b: Installing supplemental packages (fonts, cursors, Python) ---"
# REPO_ROOT="$BUNDLE_DIR" bash "$BUNDLE_DIR/pkginstall.sh"

# echo
# echo "--- 2c: Installing MicroTeX (Manual Build) ---"
# bash "$BUNDLE_DIR/scripts/install-microtex.sh"
#
if [[ "$BASE_DISTRO" == "fedora" ]]; then
    echo
    echo "--- 2d: Compatibility Symlinks ---"
    # Fix Arch -> Fedora compatibility for qdbus6
    if [ ! -L /usr/local/bin/qdbus6 ]; then
        sudo ln -s /usr/bin/qdbus-qt6 /usr/local/bin/qdbus6 2>/dev/null || true
    fi
fi

echo
if [[ "${POLONIUM_ENABLED:-false}" == "true" ]]; then
    echo "--- Installing Polonium KWin Script ---"
    if ! command -v kpackagetool6 >/dev/null 2>&1; then
        echo "  [ERR] kpackagetool6 not found. Please ensure KDE Plasma development/package tools are installed."
    else
        tmpdir="$(mktemp -d)"
        if curl -sL "https://github.com/zeroxoneafour/polonium/releases/latest/download/polonium.kwinscript" -o "$tmpdir/polonium.kwinscript"; then
            if kpackagetool6 -t KWin/Script -s polonium >/dev/null 2>&1; then
                kpackagetool6 -t KWin/Script -u "$tmpdir/polonium.kwinscript" 2>/dev/null || true
            else
                kpackagetool6 -t KWin/Script -i "$tmpdir/polonium.kwinscript" 2>/dev/null || true
            fi
            echo "  [OK]  Polonium installed."
        else
            echo "  [ERR] Failed to download Polonium."
        fi
        rm -rf "$tmpdir"
    fi
fi

echo
echo "[OK]  Package installation complete."
