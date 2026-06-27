#!/usr/bin/env bash
# Updates the QMLTermWidget colorscheme for the Quickshell Dashboard
# Usage: ./update_terminal_colors.sh <scheme_name> <bg_hex> <fg_hex> <c1_hex> <c2_hex>

scheme_name="$1"
bg_hex="$2"
fg_hex="$3"
c1_hex="$4"
c2_hex="$5"

hexToRgb() {
    local hex="${1#\#}"
    [ "${#hex}" -eq 8 ] && hex="${hex:2:6}"
    printf "%d,%d,%d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

bg=$(hexToRgb "$bg_hex")
fg=$(hexToRgb "$fg_hex")
c1=$(hexToRgb "$c1_hex")
c2=$(hexToRgb "$c2_hex")

out_dir="$HOME/.local/share/qmltermwidget/color-schemes"
mkdir -p "$out_dir"

# Clean up old dynamic schemes to prevent clutter
rm -f "$out_dir/DashboardTerminal_"*.colorscheme

out_file="$out_dir/${scheme_name}.colorscheme"

cat <<EOF > "$out_file"
[Background]
Color=$bg
[BackgroundIntense]
Color=$bg
[Foreground]
Color=$fg
[ForegroundIntense]
Color=$fg
[Color0]
Color=$bg
[Color1]
Color=$c1
[Color2]
Color=$c2
[Color3]
Color=$c1
[Color4]
Color=$c1
[Color5]
Color=$c1
[Color6]
Color=$c1
[Color7]
Color=$fg
[General]
Description=$scheme_name
Opacity=1.0
Blur=false
EOF
