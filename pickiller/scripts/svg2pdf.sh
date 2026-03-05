#!/usr/bin/env bash
set -euo pipefail

# ── Usage ────────────────────────────────────────────────────────────
# bash svg2pdf.sh <input.svg> <output.pdf> [-d DPI] [-w WIDTH] [-h HEIGHT]
#
# Options:
#   -d DPI     Rasterization DPI for embedded images (default: 300)
#   -w WIDTH   Scale output to width (in pixels)
#   -h HEIGHT  Scale output to height (in pixels)
# ─────────────────────────────────────────────────────────────────────

input="${1:?Usage: svg2pdf.sh <input.svg> <output.pdf> [options]}"
output="${2:?Usage: svg2pdf.sh <input.svg> <output.pdf> [options]}"
shift 2

dpi=300
opts=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d)  dpi="$2"; shift 2 ;;
        -w)  opts+=(-w "$2"); shift 2 ;;
        -h)  opts+=(-h "$2"); shift 2 ;;
        *)   echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -f "$input" ]]; then
    echo "Error: '$input' not found" >&2
    exit 1
fi

rsvg-convert "$input" -f pdf -d "$dpi" "${opts[@]}" -o "$output"
echo "✓ $input → $output (${dpi} DPI)"
