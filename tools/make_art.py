#!/usr/bin/env python3
"""Draws Waypost's flat textures (logo, map pin, dot) as 32-bit TGA. Needs Pillow.
The 3D arrow sheet comes from make_arrow3d.py."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Waypost", "Media")
SS = 8


EMBLEM = os.path.join(os.path.dirname(OUT), "..", "listing", "source", "emblem.webp")
EMBLEM_CIRCLE = (1010, 981, 892)   # centre x, centre y, radius of the medallion in the source art


def emblem(size):
    """The painted emblem (listing/source/emblem.webp), cut to its medallion with a soft edge."""
    cx, cy, r = EMBLEM_CIRCLE
    im = Image.open(EMBLEM).convert("RGBA").crop((cx - r - 8, cy - r - 8, cx + r + 8, cy + r + 8))
    n = im.size[0]
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).ellipse([8, 8, n - 8, n - 8], fill=255)
    im.putalpha(mask.filter(ImageFilter.GaussianBlur(3)))
    out = im.resize((size, size), Image.LANCZOS)
    if size <= 96:
        out = out.filter(ImageFilter.UnsharpMask(radius=1, percent=80, threshold=2))
    return out


def logo(size=64):
    """The logo: the painted emblem when its source art is in the repo, else the drawn signpost."""
    if os.path.exists(EMBLEM):
        return emblem(size)
    return drawn_logo(size)


def drawn_logo(size=64):
    """A signpost: gold ring, dark field, two pointing boards on a post."""
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = n / 64.0
    d.ellipse([2 * u, 2 * u, 62 * u, 62 * u], fill=(196, 152, 58, 255))
    d.ellipse([5 * u, 5 * u, 59 * u, 59 * u], fill=(246, 213, 120, 255))
    d.ellipse([7 * u, 7 * u, 57 * u, 57 * u], fill=(34, 24, 14, 255))
    d.ellipse([9 * u, 9 * u, 55 * u, 55 * u], fill=(58, 40, 22, 255))
    # post
    d.rectangle([30 * u, 16 * u, 34 * u, 50 * u], fill=(150, 104, 54, 255))
    d.rectangle([30 * u, 16 * u, 31.3 * u, 50 * u], fill=(190, 140, 80, 255))
    d.polygon([(26 * u, 50 * u), (38 * u, 50 * u), (36 * u, 47 * u), (28 * u, 47 * u)], fill=(120, 82, 42, 255))
    # boards
    def board(y, right, col, hi):
        if right:
            pts = [(20 * u, y), (40 * u, y), (46 * u, y + 4 * u), (40 * u, y + 8 * u), (20 * u, y + 8 * u)]
        else:
            pts = [(44 * u, y), (24 * u, y), (18 * u, y + 4 * u), (24 * u, y + 8 * u), (44 * u, y + 8 * u)]
        d.polygon(pts, fill=col)
        d.line([pts[0], pts[1]], fill=hi, width=int(1.2 * u))
    board(19 * u, True, (240, 200, 96, 255), (255, 236, 170, 255))
    board(30 * u, False, (212, 168, 70, 255), (244, 214, 140, 255))
    return img.resize((size, size), Image.LANCZOS)


def pin(size=32):
    """Map pin: a ring with a dark centre, in greys so it can be tinted."""
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = n / 32.0
    d.ellipse([1 * u, 1 * u, 31 * u, 31 * u], fill=(20, 20, 20, 255))
    d.ellipse([2.5 * u, 2.5 * u, 29.5 * u, 29.5 * u], fill=(255, 255, 255, 255))
    d.ellipse([5.5 * u, 5.5 * u, 26.5 * u, 26.5 * u], fill=(28, 24, 20, 255))
    return img.resize((size, size), Image.LANCZOS)


def dot(size=16):
    """Small soft dot for objective areas."""
    n = size * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = n / 16.0
    d.ellipse([1 * u, 1 * u, 15 * u, 15 * u], fill=(20, 20, 20, 230))
    d.ellipse([3 * u, 3 * u, 13 * u, 13 * u], fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


def glow(size=128):
    """Soft round glow, white with alpha falling off to the edge. Drawn additively behind the level-up text."""
    n = size
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    px = img.load()
    c = (n - 1) / 2.0
    for y in range(n):
        for x in range(n):
            d = (((x - c) ** 2 + (y - c) ** 2) ** 0.5) / c
            a = max(0.0, 1.0 - d) ** 2.2
            px[x, y] = (255, 255, 255, int(255 * a))
    return img


def burst(size=256, rays=14):
    """Rays fanning out from the centre, fading toward the rim. Spun slowly behind the level-up text."""
    import math
    n = size * 2
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    c = n / 2.0
    for k in range(rays):
        a = 2 * math.pi * k / rays
        w = math.pi / rays * (0.55 if k % 2 == 0 else 0.32)
        r = c * (0.98 if k % 2 == 0 else 0.74)
        d.polygon([(c, c), (c + r * math.cos(a - w), c + r * math.sin(a - w)), (c + r * math.cos(a + w), c + r * math.sin(a + w))], fill=255)
    img = img.filter(ImageFilter.GaussianBlur(3)).resize((size, size), Image.LANCZOS)
    fade = glow(size).split()[3].point(lambda v: min(255, int(v * 2.4)))
    alpha = ImageChops.multiply(img, fade)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".tga"), compression=None, orientation=1)  # top-left origin, 32-bit, uncompressed


if __name__ == "__main__":
    save(logo(), "Logo")
    save(pin(), "Pin")
    save(dot(), "Dot")
    save(glow(), "Glow")
    save(burst(), "Burst")
    print("wrote Logo.tga, Pin.tga, Dot.tga, Glow.tga, Burst.tga")
