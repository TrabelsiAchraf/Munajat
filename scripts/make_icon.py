#!/usr/bin/env python3
"""Generate Munajat app icon variants (light / dark / tinted) at 1024x1024.

Crescent + star are filled with a vertical gold gradient (cream → bronze)
matching the in-app HomeTitle calligraphy, with a soft warm halo for depth.
"""
from PIL import Image, ImageDraw, ImageChops, ImageFilter
from pathlib import Path
import math

OUT_DIR = Path('/Users/a.trabelsi/Workspace/Perso/Adhkar/Adhkar/Resources/Assets.xcassets/AppIcon.appiconset')
SIZE = 1024

# Gold palette — matches Adhkar/Design/CrescentStarPattern.swift + the
# in-app HomeTitle gradient (#FFF1C4 → #F2C66A → #B97A22).
GOLD_STOPS = [
    (0.00, '#FFF4CC'),  # very light cream highlight at the top
    (0.35, '#F2C66A'),  # warm gold mid
    (1.00, '#9D6418'),  # deep bronze shadow at the bottom
]

HALO_GOLD = '#F2C66A'


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def vertical_gradient(size, top_hex, bottom_hex):
    img = Image.new('RGB', (size, size))
    top = hex2rgb(top_hex)
    bot = hex2rgb(bottom_hex)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        for x in range(size):
            px[x, y] = (r, g, b)
    return img


def multi_stop_gradient(size, stops):
    """Vertical gradient with N color stops at fractional positions [0..1]."""
    img = Image.new('RGB', (size, size))
    px = img.load()
    rgb_stops = [(pos, hex2rgb(c)) for pos, c in stops]
    for y in range(size):
        t = y / (size - 1)
        for i in range(len(rgb_stops) - 1):
            p0, c0 = rgb_stops[i]
            p1, c1 = rgb_stops[i + 1]
            if p0 <= t <= p1:
                u = (t - p0) / (p1 - p0) if p1 > p0 else 0
                r = int(c0[0] + (c1[0] - c0[0]) * u)
                g = int(c0[1] + (c1[1] - c0[1]) * u)
                b = int(c0[2] + (c1[2] - c0[2]) * u)
                break
        else:
            r, g, b = rgb_stops[-1][1]
        for x in range(size):
            px[x, y] = (r, g, b)
    return img


def crescent_mask(size, scale=0.62):
    """Returns an L-mode alpha mask for a crescent (outer disk minus offset inner disk)."""
    mask = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(mask)
    cx = cy = size // 2
    r = int(size * scale * 0.5)
    inner_r = int(r * 0.92)
    offset = int(r * 0.32)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d.ellipse((cx - inner_r + offset, cy - inner_r,
               cx + inner_r + offset, cy + inner_r), fill=0)
    return mask


def star_mask(size):
    """L-mode alpha mask for a 5-point star near the crescent tip."""
    mask = Image.new('L', (size, size), 0)
    cx = int(size * 0.62)
    cy = int(size * 0.42)
    r_outer = int(size * 0.052)
    r_inner = r_outer * 0.42
    pts = []
    for i in range(10):
        angle = -math.pi / 2 + i * math.pi / 5
        rr = r_outer if i % 2 == 0 else r_inner
        pts.append((cx + rr * math.cos(angle), cy + rr * math.sin(angle)))
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    return mask


def paint_gradient(bg, shape_mask, gradient):
    """Paint `gradient` onto `bg` only where `shape_mask` is opaque."""
    gold_layer = gradient.convert('RGBA').copy()
    gold_layer.putalpha(shape_mask)
    bg.alpha_composite(gold_layer)


def add_halo(bg, shape_mask, color_hex, blur=44, opacity=110):
    """Soft warm halo behind the gold foreground."""
    halo_color = Image.new('RGBA', bg.size, (*hex2rgb(color_hex), 0))
    solid = Image.new('RGBA', bg.size, (*hex2rgb(color_hex), opacity))
    halo_color.paste(solid, (0, 0), shape_mask)
    glow = halo_color.filter(ImageFilter.GaussianBlur(blur))
    bg.alpha_composite(glow)


def render(background_top, background_bottom, output_path):
    bg = vertical_gradient(SIZE, background_top, background_bottom).convert('RGBA')
    gradient = multi_stop_gradient(SIZE, GOLD_STOPS)

    c_mask = crescent_mask(SIZE)
    s_mask = star_mask(SIZE)
    combined = ImageChops.lighter(c_mask, s_mask)

    add_halo(bg, combined, HALO_GOLD)
    paint_gradient(bg, c_mask, gradient)
    paint_gradient(bg, s_mask, gradient)

    bg.convert('RGB').save(output_path, 'PNG')


# ---- Light variant: deep blue gradient + gold crescent ----
render('#3A55C7', '#162269', OUT_DIR / 'icon-light.png')

# ---- Dark variant: very deep navy + gold crescent ----
render('#0F1740', '#050714', OUT_DIR / 'icon-dark.png')

# ---- Tinted variant: grayscale (Apple system applies the tint) ----
tinted = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))
c_mask = crescent_mask(SIZE)
s_mask = star_mask(SIZE)
for mask in (c_mask, s_mask):
    white = Image.new('RGBA', (SIZE, SIZE), (255, 255, 255, 255))
    white.putalpha(mask)
    tinted.alpha_composite(white)
tinted.convert('RGB').save(OUT_DIR / 'icon-tinted.png', 'PNG')

# ---- macOS variants: downsampled from the light icon ----
mac_master = Image.open(OUT_DIR / 'icon-light.png')
MAC_SIZES = [
    ('icon-mac-16x16.png', 16),
    ('icon-mac-16x16@2x.png', 32),
    ('icon-mac-32x32.png', 32),
    ('icon-mac-32x32@2x.png', 64),
    ('icon-mac-128x128.png', 128),
    ('icon-mac-128x128@2x.png', 256),
    ('icon-mac-256x256.png', 256),
    ('icon-mac-256x256@2x.png', 512),
    ('icon-mac-512x512.png', 512),
    ('icon-mac-512x512@2x.png', 1024),
]
for name, dim in MAC_SIZES:
    mac_master.resize((dim, dim), Image.LANCZOS).save(OUT_DIR / name, 'PNG')

print("Generated:")
for p in sorted(OUT_DIR.glob('icon-*.png')):
    print(f"  {p.name} ({p.stat().st_size // 1024} KB)")
