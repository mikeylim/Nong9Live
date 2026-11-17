#!/usr/bin/env python3
"""Renders the app icon (a shaded basketball) as PNGs, pure Python.

Run from the project root, then apply with flutter_launcher_icons:
    python3 tool/generate_icon.py
    dart run flutter_launcher_icons
"""

import math
import os
import struct
import zlib

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')
SIZE = 1024

BG_TOP = (0x23, 0x27, 0x3A)
BG_BOTTOM = (0x0E, 0x10, 0x18)
BALL = (0xFF, 0x7A, 0x1A)
SEAM = (0x2A, 0x14, 0x08)
RING = (0xFF, 0xB2, 0x5E)


def smooth(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(len(a)))


def over(dst, src, alpha):
    """Composite src (rgb) at alpha over dst (rgba)."""
    a = alpha + dst[3] * (1 - alpha)
    if a <= 0:
        return (0.0, 0.0, 0.0, 0.0)
    rgb = tuple((src[i] * alpha + dst[i] * dst[3] * (1 - alpha)) / a for i in range(3))
    return rgb + (a,)


def ball_pixel(px, py, cx, cy, r, base):
    """Returns the composited pixel for the ball layer over `base`."""
    dx, dy = px - cx, py - cy
    dist = math.hypot(dx, dy)
    aa = 1.2  # anti-alias width in pixels
    cover = 1 - smooth(r - aa, r + aa, dist)
    if cover <= 0:
        # soft outer glow
        glow = max(0.0, 1 - (dist - r) / (r * 0.35))
        if glow > 0:
            return over(base, RING, 0.10 * glow * glow)
        return base

    # unit sphere coordinates for shading
    ux, uy = dx / r, dy / r
    uz = math.sqrt(max(0.0, 1 - ux * ux - uy * uy))
    lx, ly, lz = -0.45, -0.55, 0.70
    lambert = max(0.0, ux * lx + uy * ly + uz * lz)
    shade = 0.45 + 0.65 * lambert
    spec = max(0.0, lambert) ** 18 * 0.35
    col = tuple(min(255, c * shade + 255 * spec) for c in BALL)

    # seams, in a rotated frame so the ball looks like it is spinning
    ang = math.radians(-24)
    sx = (dx * math.cos(ang) - dy * math.sin(ang)) / r
    sy = (dx * math.sin(ang) + dy * math.cos(ang)) / r
    w = 0.028  # seam half width (unit radius)
    px_unit = 1.0 / r
    seam_d = min(
        abs(sx),                                   # vertical seam
        abs(sy),                                   # horizontal seam
        abs(math.hypot(sx - 1.18, sy) - 0.78),     # right curve
        abs(math.hypot(sx + 1.18, sy) - 0.78),     # left curve
    )
    seam_a = 1 - smooth(w - px_unit * 1.2, w + px_unit * 1.2, seam_d)
    seam_col = tuple(c * (0.6 + 0.4 * shade) for c in SEAM)
    col = lerp(col, seam_col, seam_a)

    # dark rim for definition
    rim = smooth(r - r * 0.045, r - r * 0.005, dist)
    col = lerp(col, SEAM, rim * 0.85)
    return over(base, col, cover)


def render(path, with_bg, ball_radius):
    rows = []
    cx = cy = SIZE / 2
    for y in range(SIZE):
        row = bytearray([0])  # PNG filter type 0
        t = y / (SIZE - 1)
        bg = lerp(BG_TOP, BG_BOTTOM, t) + (1.0,) if with_bg else (0.0, 0.0, 0.0, 0.0)
        for x in range(SIZE):
            p = ball_pixel(x + 0.5, y + 0.5, cx, cy, ball_radius, bg)
            row += bytes((int(p[0]), int(p[1]), int(p[2]), int(p[3] * 255)))
        rows.append(bytes(row))
    raw = b''.join(rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(png)
    print('  wrote', os.path.normpath(path))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    render(os.path.join(OUT, 'icon.png'), with_bg=True, ball_radius=SIZE * 0.33)
    # adaptive icon foreground must sit inside the 66% safe zone
    render(os.path.join(OUT, 'icon_foreground.png'), with_bg=False, ball_radius=SIZE * 0.25)
