#!/usr/bin/env bash
set -euo pipefail

# ── ID Photo: crop to standard size + change background color ────────
#
# Usage:
#   bash idphoto.sh <input> <output> -s SIZE [-b BG_COLOR] [-g GRAVITY] [--fuzz PCT]
#
# Options:
#   -s SIZE        Preset name or WxH in pixels (see list below)
#   -b BG_COLOR    New background color (default: keep original)
#                    Presets: white, blue, red, or any hex like "#438EDB"
#   -g GRAVITY     Crop anchor (default: North — keep head at top)
#   --fuzz PCT     Color tolerance for background replacement (default: 20%)
#   --src-bg CLR   Original background color to replace (default: auto-detect from corners)
#
# Standard sizes (at 300 DPI):
#   1inch      25×35mm    295×413px   — 身份证、驾照、医保卡
#   1inch_sm   22×32mm    260×378px   — 小1寸（驾照体检）
#   2inch_sm   33×48mm    390×567px   — 小2寸（护照、港澳通行证）
#   2inch      35×49mm    413×579px   — 2寸（户口本、结婚证）
#   2inch_lg   35×53mm    413×626px   — 大2寸（部分签证）
#   5inch      89×127mm   1050×1500px — 5寸（照片冲印）
#   6inch      102×152mm  1200×1795px — 6寸（照片冲印）
# ─────────────────────────────────────────────────────────────────────

input="${1:?Usage: idphoto.sh <input> <output> -s SIZE [-b BG_COLOR]}"
output="${2:?Usage: idphoto.sh <input> <output> -s SIZE [-b BG_COLOR]}"
shift 2

size=""
bg_color=""
gravity="North"
fuzz="20%"
src_bg=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s)       size="$2"; shift 2 ;;
        -b)       bg_color="$2"; shift 2 ;;
        -g)       gravity="$2"; shift 2 ;;
        --fuzz)   fuzz="$2"; shift 2 ;;
        --src-bg) src_bg="$2"; shift 2 ;;
        *)        echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$size" ]]; then
    echo "Error: -s SIZE is required" >&2
    exit 1
fi

# Resolve size preset to WxH
case "$size" in
    1inch|1寸)       px="295x413" ;;
    1inch_sm|小1寸)   px="260x378" ;;
    2inch_sm|小2寸)   px="390x567" ;;
    2inch|2寸)       px="413x579" ;;
    2inch_lg|大2寸)   px="413x626" ;;
    5inch|5寸)       px="1050x1500" ;;
    6inch|6寸)       px="1200x1795" ;;
    *x*)             px="$size" ;;
    *)               echo "Unknown size: $size" >&2; exit 1 ;;
esac

W="${px%x*}"
H="${px#*x}"

# Resolve background color preset
resolve_bg() {
    case "$1" in
        white|白)  echo "#FFFFFF" ;;
        blue|蓝)   echo "#438EDB" ;;
        red|红)    echo "#BE0025" ;;
        "")        echo "" ;;
        *)         echo "$1" ;;
    esac
}
bg_color=$(resolve_bg "$bg_color")

echo "=== ID Photo ==="
echo "Input:   $input"
echo "Output:  $output"
echo "Size:    ${W}x${H} px ($size)"
[[ -n "$bg_color" ]] && echo "BG:      $bg_color"
echo "Gravity: $gravity"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
tmp="$tmpdir/work.png"

cp "$input" "$tmp"

# Step 1: Replace background color if requested
if [[ -n "$bg_color" ]]; then
    # Auto-detect source background from corner pixels if not specified
    if [[ -z "$src_bg" ]]; then
        src_bg=$(magick "$tmp" -format '%[pixel:u.p{0,0}]' info:)
        echo "Detected source BG: $src_bg"
    fi

    magick "$tmp" \
        -fuzz "$fuzz" \
        -fill "$bg_color" \
        -opaque "$src_bg" \
        "$tmpdir/recolor.png"
    tmp="$tmpdir/recolor.png"
    echo "✓ Background replaced"
fi

# Step 2: Resize + crop to target dimensions
# Fill the target area (may overflow one axis), then crop from gravity anchor
magick "$tmp" \
    -resize "${W}x${H}^" \
    -gravity "$gravity" \
    -extent "${W}x${H}" \
    "$output"

echo "✓ Cropped to ${W}x${H} → $output"
