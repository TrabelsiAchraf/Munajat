#!/usr/bin/env python3
"""
App Store screenshot compositor for Munajat.

Inputs  : marketing/raw/<lang>/<screen>.png   (raw simulator captures)
          marketing/config/copy.json          (titles + subtitles)
Outputs : marketing/out/<lang>/<n>_<screen>.png  (1320×2868, App Store ready)

Style: deep navy gradient + soft crescents + bold Amiri title at top,
device-screenshot floating below with rounded corners and a drop shadow.
"""

from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, features

# HarfBuzz/Raqm gives proper Arabic shaping, ligatures and kerning. Falls back
# to the legacy reshape+bidi pipeline if Pillow was built without it.
_USE_RAQM = features.check("raqm")
if _USE_RAQM:
    _LAYOUT = ImageFont.Layout.RAQM
else:
    _LAYOUT = ImageFont.Layout.BASIC
    import arabic_reshaper
    from bidi.algorithm import get_display

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

SIZES = {
    "6.5":    (1242, 2688),  # iPhone XS Max / 11 Pro Max
    "6.7":    (1284, 2778),  # iPhone 12–15 Pro Max (also fits the 6.5" slot)
    "6.9":    (1320, 2868),  # iPhone 16/17 Pro Max  (new dedicated slot)
    "ipad13": (2064, 2752),  # iPad Pro 13" M4/M5     (required for universal apps)
}
CANVAS_W, CANVAS_H = SIZES["6.7"]   # default: maximum compatibility

PAD_H            = 96    # horizontal padding for text
TITLE_TOP_PAD    = 180   # top margin before title
TITLE_SUBTITLE_GAP = 70   # base gap; Arabic adds more (descenders need room)
TITLE_SUBTITLE_GAP_AR_EXTRA = 30
DEVICE_TOP_GAP   = 110   # gap between subtitle and device
DEVICE_WIDTH     = int(CANVAS_W * 0.78)   # device width on canvas
DEVICE_RADIUS    = 86    # rounded corners of the screenshot
DEVICE_SHADOW_BLUR = 90
DEVICE_SHADOW_OFFSET_Y = 30
DEVICE_SHADOW_ALPHA = 140

TITLE_PT_LATIN   = 110
TITLE_PT_ARABIC  = 120
SUBTITLE_PT      = 48
TITLE_LH_LATIN   = 1.05
TITLE_LH_ARABIC  = 1.30   # Arabic descenders (ك, ج, …) need extra room
SUBTITLE_LH      = 1.35

BG_TOP   = (10, 20, 40)     # deep navy (matches AdaptiveBackground top)
BG_BOT   = (4, 6, 14)       # near-black (matches AdaptiveBackground bottom)
ACCENT   = (255, 159, 28)   # app's orange — used sparingly

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO = Path(__file__).resolve().parents[1]
FONT_BOLD = REPO / "Adhkar" / "Resources" / "Amiri-Bold.ttf"
FONT_REG  = REPO / "Adhkar" / "Resources" / "Amiri-Regular.ttf"
RAW_DIR   = REPO / "marketing" / "raw"
OUT_DIR   = REPO / "marketing" / "out"
COPY_FILE = REPO / "marketing" / "config" / "copy.json"


# ---------------------------------------------------------------------------
# Text helpers
# ---------------------------------------------------------------------------

ARABIC_RANGE = (0x0600, 0x06FF)


def _is_arabic(text: str) -> bool:
    return any(ARABIC_RANGE[0] <= ord(c) <= ARABIC_RANGE[1] for c in text)


def shape_for_drawing(text: str) -> str:
    """Reshape + apply bidi so Pillow renders Arabic correctly.

    No-op when the RAQM layout engine is available — HarfBuzz does both
    shaping and bidi reordering on the raw codepoints.
    """
    if _USE_RAQM or not _is_arabic(text):
        return text
    return get_display(arabic_reshaper.reshape(text))


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    """Greedy word wrap. Works for LTR + RTL (we pre-shape arabic before measuring)."""
    words = text.split()
    if not words:
        return []
    lines: list[str] = []
    current = words[0]
    for w in words[1:]:
        candidate = f"{current} {w}"
        if draw.textlength(shape_for_drawing(candidate), font=font) <= max_w:
            current = candidate
        else:
            lines.append(current)
            current = w
    lines.append(current)
    return lines


# ---------------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------------

def gradient_background() -> Image.Image:
    img = Image.new("RGB", (CANVAS_W, CANVAS_H), BG_BOT)
    px  = img.load()
    for y in range(CANVAS_H):
        t = y / (CANVAS_H - 1)
        # ease-out so the top stays rich navy longer
        t = 1 - (1 - t) ** 2
        r = int(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
        g = int(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
        b = int(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
        for x in range(CANVAS_W):
            px[x, y] = (r, g, b)
    return img


def crescent(diameter: int, alpha: int, color=(212, 175, 55)) -> Image.Image:
    """Tiny gold crescent on a transparent canvas, à la in-app CrescentStarPattern."""
    pad = diameter // 3
    size = diameter + pad * 2
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Outer disk
    d.ellipse((pad, pad, pad + diameter, pad + diameter), fill=(*color, alpha))
    # Inner disk subtracted by drawing background colour, slight offset
    off = diameter // 5
    d.ellipse((pad + off, pad, pad + off + diameter, pad + diameter), fill=(0, 0, 0, 0))
    # Re-draw with proper alpha subtraction
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse((pad, pad, pad + diameter, pad + diameter), fill=alpha)
    md.ellipse((pad + off, pad, pad + off + diameter, pad + diameter), fill=0)
    layer.putalpha(mask)
    # Recolour to gold
    base = Image.new("RGBA", layer.size, (*color, 255))
    base.putalpha(mask)
    return base


def scatter_crescents(bg: Image.Image, count: int = 9, seed: int = 7) -> Image.Image:
    rnd = random.Random(seed)
    out = bg.copy()
    title_zone_bottom = int(CANVAS_H * 0.32)   # stay in the top band
    for _ in range(count):
        diam = rnd.randint(28, 78)
        alpha = rnd.randint(28, 68)
        x = rnd.randint(40, CANVAS_W - diam - 40)
        y = rnd.randint(40, title_zone_bottom)
        c = crescent(diam, alpha)
        # rotate randomly so they don't all face the same way
        c = c.rotate(rnd.randint(-45, 45), resample=Image.BICUBIC, expand=True)
        out.alpha_composite(c.convert("RGBA"), dest=(x, y)) if out.mode == "RGBA" \
            else out.paste(c, (x, y), c)
    return out


# ---------------------------------------------------------------------------
# Device frame
# ---------------------------------------------------------------------------

def rounded_screenshot(raw: Image.Image, target_w: int, radius: int) -> Image.Image:
    ratio = raw.height / raw.width
    target_h = int(target_w * ratio)
    img = raw.resize((target_w, target_h), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (target_w, target_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, target_w, target_h), radius=radius, fill=255)
    img.putalpha(mask)
    return img


def with_shadow(layer: Image.Image, blur: int, alpha: int, offset_y: int) -> Image.Image:
    pad = blur * 2
    canvas = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2 + offset_y), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sh_mask = layer.split()[-1]
    shadow_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_layer.paste((0, 0, 0, alpha), (pad, pad + offset_y), sh_mask)
    shadow = shadow_layer.filter(ImageFilter.GaussianBlur(blur))
    out = Image.alpha_composite(canvas, shadow)
    out.alpha_composite(layer, dest=(pad, pad))
    return out


# ---------------------------------------------------------------------------
# Composition
# ---------------------------------------------------------------------------

@dataclass
class Copy:
    title: str
    subtitle: str


def draw_title_block(canvas: Image.Image, copy: Copy, is_arabic: bool) -> int:
    """Draws title + subtitle starting at TITLE_TOP_PAD. Returns the y where text ends."""
    draw = ImageDraw.Draw(canvas)

    title_font_size = TITLE_PT_ARABIC if is_arabic else TITLE_PT_LATIN
    title_font    = ImageFont.truetype(str(FONT_BOLD), title_font_size, layout_engine=_LAYOUT)
    subtitle_font = ImageFont.truetype(str(FONT_REG),  SUBTITLE_PT,    layout_engine=_LAYOUT)

    max_w = CANVAS_W - PAD_H * 2

    title_lines    = wrap_text(draw, copy.title, title_font, max_w)
    subtitle_lines = wrap_text(draw, copy.subtitle, subtitle_font, max_w)

    x = CANVAS_W // 2
    y = TITLE_TOP_PAD

    title_lh = TITLE_LH_ARABIC if is_arabic else TITLE_LH_LATIN
    title_line_h = int(title_font_size * title_lh)
    for line in title_lines:
        draw.text((x, y), shape_for_drawing(line), font=title_font, fill="white", anchor="ma")
        y += title_line_h

    y += TITLE_SUBTITLE_GAP + (TITLE_SUBTITLE_GAP_AR_EXTRA if is_arabic else 0)

    sub_color = (255, 255, 255, 175)
    sub_line_h = int(SUBTITLE_PT * SUBTITLE_LH)
    for line in subtitle_lines:
        draw.text((x, y), shape_for_drawing(line), font=subtitle_font, fill=sub_color, anchor="ma")
        y += sub_line_h

    return y


def composite_screen(raw_path: Path, copy: Copy, is_arabic: bool, out_path: Path) -> None:
    bg = gradient_background().convert("RGBA")
    bg = scatter_crescents(bg)

    text_bottom = draw_title_block(bg, copy, is_arabic)

    raw = Image.open(raw_path).convert("RGB")
    device = rounded_screenshot(raw, DEVICE_WIDTH, DEVICE_RADIUS)
    framed = with_shadow(device, blur=DEVICE_SHADOW_BLUR, alpha=DEVICE_SHADOW_ALPHA, offset_y=DEVICE_SHADOW_OFFSET_Y)

    dx = (CANVAS_W - framed.width) // 2
    dy = text_bottom + DEVICE_TOP_GAP
    # Clamp so the device doesn't run past the canvas bottom — scale further if it would
    if dy + framed.height > CANVAS_H - 40:
        scale = (CANVAS_H - 40 - dy) / framed.height
        new_w = int(framed.width * scale)
        new_h = int(framed.height * scale)
        framed = framed.resize((new_w, new_h), Image.LANCZOS)
        dx = (CANVAS_W - framed.width) // 2

    bg.alpha_composite(framed, dest=(dx, dy))
    bg.convert("RGB").save(out_path, "PNG", optimize=True)


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Compose App Store screenshots.")
    parser.add_argument("--size", choices=sorted(SIZES.keys()), default="6.7",
                        help="Target device size (default: 6.7\" iPhone).")
    args = parser.parse_args()

    global CANVAS_W, CANVAS_H
    CANVAS_W, CANVAS_H = SIZES[args.size]

    # iPad raws/outs live in a parallel tree to keep the iPhone deliverables
    # untouched. iPhone sizes share the legacy `raw/` and `out/` folders.
    is_ipad = args.size.startswith("ipad")
    raw_root = REPO / "marketing" / ("raw_" + args.size if is_ipad else "raw")
    out_root = REPO / "marketing" / ("out_" + args.size if is_ipad else "out")

    # On iPad the device is wider relative to height, so screenshots benefit
    # from larger padding around the device — adjust per canvas to keep
    # consistent visual weight.
    global DEVICE_WIDTH
    DEVICE_WIDTH = int(CANVAS_W * (0.66 if is_ipad else 0.78))

    config = json.loads(COPY_FILE.read_text())
    screens = config["screens"]

    found = 0
    missing: list[str] = []

    for lang in ("fr", "en", "ar"):
        is_arabic = lang == "ar"
        for idx, screen in enumerate(screens, start=1):
            slug = screen["slug"]
            raw_path = raw_root / lang / f"{slug}.png"
            out_path = out_root / lang / f"{idx:02d}_{slug}.png"
            if not raw_path.exists():
                missing.append(str(raw_path.relative_to(REPO)))
                continue
            out_path.parent.mkdir(parents=True, exist_ok=True)
            entry = screen[lang]
            copy = Copy(title=entry["title"], subtitle=entry["subtitle"])
            composite_screen(raw_path, copy, is_arabic, out_path)
            found += 1
            print(f"✓ {out_path.relative_to(REPO)}")

    if missing:
        print(f"\n{len(missing)} raw screenshot(s) missing — placeholders skipped:")
        for m in missing:
            print(f"  · {m}")
    print(f"\nGenerated {found} marketing screenshot(s).")


if __name__ == "__main__":
    main()
