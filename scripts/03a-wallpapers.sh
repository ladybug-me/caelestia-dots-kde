#!/usr/bin/env bash
# 03a-wallpapers.sh  Download the dharmx "digital" wallpaper pack into the
#                     wallpaper library (default ~/Pictures/Wallpapers).
#
# Best-effort: this step never fails the install. If the pack is already
# present it is skipped, and if the download cannot run (no git, no network)
# it warns and continues. The KDE deploy step (04) uses the pack's default
# image when it exists and otherwise keeps the bundled fallback.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

# Match the runtime's resolution in shell/utils/Paths.qml as closely as a
# fresh install can: honor CAELESTIA_WALLPAPERS_DIR, else XDG_PICTURES_DIR,
# else ~/Pictures.
if [[ -n "${CAELESTIA_WALLPAPERS_DIR:-}" ]]; then
    WALLS_DIR="$CAELESTIA_WALLPAPERS_DIR"
elif [[ -n "${XDG_PICTURES_DIR:-}" ]]; then
    WALLS_DIR="$XDG_PICTURES_DIR/Wallpapers"
elif command -v xdg-user-dir >/dev/null 2>&1 \
        && PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null)" \
        && [[ -n "$PICTURES_DIR" ]]; then
    WALLS_DIR="$PICTURES_DIR/Wallpapers"
else
    WALLS_DIR="$HOME/Pictures/Wallpapers"
fi
PACK_DIR="$WALLS_DIR/dharmx-digital"
DEFAULT_IMAGE="$PACK_DIR/a_couple_of_people_standing_on_a_mountain.png"

info "Downloading wallpaper pack (dharmx/walls digital)..."

# Idempotent: a previous successful run left a populated pack folder. The
# staging dir is only ever moved into place once complete, so a populated
# pack folder means the download finished.
if [[ -d "$PACK_DIR" ]] && [[ -n "$(ls -A "$PACK_DIR" 2>/dev/null)" ]]; then
    ok "Wallpaper pack already present at $PACK_DIR"
    exit 0
fi

if ! command -v git >/dev/null 2>&1; then
    warn "git not found - skipping wallpaper pack download."
    exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Partial clone + sparse checkout pulls only the digital/ folder, not the
# whole walls repo (which holds many other categories).
if ! git clone --depth 1 --filter=blob:none --sparse \
        "https://github.com/dharmx/walls.git" "$TMP_DIR/walls" >/dev/null 2>&1; then
    warn "Failed to clone the wallpaper repository - skipping pack download."
    exit 0
fi

if ! git -C "$TMP_DIR/walls" sparse-checkout set digital >/dev/null 2>&1; then
    warn "Failed to check out the digital wallpapers - skipping pack download."
    exit 0
fi

mkdir -p "$WALLS_DIR"
STAGING="$WALLS_DIR/.dharmx-digital.tmp"
rm -rf "$STAGING"
mkdir -p "$STAGING"

shopt -s nullglob nocaseglob
files=( "$TMP_DIR/walls/digital"/*.png \
        "$TMP_DIR/walls/digital"/*.jpg \
        "$TMP_DIR/walls/digital"/*.jpeg \
        "$TMP_DIR/walls/digital"/*.webp \
        "$TMP_DIR/walls/digital"/*.gif )
shopt -u nullglob nocaseglob

if [[ ${#files[@]} -eq 0 ]]; then
    rm -rf "$STAGING"
    warn "Wallpaper pack came back empty - skipping."
    exit 0
fi

cp "${files[@]}" "$STAGING/" || {
    rm -rf "$STAGING"
    warn "Failed to copy wallpapers into the library - skipping."
    exit 0
}

rm -rf "$PACK_DIR"
mv "$STAGING" "$PACK_DIR"

ok "Downloaded ${#files[@]} wallpapers to $PACK_DIR"

if [[ -f "$DEFAULT_IMAGE" ]]; then
    info "Default wallpaper available: $DEFAULT_IMAGE"
else
    warn "Expected default wallpaper missing from the pack: $DEFAULT_IMAGE"
fi

exit 0
