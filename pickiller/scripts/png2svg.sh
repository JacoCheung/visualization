#!/usr/bin/env bash
set -euo pipefail

# ── Usage ────────────────────────────────────────────────────────────
# bash png2svg.sh <input.png> <output.svg> [preset]
# bash png2svg.sh <input.png> <output.svg> custom <threshold%> <alphamax> <turdsize> <opttolerance>
#
# Presets:
#   diagram     — flowcharts, architecture diagrams
#   handwriting — hand-drawn sketches
#   document    — documents, tables, text-heavy content
#   auto        — balanced defaults (default if omitted)
#   custom      — pass all four parameters explicitly
# ─────────────────────────────────────────────────────────────────────

input="${1:?Usage: png2svg.sh <input> <output> [preset]}"
output="${2:?Usage: png2svg.sh <input> <output> [preset]}"
preset="${3:-auto}"

if [[ ! -f "$input" ]]; then
    echo "Error: input file '$input' not found" >&2
    exit 1
fi

case "$preset" in
    diagram)
        threshold=50
        alphamax=1.0
        turdsize=15
        opttolerance=0.2
        ;;
    handwriting)
        threshold=45
        alphamax=0.8
        turdsize=5
        opttolerance=0.1
        ;;
    document)
        threshold=55
        alphamax=1.2
        turdsize=20
        opttolerance=0.3
        ;;
    auto)
        threshold=50
        alphamax=1.0
        turdsize=10
        opttolerance=0.2
        ;;
    custom)
        threshold="${4:?custom preset requires: threshold alphamax turdsize opttolerance}"
        alphamax="${5:?custom preset requires: threshold alphamax turdsize opttolerance}"
        turdsize="${6:?custom preset requires: threshold alphamax turdsize opttolerance}"
        opttolerance="${7:?custom preset requires: threshold alphamax turdsize opttolerance}"
        ;;
    *)
        echo "Unknown preset: $preset" >&2
        echo "Available: diagram, handwriting, document, auto, custom" >&2
        exit 1
        ;;
esac

echo "=== png2svg ==="
echo "Input:         $input"
echo "Output:        $output"
echo "Preset:        $preset"
echo "Threshold:     ${threshold}%"
echo "Alphamax:      $alphamax"
echo "Turdsize:      $turdsize"
echo "Opttolerance:  $opttolerance"
echo ""

magick "$input" \
    -colorspace Gray \
    -normalize \
    -threshold "${threshold}%" \
    pbm:- \
| potrace \
    --svg \
    --alphamax "$alphamax" \
    --turdsize "$turdsize" \
    --opttolerance "$opttolerance" \
    -o "$output"

echo "✓ SVG written to $output"
