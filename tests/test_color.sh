#!/usr/bin/env bash
# test_color.sh - Tests for the color pipeline (src/bin/caelestia-color).
#
# matugen generates the palette and is replaced here by a stub that reads the
# config it is handed and writes the files the config names, which is the part
# the command is responsible for: what gets rendered, where it lands, and what
# reaches scheme.json. The palette itself is matugen's and is checked on a real
# machine instead.
#
# The scheme data is the repository's own src/ directory, so these tests read
# the same files a checkout installs.

set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COLOR="$REPO_ROOT/src/bin/caelestia-color"

SANDBOX=""
STUB_DIR=""
CALLS=""
OUTPUT=""
STATUS=0

# write_stub_matugen
#
# A stand-in for matugen. It records its arguments, then walks the config it was
# given and writes every output path: the scheme template gets a scheme.json
# built from the metadata and mode it was handed, everything else gets a line
# naming the template it came from.
write_stub_matugen() {
    cat > "$STUB_DIR/matugen" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$MATUGEN_CALLS"

config=""
mode="dark"
meta="{}"
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    case "${args[i]}" in
        --config) config="${args[i + 1]}" ;;
        --mode) mode="${args[i + 1]}" ;;
        --import-json-string) meta="${args[i + 1]}" ;;
    esac
done

# matugen resolves "smart" itself; this stub always ands up dark.
[[ "$mode" == "smart" ]] && mode="dark"

json_field() {
    printf '%s' "$meta" | sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p"
}

awk '
    /^\[templates\./ { id = substr($0, 12, length($0) - 12); next }
    /^input_path/ { input = $0; sub(/^input_path = "/, "", input); sub(/"$/, "", input); next }
    /^output_path/ { output = $0; sub(/^output_path = "/, "", output); sub(/"$/, "", output); print id "|" input "|" output; next }
' "$config" | while IFS='|' read -r id input output; do
    mkdir -p "$(dirname "$output")"
    if [[ "$id" == "scheme" ]]; then
        cat > "$output" <<EOF
{
    "name": "$(json_field name)",
    "flavour": "$(json_field flavour)",
    "variant": "$(json_field variant)",
    "mode": "$mode",
    "colours": {
        "background": "101417",
        "onSurface": "dfe6ed",
        "surface": "0a0f12",
        "primary": "92cef5",
        "term0": "333a40"
    }
}
EOF
    else
        case "${input##*/}" in
            palettes.json.tmpl)
                # What the real template renders: every palette, every shade.
                printf '%s' '{"primary": {"50": "227cbb"}, "secondary": {"50": "677987"}, "tertiary": {"50": "6e759f"}, "neutral": {"50": "74777a"}, "neutral_variant": {"50": "71787e"}}' > "$output"
                ;;
            *)
                printf 'rendered %s\n' "${input##*/}" > "$output"
                ;;
        esac
    fi
done
STUB
    chmod +x "$STUB_DIR/matugen"
}

# write_stub_ffmpeg
#
# The stand-in for the decoder the smart-variant measurement reads pixels with.
# It prints raw RGB instead of running ffmpeg, so the thresholds upstream chose
# are exercised without a real image: FFMPEG_PATTERN picks the pixels, and an
# unknown one fails the way a file ffmpeg cannot read would.
write_stub_ffmpeg() {
    cat > "$STUB_DIR/ffmpeg" <<'STUB'
#!/usr/bin/env bash
case "${FFMPEG_PATTERN:-gray}" in
    gray) printf '\x80\x80\x80\x80\x80\x80' ;;
    redblue) printf '\xff\x00\x00\x00\x00\xff' ;;
    *) exit 1 ;;
    esac
STUB
    chmod +x "$STUB_DIR/ffmpeg"
}

# setup_sandbox
#
# A throwaway home: config, state and cache all inside it, with the repository's
# scheme data pointed at directly. Nothing here touches the developer's own
# files, which matters because the command writes into XDG directories.
setup_sandbox() {
    SANDBOX="$(new_tmpdir)"
    STUB_DIR="$SANDBOX/bin"
    CALLS="$SANDBOX/matugen-calls.log"
    mkdir -p "$STUB_DIR" "$SANDBOX/config" "$SANDBOX/state" "$SANDBOX/cache" "$SANDBOX/data" "$SANDBOX/pictures"
    write_stub_matugen
    write_stub_ffmpeg

    export CAELESTIA_DATA_DIR="$REPO_ROOT/src"
    export XDG_CONFIG_HOME="$SANDBOX/config"
    export XDG_STATE_HOME="$SANDBOX/state"
    export XDG_CACHE_HOME="$SANDBOX/cache"
    export XDG_DATA_HOME="$SANDBOX/data"
    export XDG_PICTURES_DIR="$SANDBOX/pictures"
    export MATUGEN_CALLS="$CALLS"
    export PATH="$STUB_DIR:$PATH"
}

# run_color <args...>
run_color() {
    : > "$CALLS"
    OUTPUT="$(
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
        XDG_STATE_HOME="$XDG_STATE_HOME" \
        XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        XDG_DATA_HOME="$XDG_DATA_HOME" \
        XDG_PICTURES_DIR="$XDG_PICTURES_DIR" \
        CAELESTIA_DATA_DIR="$CAELESTIA_DATA_DIR" \
        MATUGEN_CALLS="$CALLS" \
        FFMPEG_PATTERN="${FFMPEG_PATTERN:-gray}" \
        PATH="$PATH" \
        bash "$COLOR" "$@" 2>&1
    )"
    STATUS=$?
}

state_file() { printf '%s/caelestia/%s' "$XDG_STATE_HOME" "$1"; }

# wallpaper_image <name>
#
# A file to point the command at. The path is canonicalized, because that is
# what the command stores: it resolves the wallpaper before writing it down.
wallpaper_image() {
    local path="$XDG_PICTURES_DIR/$1"
    printf 'not really a png\n' > "$path"
    printf '%s' "$(realpath -- "$path")"
}

# set_cli_config <json>
set_cli_config() {
    mkdir -p "$XDG_CONFIG_HOME/caelestia"
    printf '%s' "$1" > "$XDG_CONFIG_HOME/caelestia/cli.json"
}

test_list_names_are_the_shipped_ones() {
    setup_sandbox
    run_color scheme list -n
    assert_status 0 "$STATUS" "scheme list -n should succeed"
    assert_contains "$OUTPUT" "catppuccin" "the shipped names are listed"
    assert_contains "$OUTPUT" "gruvbox" "more than one name is listed"
    assert_ne "" "$OUTPUT" "the list is not empty"
}

test_list_flat_is_the_shape_the_colors_page_reads() {
    setup_sandbox
    run_color scheme list --flat
    assert_status 0 "$STATUS" "scheme list --flat should succeed"

    # Every entry carries the four fields the Colors page builds its cards from,
    # and the colors are hex digits with no '#' because the shell adds it.
    local described
    described="$(printf '%s' "$OUTPUT" | python3 -c '
import json, sys
entries = json.load(sys.stdin)
assert entries, "no entries"
keys = {"name", "flavour", "mode", "colours"}
for entry in entries:
    assert keys <= set(entry), f"missing keys in {entry.keys()}"
    for role, value in entry["colours"].items():
        assert "#" not in value, f"{role} carries a hash: {value}"
print(f"{len(entries)} entries")
' 2>&1)"
    assert_contains "$described" "entries" "the flat list parses and carries the expected keys: $described"
}

test_set_a_named_scheme_writes_its_own_file() {
    setup_sandbox
    run_color scheme set -n catppuccin -f mocha -m dark
    assert_status 0 "$STATUS" "setting a named scheme should succeed"

    local scheme="$XDG_STATE_HOME/caelestia/scheme.json"
    assert_file_exists "$scheme"

    local described
    described="$(python3 - "$scheme" "$REPO_ROOT/src/schemes/catppuccin/mocha/dark.txt" <<'PY' 2>&1
import json, pathlib, sys
scheme = json.loads(pathlib.Path(sys.argv[1]).read_text())
source = {}
for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
    parts = line.split()
    if len(parts) == 2:
        source[parts[0]] = parts[1].lstrip("#")
assert scheme["name"] == "catppuccin", scheme["name"]
assert scheme["flavour"] == "mocha", scheme["flavour"]
assert scheme["mode"] == "dark", scheme["mode"]
assert scheme["colours"] == source, "the colors differ from the shipped file"
print(f'{len(scheme["colours"])} roles, all from the file')
PY
)"
    assert_contains "$described" "roles, all from the file" "$described"
}

test_a_named_scheme_without_the_mode_asked_for_says_so() {
    setup_sandbox
    # catppuccin/mocha ships dark only.
    run_color scheme set -n catppuccin -f mocha -m light
    assert_status 0 "$STATUS" "the switch should still happen"
    assert_contains "$OUTPUT" "has no light colors" "the substitution is reported"
    assert_contains "$(cat "$XDG_STATE_HOME/caelestia/scheme.json")" '"mode": "dark"' \
        "the mode that exists is the one written"
}

test_unknown_schemes_are_refused() {
    setup_sandbox
    run_color scheme set -n nosuchscheme -f medium -m dark
    assert_status 1 "$STATUS" "an unknown scheme should fail"
    assert_contains "$OUTPUT" "no such scheme" "the reason is named"
    assert_file_missing "$XDG_STATE_HOME/caelestia/scheme.json"
}

test_dynamic_without_a_wallpaper_explains_itself() {
    setup_sandbox
    run_color scheme set -n dynamic
    assert_status 1 "$STATUS" "a dynamic scheme without a wallpaper should fail"
    assert_contains "$OUTPUT" "no wallpaper has been set yet" "the reason is named"
}

test_get_prints_the_fields_that_were_asked_for() {
    setup_sandbox
    run_color scheme set -n catppuccin -f mocha -m dark
    run_color scheme get -n -m -v
    assert_status 0 "$STATUS" "scheme get should succeed"
    assert_eq "catppuccin
dark
tonalspot" "$OUTPUT" "name, mode and variant come back in order"
}

test_wallpaper_writes_the_state_the_shell_watches() {
    setup_sandbox
    local image
    image="$(wallpaper_image wall.png)"
    run_color wallpaper -f "$image"
    assert_status 0 "$STATUS" "setting a wallpaper should succeed"

    assert_eq "$image" "$(cat "$XDG_STATE_HOME/caelestia/wallpaper/path.txt")" \
        "path.txt carries the wallpaper"
    assert_eq "$image" "$(readlink "$XDG_STATE_HOME/caelestia/wallpaper/current")" \
        "the symlink points at it"
    local scheme="$XDG_STATE_HOME/caelestia/scheme.json"
    assert_file_exists "$scheme"
    assert_contains "$(cat "$scheme")" '"name": "dynamic"' "the scheme follows the wallpaper"
    assert_contains "$(cat "$CALLS")" "image" "matugen is asked for an image"
    assert_contains "$(cat "$CALLS")" "--source-color-index 0" \
        "the source color is picked, not prompted for"
}

test_the_roles_the_shell_reads_come_with_a_generated_scheme() {
    setup_sandbox
    local image
    image="$(wallpaper_image wall.png)"
    run_color wallpaper -f "$image"
    assert_status 0 "$STATUS" "setting a wallpaper should succeed"

    # matugen names the Material roles; these are the ones it does not, and the
    # palette manager, the toasts, the weather and the greeter read them.
    local described
    described="$(python3 - "$XDG_STATE_HOME/caelestia/scheme.json" <<'PY' 2>&1
import json, pathlib, sys
colours = json.loads(pathlib.Path(sys.argv[1]).read_text())["colours"]
expected = {
    "primary_paletteKeyColor": "227cbb",
    "secondary_paletteKeyColor": "677987",
    "tertiary_paletteKeyColor": "6e759f",
    "neutral_paletteKeyColor": "74777a",
    "neutral_variant_paletteKeyColor": "71787e",
    "success": "B5CCBA",
    "onSuccess": "213528",
    "successContainer": "374B3E",
    "onSuccessContainer": "D1E9D6",
    "text": "dfe6ed",
}
for role, value in expected.items():
    actual = colours.get(role)
    assert actual == value, f"{role}: expected {value}, got {actual}"
print(f"{len(expected)} roles folded in")
PY
)"
    assert_contains "$described" "roles folded in" "$described"
}

test_the_wallpaper_picks_the_variant_unless_asked_not_to() {
    setup_sandbox
    local image
    image="$(wallpaper_image wall.png)"

    # A flat image has no colourfulness, which upstream called neutral.
    FFMPEG_PATTERN=gray run_color wallpaper -f "$image"
    assert_contains "$(cat "$CALLS")" "--type scheme-neutral" \
        "a flat wallpaper picks the neutral variant"
    assert_contains "$(cat "$CALLS")" "--mode smart" "the wallpaper picks the mode"
    assert_contains "$(cat "$XDG_STATE_HOME/caelestia/scheme.json")" '"variant": "neutral"' \
        "the scheme is filed under the variant it really is"

    # Two far-apart colors are about as colourful as it gets.
    FFMPEG_PATTERN=redblue run_color wallpaper -f "$image"
    assert_contains "$(cat "$CALLS")" "--type scheme-tonal-spot" \
        "a colourful wallpaper picks the tonal spot variant"

    # With nothing to measure, matugen chooses and the name is whatever was asked
    # for - the one case where the two can disagree.
    FFMPEG_PATTERN=unreadable run_color wallpaper -f "$image"
    assert_status 0 "$STATUS" "an unreadable image should still produce a scheme"
    assert_contains "$(cat "$CALLS")" "--type scheme-smart" "matugen picks the variant as a fallback"
}

test_no_smart_keeps_the_mode_and_variant() {
    setup_sandbox
    local image
    image="$(wallpaper_image wall.png)"

    # A dynamic scheme needs a wallpaper before it can be derived at all.
    run_color wallpaper -f "$image" --no-smart
    run_color scheme set -n dynamic -v rainbow -m light
    run_color wallpaper -f "$image" --no-smart

    local calls
    calls="$(cat "$CALLS")"
    assert_contains "$calls" "--type scheme-rainbow" "--no-smart keeps the variant"
    assert_contains "$calls" "--mode light" "--no-smart keeps the mode"
    assert_eq "0" "$(printf '%s' "$calls" | grep -c 'scheme-smart' || true)" \
        "no smart type is passed with --no-smart (calls: $calls)"
    assert_eq "0" "$(printf '%s' "$calls" | grep -c -- '--mode smart' || true)" \
        "no smart mode is passed with --no-smart (calls: $calls)"
}

test_a_named_scheme_does_not_follow_the_wallpaper() {
    setup_sandbox
    run_color scheme set -n catppuccin -f mocha -m dark
    local before
    before="$(cat "$XDG_STATE_HOME/caelestia/scheme.json")"

    local image
    image="$(wallpaper_image other.png)"
    run_color wallpaper -f "$image"
    assert_status 0 "$STATUS" "the wallpaper should still be set"
    assert_eq "$before" "$(cat "$XDG_STATE_HOME/caelestia/scheme.json")" \
        "a scheme the user picked is left alone"
    assert_eq "$image" "$(cat "$XDG_STATE_HOME/caelestia/wallpaper/path.txt")" \
        "the wallpaper state is still updated"
}

test_the_generated_config_follows_the_user_config() {
    setup_sandbox
    set_cli_config '{"theme": {"enableGtk": false}}'
    run_color scheme set -n catppuccin -f mocha -m dark
    assert_status 0 "$STATUS" "the switch should succeed with a config file"

    local config="$XDG_STATE_HOME/caelestia/matugen/config.toml"
    assert_file_exists "$config"
    assert_file_missing "$XDG_CONFIG_HOME/gtk-3.0/colors.css"
    assert_file_missing "$XDG_CONFIG_HOME/gtk-4.0/colors.css"
    assert_file_exists "$XDG_CONFIG_HOME/btop/themes/matugen.theme"
    assert_file_exists "$XDG_CACHE_HOME/caelestia/terminal-sequences"
    assert_file_exists "$XDG_DATA_HOME/color-schemes/Matugen.colors"

    # A key upstream defined is still honoured for the targets upstream named.
    set_cli_config '{"theme": {"enableBtop": false, "enableQt": false}}'
    rm -rf "$XDG_CONFIG_HOME/btop" "$XDG_CONFIG_HOME/qt5ct"
    run_color scheme set -n catppuccin -f mocha -m dark
    assert_file_missing "$XDG_CONFIG_HOME/btop/themes/matugen.theme"
    assert_file_missing "$XDG_CONFIG_HOME/qt5ct/colors/matugen.conf"
    assert_file_exists "$XDG_CONFIG_HOME/rofi/colors.rasi"
}

test_starship_is_not_written_unless_asked_for() {
    setup_sandbox
    run_color scheme set -n catppuccin -f mocha -m dark
    assert_file_missing "$XDG_CONFIG_HOME/starship.toml"

    set_cli_config '{"theme": {"enableStarship": true}}'
    run_color scheme set -n catppuccin -f mocha -m dark
    assert_file_exists "$XDG_CONFIG_HOME/starship.toml"
}

test_a_preview_changes_nothing() {
    setup_sandbox
    run_color scheme set -n catppuccin -f mocha -m dark
    local before
    before="$(cat "$XDG_STATE_HOME/caelestia/scheme.json")"

    run_color scheme set --preview -n gruvbox -f medium -m dark
    assert_status 0 "$STATUS" "a preview should succeed"
    assert_contains "$OUTPUT" '"name": "gruvbox"' "the preview prints the scheme that would be set"
    assert_eq "$before" "$(cat "$XDG_STATE_HOME/caelestia/scheme.json")" \
        "the scheme in effect is untouched"
    assert_ne "$before" "$OUTPUT" "the preview is not the current scheme"
}

test_the_user_templates_are_rendered() {
    setup_sandbox
    mkdir -p "$XDG_CONFIG_HOME/caelestia/templates"
    cat > "$XDG_CONFIG_HOME/caelestia/templates/thing.conf" <<'EOF'
background={{ background.hex }}
upper={{ background.hex | upper }}
mode={{ mode }}
unknown={{ background.nosuchfield }}
EOF

    run_color scheme set -n catppuccin -f mocha -m dark
    assert_status 0 "$STATUS" "the switch should succeed"

    local rendered="$XDG_STATE_HOME/caelestia/theme/thing.conf"
    assert_file_exists "$rendered"

    local expected
    expected="$(python3 - "$REPO_ROOT/src/schemes/catppuccin/mocha/dark.txt" <<'PY'
import pathlib, sys
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    parts = line.split()
    if len(parts) == 2 and parts[0] == "background":
        print(parts[1])
        break
PY
)"
    assert_contains "$(cat "$rendered")" "background=$expected" "the role was rendered"
    assert_contains "$(cat "$rendered")" "mode=dark" "the mode was rendered"
    assert_contains "$(cat "$rendered")" "unknown={{ background.nosuchfield }}" \
        "a field that does not exist is left as it was"
}

test_the_hooks_run_with_the_scheme_in_their_environment() {
    setup_sandbox
    local log="$SANDBOX/hook.log"
    set_cli_config "{\"theme\": {\"postHook\": \"echo theme \$SCHEME_NAME \$SCHEME_MODE >> $log\"}, \"wallpaper\": {\"postHook\": \"echo wallpaper \$WALLPAPER_PATH >> $log\"}}"

    local image
    image="$(wallpaper_image wall.png)"
    run_color wallpaper -f "$image"
    assert_status 0 "$STATUS" "setting a wallpaper should succeed"

    local logged
    logged="$(cat "$log" 2>/dev/null || true)"
    assert_contains "$logged" "theme dynamic dark" "the theme hook saw the scheme"
    assert_contains "$logged" "wallpaper $image" "the wallpaper hook saw the wallpaper"
}

run_tests
