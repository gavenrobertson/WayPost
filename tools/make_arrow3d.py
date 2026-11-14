#!/usr/bin/env python3
"""Renders Waypost's 3D navigation arrow as a sprite sheet (Media/Arrow3D.tga).

A small software renderer: an extruded, ridged arrow lying on the ground plane,
seen from behind and above, lit from the upper left, with a contact shadow.
108 frames (9 columns x 12 rows of 112x84 px in a 1024x1024 sheet), one every
3.33 degrees. Frame i shows the arrow turned i * 360/108 degrees
counter-clockwise from "straight ahead". The render is greyscale so the addon
can tint it by distance. Needs Pillow and numpy.
"""
import math
import os

import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Waypost", "Media")
COLS, ROWS, CW, CH, SHEET = 9, 12, 112, 84, 1024
FRAMES = COLS * ROWS
SS = 4
FOCAL = 1.36

# Arrow outline, pointing +Y, as (x, y); z comes from edge/ridge heights.
# Chunky and thick, like a toy laid on the ground: wide head, short broad stem.
ZE, ZR = 0.26, 0.42          # edge height, ridge height
T = (0.0, 1.00)
R1, R2, R3 = (0.80, 0.02), (0.36, 0.10), (0.38, -0.80)
N = (0.0, -0.62)
C1 = (0.0, 0.14)
L1, L2, L3 = (-R1[0], R1[1]), (-R2[0], R2[1]), (-R3[0], R3[1])


def v(p, z):
    return (p[0], p[1], z)


def mesh():
    tris = []
    top = [
        (v(T, ZR * 0.55), v(R1, ZE), v(R2, ZE)), (v(T, ZR * 0.55), v(R2, ZE), v(C1, ZR)),
        (v(C1, ZR), v(R2, ZE), v(R3, ZE)), (v(C1, ZR), v(R3, ZE), v(N, ZR)),
        (v(T, ZR * 0.55), v(L2, ZE), v(L1, ZE)), (v(T, ZR * 0.55), v(C1, ZR), v(L2, ZE)),
        (v(C1, ZR), v(L3, ZE), v(L2, ZE)), (v(C1, ZR), v(N, ZR), v(L3, ZE)),
    ]
    tris += [(t, "top") for t in top]
    ring = [(T, ZR * 0.55), (R1, ZE), (R2, ZE), (R3, ZE), (N, ZR), (L3, ZE), (L2, ZE), (L1, ZE)]
    for i in range(len(ring)):
        (a, za), (b, zb) = ring[i], ring[(i + 1) % len(ring)]
        tris.append(((v(a, za), v(b, zb), v(b, 0.0)), "side"))
        tris.append(((v(a, za), v(b, 0.0), v(a, 0.0)), "side"))
    return tris


def render(theta):
    W, H = CW * SS, CH * SS
    pitch = math.radians(42)             # camera elevation above the ground
    dist = 4.6
    cam = np.array([0.0, -dist * math.cos(pitch), dist * math.sin(pitch)])
    fwd = -cam / np.linalg.norm(cam)
    right = np.array([1.0, 0.0, 0.0])
    up = np.cross(right, fwd)
    light = np.array([-0.55, -0.35, 0.80])
    light /= np.linalg.norm(light)
    c, s = math.cos(theta), math.sin(theta)
    rot = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
    focal = FOCAL * W

    def project(p):
        d = p - cam
        z = d @ fwd
        return np.array([W / 2 + focal * (d @ right) / z, H / 2 - focal * (d @ up) / z + H * 0.03, z])

    color = np.zeros((H, W), np.float32)
    alpha = np.zeros((H, W), np.float32)
    zbuf = np.full((H, W), 1e9, np.float32)
    shadow = np.zeros((H, W), np.float32)
    ys, xs = np.mgrid[0:H, 0:W]

    def fill(pts, shade, target=None):
        (x0, y0, z0), (x1, y1, z1), (x2, y2, z2) = pts
        minx, maxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(W - 1, math.ceil(max(x0, x1, x2))))
        miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(H - 1, math.ceil(max(y0, y1, y2))))
        if minx > maxx or miny > maxy:
            return
        X = xs[miny:maxy + 1, minx:maxx + 1] + 0.5
        Y = ys[miny:maxy + 1, minx:maxx + 1] + 0.5
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            return
        a = ((y1 - y2) * (X - x2) + (x2 - x1) * (Y - y2)) / den
        b = ((y2 - y0) * (X - x2) + (x0 - x2) * (Y - y2)) / den
        g = 1 - a - b
        inside = (a >= -1e-4) & (b >= -1e-4) & (g >= -1e-4)
        if target is not None:
            target[miny:maxy + 1, minx:maxx + 1][inside] = 1.0
            return
        z = a * z0 + b * z1 + g * z2
        zb = zbuf[miny:maxy + 1, minx:maxx + 1]
        win = inside & (z < zb)
        zb[win] = z[win]
        color[miny:maxy + 1, minx:maxx + 1][win] = shade
        alpha[miny:maxy + 1, minx:maxx + 1][win] = 1.0

    for tri, kind in mesh():
        world = [rot @ np.array(p) for p in tri]
        n = np.cross(world[1] - world[0], world[2] - world[0])
        ln = np.linalg.norm(n)
        if ln < 1e-9:
            continue
        n /= ln
        centre = (world[0] + world[1] + world[2]) / 3
        if n @ (cam - centre) < 0:
            n = -n
        diff = max(0.0, n @ light)
        view = (cam - centre) / np.linalg.norm(cam - centre)
        half = (light + view) / np.linalg.norm(light + view)
        spec = max(0.0, n @ half) ** 24
        if kind == "top":
            shade = 0.46 + 0.46 * diff + 0.45 * spec
        else:
            shade = 0.16 + 0.36 * diff
        fill([project(p) for p in world], min(1.0, shade))
        # contact shadow: the same triangle flattened onto the ground, pushed away from the light
        flat = [np.array([p[0] + 0.10, p[1] + 0.07, -0.02]) for p in world]
        fill([project(p) for p in flat], 0, shadow)

    def img(a):
        return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")

    a_img = img(alpha)
    # dark rim so the arrow reads on bright ground
    grown = a_img.filter(ImageFilter.MaxFilter(2 * SS + 1))
    rim = np.asarray(grown, np.float32) / 255 - alpha
    sh = np.asarray(img(shadow).filter(ImageFilter.GaussianBlur(SS * 2.4)), np.float32) / 255 * 0.55
    out_a = np.clip(np.maximum(np.maximum(alpha, rim * 0.95), sh * (1 - alpha)), 0, 1)
    out_c = np.where(alpha > 0, color, np.where(rim > 0, 0.07, 0.0))
    c_img = img(out_c).resize((CW, CH), Image.LANCZOS)
    al = img(out_a).resize((CW, CH), Image.LANCZOS)
    return Image.merge("RGBA", (c_img, c_img, c_img, al))


def main():
    sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
    for i in range(FRAMES):
        frame = render(i * 2 * math.pi / FRAMES)
        sheet.paste(frame, ((i % COLS) * CW, (i // COLS) * CH))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "Arrow3D.tga"), compression=None, orientation=1)  # top-left origin, 32-bit, uncompressed
    print("wrote Arrow3D.tga", sheet.size, FRAMES, "frames")


if __name__ == "__main__":
    main()
