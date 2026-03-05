#!/usr/bin/env bash
set -euo pipefail

# ── Usage ────────────────────────────────────────────────────────────
# bash pdf2img.sh <input.pdf> <output.png|jpg> [options]
#
# Options:
#   -p PAGE        Page number (default: 1, use "all" for every page)
#   -d DPI         Resolution (default: 300)
#   -w WIDTH       Scale to width in pixels (maintains aspect ratio)
#   -h HEIGHT      Scale to height in pixels (maintains aspect ratio)
#   -f FORMAT      Force format: png or jpeg (default: inferred from output extension)
#   -q QUALITY     JPEG quality 1-100 (default: 95, ignored for PNG)
# ─────────────────────────────────────────────────────────────────────

input="${1:?Usage: pdf2img.sh <input.pdf> <output> [options]}"
output="${2:?Usage: pdf2img.sh <input.pdf> <output> [options]}"
shift 2

page=1
dpi=300
width=""
height=""
format=""
quality=95

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p) page="$2"; shift 2 ;;
        -d) dpi="$2"; shift 2 ;;
        -w) width="$2"; shift 2 ;;
        -h) height="$2"; shift 2 ;;
        -f) format="$2"; shift 2 ;;
        -q) quality="$2"; shift 2 ;;
        *)  echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ ! -f "$input" ]]; then
    echo "Error: '$input' not found" >&2
    exit 1
fi

# Infer format from extension if not specified
if [[ -z "$format" ]]; then
    ext="${output##*.}"
    case "${ext,,}" in
        jpg|jpeg) format="jpeg" ;;
        *)        format="png" ;;
    esac
fi

info=$(pdfinfo "$input" 2>/dev/null) || { echo "Error: pdfinfo failed" >&2; exit 1; }
pages=$(echo "$info" | grep -i "^Pages:" | awk '{print $2}')

echo "=== pdf2img ==="
echo "Input:   $input ($pages pages)"
echo "Format:  $format"
echo "DPI:     $dpi"
[[ -n "$width" ]] && echo "Width:   $width px"
[[ -n "$height" ]] && echo "Height:  $height px"

render_page() {
    local p="$1" out="$2"
    local opts=(-"$format" -r "$dpi" -f "$p" -l "$p" -singlefile)
    [[ "$format" == "jpeg" ]] && opts+=(-jpegopt "quality=$quality")

    pdftocairo "${opts[@]}" "$input" "${out%.???}"

    # pdftocairo appends its own extension; find the actual file
    local actual
    if [[ "$format" == "jpeg" ]]; then
        actual="${out%.???}.jpg"
    else
        actual="${out%.???}.png"
    fi

    # Resize if requested
    if [[ -n "$width" || -n "$height" ]]; then
        local geom=""
        [[ -n "$width" && -n "$height" ]] && geom="${width}x${height}"
        [[ -n "$width" && -z "$height" ]] && geom="${width}x"
        [[ -z "$width" && -n "$height" ]] && geom="x${height}"
        magick "$actual" -resize "$geom" "$out"
        [[ "$actual" != "$out" ]] && rm -f "$actual"
    else
        [[ "$actual" != "$out" ]] && mv "$actual" "$out"
    fi

    echo "✓ Page $p → $out ($(magick identify -format '%wx%h' "$out"))"
}

if [[ "$page" == "all" ]]; then
    base="${output%.*}"
    ext="${output##*.}"
    for (( p=1; p<=pages; p++ )); do
        out="${base}_$(printf '%03d' "$p").${ext}"
        render_page "$p" "$out"
    done
else
    if (( page < 1 || page > pages )); then
        echo "Error: page $page out of range (1-$pages)" >&2
        exit 1
    fi
    render_page "$page" "$output"
fi
