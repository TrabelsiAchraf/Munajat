#!/usr/bin/env python3
"""Generate Adhkar app icon variants (light / dark / tinted) at 1024x1024
and macOS multi-resolution outputs."""
from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import math

OUT_DIR = Path('/Users/a.trabelsi/Workspace/Perso/Adhkar/Adhkar/Assets.xcassets/AppIcon.appiconset')
SIZE = 1024

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

def draw_crescent(img, color, opacity=255, scale=0.62):
    """Draw a crescent moon (outer disk minus offset inner disk)."""
    size = img.size[0]
    cx = cy = size // 2
    r = int(size * scale * 0.5)            # outer radius
    inner_r = int(r * 0.92)                # inner radius (creates the crescent thickness)
    offset = int(r * 0.32)                 # offset of inner disk → controls crescent shape

    # Draw outer disk on a transparent layer
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    fill = (*color, opacity)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)
    # Carve inner disk to make the crescent
    d.ellipse((cx - inner_r + offset, cy - inner_r,
               cx + inner_r + offset, cy + inner_r), fill=(0, 0, 0, 0))
    img.paste(layer, (0, 0), layer)
    return img

def draw_star(img, color, opacity=255):
    """Small 5-point star to the right of the crescent's tip."""
    size = img.size[0]
    cx = int(size * 0.62)
    cy = int(size * 0.42)
    r_outer = int(size * 0.045)
    r_inner = r_outer * 0.42
    pts = []
    for i in range(10):
        angle = -math.pi/2 + i * math.pi / 5
        rr = r_outer if i % 2 == 0 else r_inner
        pts.append((cx + rr * math.cos(angle), cy + rr * math.sin(angle)))
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts, fill=(*color, opacity))
    img.paste(layer, (0, 0), layer)
    return img

def soft_glow(img, glow_layer, blur=20, opacity=80):
    """Add a soft halo behind the foreground for depth."""
    glow = glow_layer.filter(ImageFilter.GaussianBlur(blur))
    glow.putalpha(opacity)
    img.paste(glow, (0, 0), glow)
    return img

# ---- Light variant ----
light = vertical_gradient(SIZE, '#314DD0', '#1A2B6E').convert('RGBA')
draw_crescent(light, (255, 255, 255), opacity=255)
draw_star(light, (255, 255, 255), opacity=255)
light.convert('RGB').save(OUT_DIR / 'icon-light.png', 'PNG')

# ---- Dark variant ----
dark = vertical_gradient(SIZE, '#0F1740', '#050714').convert('RGBA')
draw_crescent(dark, (235, 240, 255), opacity=255)
draw_star(dark, (235, 240, 255), opacity=255)
dark.convert('RGB').save(OUT_DIR / 'icon-dark.png', 'PNG')

# ---- Tinted variant (iOS 18 monochrome icon — system applies tint) ----
# Per Apple: provide a grayscale image with luminance representing where the
# tint should appear (white = full tint, black = no tint / background).
tinted = Image.new('RGB', (SIZE, SIZE), (0, 0, 0))
draw_crescent(tinted.convert('RGBA').copy(), (255, 255, 255), opacity=255).convert('RGB')
# Build it explicitly to ensure RGB output
tinted_rgba = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255))
draw_crescent(tinted_rgba, (255, 255, 255), opacity=255)
draw_star(tinted_rgba, (255, 255, 255), opacity=255)
tinted_rgba.convert('RGB').save(OUT_DIR / 'icon-tinted.png', 'PNG')

print("Generated:")
for p in OUT_DIR.glob('icon-*.png'):
    print(f"  {p.name} ({p.stat().st_size // 1024} KB)")
