#!/usr/bin/env bash
set -euo pipefail

# Perspective correction using ImageMagick.
# The Agent identifies four corner coordinates via visual analysis,
# then calls this script to apply the homography transform.
#
# Usage:
#   bash warp.sh <input> <TLx,TLy> <TRx,TRy> <BRx,BRy> <BLx,BLy> [-o output.png]
#
# Corner order: top-left, top-right, bottom-right, bottom-left.

input="${1:?Usage: warp.sh input TL TR BR BL [-o output]}"
tl="${2:?Missing top-left corner (x,y)}"
tr="${3:?Missing top-right corner (x,y)}"
br="${4:?Missing bottom-right corner (x,y)}"
bl="${5:?Missing bottom-left corner (x,y)}"

output="corrected.png"
if [[ "${6:-}" == "-o" ]]; then
    output="${7:?Missing output path after -o}"
fi

IFS=',' read -r tl_x tl_y <<< "$tl"
IFS=',' read -r tr_x tr_y <<< "$tr"
IFS=',' read -r br_x br_y <<< "$br"
IFS=',' read -r bl_x bl_y <<< "$bl"

# Compute output dimensions from corner distances
read -r W H <<< "$(awk "BEGIN {
    w1 = sqrt(($tr_x-$tl_x)^2 + ($tr_y-$tl_y)^2)
    w2 = sqrt(($br_x-$bl_x)^2 + ($br_y-$bl_y)^2)
    h1 = sqrt(($bl_x-$tl_x)^2 + ($bl_y-$tl_y)^2)
    h2 = sqrt(($br_x-$tr_x)^2 + ($br_y-$tr_y)^2)
    printf \"%d %d\", (w1>w2?w1:w2), (h1>h2?h1:h2)
}")"

Wm=$((W - 1))
Hm=$((H - 1))

magick "$input" \
    -distort Perspective \
    "${tl_x},${tl_y},0,0  ${tr_x},${tr_y},${Wm},0  ${br_x},${br_y},${Wm},${Hm}  ${bl_x},${bl_y},0,${Hm}" \
    -crop "${W}x${H}+0+0" +repage \
    "$output"

echo "Warped: TL=($tl_x,$tl_y) TR=($tr_x,$tr_y) BR=($br_x,$br_y) BL=($bl_x,$bl_y)"
echo "Output: ${W}x${H} → $output"
