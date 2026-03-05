#!/usr/bin/env bash
set -euo pipefail

# ── Usage ────────────────────────────────────────────────────────────
# bash pdf2svg.sh <input.pdf> <output.svg> [options]
#
# Options:
#   -p PAGE        Page number to convert (default: 1)
#   -m MODE        Conversion mode (default: auto)
#                    vector  — preserve vector paths via pdftocairo
#                    raster  — rasterize then trace (for scanned PDFs)
#                    auto    — try vector first, fall back to raster
#   -d DPI         Rasterization DPI for raster mode (default: 300)
#   --preset PRE   Preset for raster trace (diagram|handwriting|document|auto)
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

input="${1:?Usage: pdf2svg.sh <input.pdf> <output.svg> [options]}"
output="${2:?Usage: pdf2svg.sh <input.pdf> <output.svg> [options]}"
shift 2

page=1
mode="auto"
dpi=300
preset="auto"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p)     page="$2"; shift 2 ;;
        -m)     mode="$2"; shift 2 ;;
        -d)     dpi="$2"; shift 2 ;;
        --preset) preset="$2"; shift 2 ;;
        *)      echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -f "$input" ]]; then
    echo "Error: '$input' not found" >&2
    exit 1
fi

echo "=== pdf2svg ==="
echo "Input:   $input"
echo "Output:  $output"
echo "Page:    $page"
echo "Mode:    $mode"

info=$(pdfinfo "$input" 2>/dev/null) || { echo "Error: pdfinfo failed. Is poppler installed?" >&2; exit 1; }
pages=$(echo "$info" | grep -i "^Pages:" | awk '{print $2}')
echo "Pages:   $pages"

if (( page < 1 || page > pages )); then
    echo "Error: page $page out of range (1-$pages)" >&2
    exit 1
fi

convert_vector() {
    echo "Converting page $page (vector mode)..."
    pdftocairo -svg -f "$page" -l "$page" "$input" "$output"
    echo "✓ Vector SVG written to $output"
}

convert_raster() {
    echo "Converting page $page (raster mode, ${dpi} DPI)..."
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    pdftocairo -png -r "$dpi" -f "$page" -l "$page" -singlefile "$input" "$tmpdir/page"

    local png="$tmpdir/page.png"
    if [[ ! -f "$png" ]]; then
        echo "Error: rasterization failed" >&2
        exit 1
    fi

    echo "Rasterized to $(magick identify -format '%wx%h' "$png") @ ${dpi} DPI"
    bash "$SCRIPT_DIR/png2svg.sh" "$png" "$output" "$preset"
}

case "$mode" in
    vector)
        convert_vector
        ;;
    raster)
        convert_raster
        ;;
    auto)
        convert_vector
        svg_size=$(wc -c < "$output" 2>/dev/null || echo 0)
        svg_size=$((svg_size + 0))
        # A vector SVG with actual paths is typically > 1KB.
        # If pdftocairo produced a near-empty or image-embedded SVG,
        # the file is likely a scanned PDF wrapped in vector container.
        if (( svg_size < 500 )); then
            echo "Vector output looks empty; falling back to raster trace..."
            rm -f "$output"
            convert_raster
        else
            echo "✓ Vector conversion succeeded (${svg_size} bytes)"
        fi
        ;;
    *)
        echo "Unknown mode: $mode (use: vector, raster, auto)" >&2
        exit 1
        ;;
esac
