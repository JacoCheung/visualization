---
name: pickiller
description: Convert between image (PNG/JPG), PDF, and SVG formats. Crop ID photos to standard sizes and change background color. Use when the user wants to convert between image/PDF/SVG, make ID photos (证件照), change photo background, or mentions vectorization, tracing, perspective correction.
---

# Pickiller — Image / PDF / SVG Converter

## Prerequisites

```bash
bash scripts/setup.sh
```

Dependencies: `imagemagick`, `potrace`, `poppler`, `librsvg`.

## Input Routing

Determine the conversion path based on input → output:

- **PNG / JPG → SVG** → [Image to SVG](#image-to-svg)
- **PDF → SVG** → [PDF to SVG](#pdf-to-svg)
- **PDF → PNG / JPG** → [PDF to Image](#pdf-to-image)
- **SVG → PDF** → [SVG to PDF](#svg-to-pdf)
- **证件照裁剪 / 换底色** → [ID Photo](#id-photo)

---

## Image to SVG

```
- [ ] Step 1: Analyze image
- [ ] Step 2: Perspective correction
- [ ] Step 3: Vectorize
- [ ] Step 4: Verify
```

### Step 1: Analyze image

Read the image with your vision capability. Determine:

1. **Content type**: `diagram` | `handwriting` | `document` | `auto`
2. **Perspective distortion**: Trapezoids, non-parallel lines?
3. **Dimensions**: `magick identify <input>`

No distortion → skip to Step 3.

### Step 2: Perspective correction

Identify the four corner pixel coordinates of the content region (TL, TR, BR, BL):

```bash
bash scripts/warp.sh <input> TLx,TLy TRx,TRy BRx,BRy BLx,BLy -o corrected.png
```

Read output to verify. Adjust corners and re-run if needed.

### Step 3: Vectorize

```bash
bash scripts/png2svg.sh <input.png> output.svg <preset>
```

Presets: `diagram`, `handwriting`, `document`, `auto`, or `custom <threshold> <alphamax> <turdsize> <opttolerance>`.

### Step 4: Verify

Read the SVG. If quality is insufficient, consult [reference.md](reference.md) and re-run with `custom` preset.

---

## PDF to SVG

```
- [ ] Step 1: Inspect PDF
- [ ] Step 2: Convert
- [ ] Step 3: Verify
```

### Step 1: Inspect PDF

```bash
pdfinfo <input.pdf>
```

Check page count and whether content is vector or scanned (read the PDF to determine visually).

### Step 2: Convert

**Vector PDF** (CAD exports, Office docs, digital diagrams):

```bash
bash scripts/pdf2svg.sh <input.pdf> output.svg -m vector -p <page>
```

Preserves paths, text, shapes losslessly via `pdftocairo`.

**Scanned PDF** (photos, scans embedded in PDF):

```bash
bash scripts/pdf2svg.sh <input.pdf> output.svg -m raster -p <page> -d 300 --preset diagram
```

Rasterizes at high DPI, then traces with potrace. Adjust `-d` (DPI) and `--preset` as needed.

**Auto mode** (default — tries vector first, falls back to raster):

```bash
bash scripts/pdf2svg.sh <input.pdf> output.svg
```

### Step 3: Verify

Read the output SVG. For raster conversions, check trace quality and adjust preset/DPI if needed.

---

## PDF to Image

### Step 1: Inspect PDF and ask user for output size

Run `pdfinfo <input.pdf>` to get page size, then use AskQuestion to let the user pick:

```
Question 1: Output format?
  - PNG (lossless)
  - JPG (smaller file)

Question 2: Output size?
  - Original (match PDF page proportions at 300 DPI)
  - 4K (3840×2160)
  - 2K / QHD (2560×1440)
  - 1080p (1920×1080)
  - 720p (1280×720)
  - A4 Print 300DPI (2480×3508)
  - A4 Print 150DPI (1240×1754)
  - Custom (ask user for width×height)

Question 3 (if multi-page): Which pages?
  - All pages
  - Specific page number
```

### Step 2: Convert

```bash
bash scripts/pdf2img.sh <input.pdf> <output.png|jpg> [options]
```

Options:

- `-p PAGE` — page number, or `all` for every page (default: 1)
- `-d DPI` — resolution (default: 300)
- `-w WIDTH` — scale to width in pixels (keeps aspect ratio)
- `-h HEIGHT` — scale to height in pixels (keeps aspect ratio)
- `-f FORMAT` — force `png` or `jpeg` (default: from extension)
- `-q QUALITY` — JPEG quality 1-100 (default: 95)

Map user's size choice to `-w`/`-h` flags. For "Original", use only `-d 300` without `-w`/`-h`.

---

## SVG to PDF

```bash
bash scripts/svg2pdf.sh <input.svg> <output.pdf> [-d DPI] [-w WIDTH] [-h HEIGHT]
```

Vector-preserving conversion via `rsvg-convert`. Options:

- `-d DPI` — rasterization DPI for embedded images (default: 300)
- `-w WIDTH` — scale to width (pixels)
- `-h HEIGHT` — scale to height (pixels)

---

## ID Photo

### Step 1: Ask user for requirements

Use AskQuestion to gather:

```
Question 1: 照片尺寸？
  - 1寸 (25×35mm, 295×413px) — 身份证、驾照、医保卡
  - 小2寸 (33×48mm, 390×567px) — 护照、港澳通行证
  - 2寸 (35×49mm, 413×579px) — 户口本、结婚证
  - 大2寸 (35×53mm, 413×626px) — 部分签证
  - 自定义尺寸

Question 2: 底色？
  - 白底 — 护照、签证
  - 蓝底 — 身份证、简历
  - 红底 — 部分证件
  - 保持原色
  - 自定义颜色 (hex)
```

### Step 2: Inspect image

Read the photo with vision. Check:

1. Is the person centered? What gravity should be used? (default: `North` keeps head at top)
2. If changing background: what is the current background color? Is it solid?
3. If background is complex (not solid), warn user that `--fuzz` may need adjustment or result may not be clean.

### Step 3: Run

```bash
bash scripts/idphoto.sh <input> <output> -s SIZE [-b BG_COLOR] [-g GRAVITY] [--fuzz PCT]
```

Size presets: `1inch` `1寸` `1inch_sm` `小1寸` `2inch_sm` `小2寸` `2inch` `2寸` `2inch_lg` `大2寸` `5inch` `5寸` `6inch` `6寸`, or custom `WxH`.

Background presets: `white` `蓝` `blue` `红` `red`, or hex like `#438EDB`.

Options:

- `-g GRAVITY` — crop anchor: `North` (default), `Center`, `South`
- `--fuzz PCT` — color tolerance for background replacement (default: 20%)
- `--src-bg CLR` — override source background color (default: auto-detect from corners)

### Step 4: Verify

Read output. If background replacement has artifacts, adjust `--fuzz` (higher = more aggressive, lower = more precise) or specify `--src-bg` explicitly.

---

## Troubleshooting

- **Output too noisy**: Increase `turdsize` or raise threshold
- **Missing detail**: Decrease `opttolerance` and `alphamax`
- **Uneven lighting**: Use `-lat` adaptive threshold (see [reference.md](reference.md))
- **Colored content**: See color separation in [reference.md](reference.md)
- **Multi-page PDF**: Run `pdf2svg.sh` once per page with `-p`
