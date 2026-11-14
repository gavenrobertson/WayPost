#!/usr/bin/env python3
"""Draws Waypost's interface glyphs into one sheet (Media/Icons.tga).

8 columns of 64 px cells in a 512x512 texture (room for 8 rows). The glyphs are white
on transparent so the addon tints them. The order here is the order in
UI/Skin.lua's ICON table. Needs Pillow.

Replacing a glyph with your own art: put an image named after the glyph in
art/icons/ (for example art/icons/kill.png; png, webp or jpg) and run this
script again. The image should be a light shape on a black background, or a
shape on a transparent background; it is turned into a white silhouette,
trimmed and centred in its cell. Glyphs without a file are drawn by the code
below. To cut up one sheet instead:

  python3 tools/make_icons.py --sheet art/icons-sheet.png --grid 8x5

slices the sheet left to right, top to bottom into art/icons/ using the
names in NAMES (check the order before relying on it).
"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Waypost", "Media")
CELL, COLS, ROWS, SS = 64, 8, 5, 6
N = CELL * SS
W = (255, 255, 255, 255)

NAMES = [
    "accept", "turnin", "kill", "collect", "talk", "goto", "use", "fly",
    "home", "train", "level", "vendor", "note", "check", "skip", "left",
    "right", "down", "gear", "list", "close", "minus", "plus", "book",
    "undo", "warn", "dots", "lock", "nav", "interact", "box", "explore",
    "up", "bug", "users", "clock", "boxcheck", "search", "pinoff", "star",
    "grip", "chart", "layout", "bolt",
]


def u(v):
    return v * N / 64.0


def line(d, pts, w=6):
    pts = [(u(x), u(y)) for x, y in pts]
    d.line(pts, fill=W, width=int(u(w)), joint="curve")
    r = u(w) / 2
    for x, y in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=W)


def poly(d, pts):
    d.polygon([(u(x), u(y)) for x, y in pts], fill=W)


def circle(d, cx, cy, r, fill=W):
    d.ellipse([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], fill=fill)


def ring(d, cx, cy, r, w=6):
    d.ellipse([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], outline=W, width=int(u(w)))


def rect(d, x0, y0, x1, y1, r=0, fill=W, outline=None, w=6):
    box = [u(x0), u(y0), u(x1), u(y1)]
    if outline:
        d.rounded_rectangle(box, radius=u(r), outline=W, width=int(u(w)))
    else:
        d.rounded_rectangle(box, radius=u(r), fill=fill)


CLEAR = (0, 0, 0, 0)


def g_accept(d):
    rect(d, 27, 10, 37, 40, 5)
    circle(d, 32, 50, 5.5)


def g_turnin(d):
    d.arc([u(18), u(10), u(46), u(38)], 180, 90, fill=W, width=int(u(8)))
    line(d, [(32, 38), (32, 41)], 8)
    circle(d, 32, 52, 5)


def g_kill(d):
    line(d, [(46, 12), (22, 40)], 7)          # blade
    poly(d, [(50, 8), (52, 18), (42, 10)])    # tip
    line(d, [(14, 34), (30, 48)], 6)          # guard
    line(d, [(19, 44), (12, 52)], 7)          # grip


def g_collect(d):
    rect(d, 14, 24, 50, 54, 9)
    d.arc([u(22), u(10), u(42), u(34)], 180, 360, fill=W, width=int(u(6)))
    rect(d, 27, 32, 37, 40, 2, fill=CLEAR)


def g_talk(d):
    rect(d, 10, 12, 54, 42, 10)
    poly(d, [(20, 40), (20, 54), (34, 40)])


def g_goto(d):
    circle(d, 32, 25, 15)
    poly(d, [(19.5, 33), (44.5, 33), (32, 56)])
    circle(d, 32, 25, 6, CLEAR)


def g_gear(d):
    for k in range(8):
        a = k * math.pi / 4
        cx, cy = 32 + 19 * math.cos(a), 32 + 19 * math.sin(a)
        circle(d, cx, cy, 5.5)
    circle(d, 32, 32, 17)
    circle(d, 32, 32, 7.5, CLEAR)


def g_use(d):
    # a hand cursor: palm and a raised finger
    rect(d, 20, 28, 46, 54, 8)
    rect(d, 26, 8, 35, 36, 4.5)
    rect(d, 36, 22, 44, 34, 4)


def g_fly(d):
    poly(d, [(8, 30), (56, 10), (38, 54), (30, 36)])
    poly(d, [(30, 36), (56, 10), (33, 42)])


def g_home(d):
    poly(d, [(32, 8), (56, 30), (8, 30)])
    rect(d, 15, 28, 49, 54, 3)
    rect(d, 27, 38, 37, 54, 1, fill=CLEAR)


def g_train(d):
    poly(d, [(6, 14), (30, 18), (30, 52), (6, 46)])
    poly(d, [(58, 14), (34, 18), (34, 52), (58, 46)])


def g_level(d):
    line(d, [(16, 30), (32, 14), (48, 30)], 7)
    line(d, [(16, 48), (32, 32), (48, 48)], 7)


def g_vendor(d):
    circle(d, 26, 38, 16)
    circle(d, 26, 38, 9, CLEAR)
    d.arc([u(24), u(8), u(56), u(40)], 250, 90, fill=W, width=int(u(6)))


def g_note(d):
    ring(d, 32, 32, 22, 6)
    circle(d, 32, 21, 4)
    rect(d, 28.5, 28, 35.5, 46, 3)


def g_check(d):
    line(d, [(12, 34), (26, 48), (52, 18)], 8)


def g_skip(d):
    poly(d, [(10, 14), (30, 32), (10, 50)])
    poly(d, [(28, 14), (48, 32), (28, 50)])
    rect(d, 49, 14, 56, 50, 2)


def g_left(d):
    line(d, [(40, 12), (20, 32), (40, 52)], 8)


def g_right(d):
    line(d, [(24, 12), (44, 32), (24, 52)], 8)


def g_down(d):
    line(d, [(12, 22), (32, 42), (52, 22)], 8)


def g_up(d):
    line(d, [(12, 42), (32, 22), (52, 42)], 8)


def g_list(d):
    for y in (16, 32, 48):
        circle(d, 11, y, 4)
        line(d, [(22, y), (54, y)], 6)


def g_close(d):
    line(d, [(15, 15), (49, 49)], 8)
    line(d, [(49, 15), (15, 49)], 8)


def g_minus(d):
    line(d, [(12, 32), (52, 32)], 8)


def g_plus(d):
    line(d, [(12, 32), (52, 32)], 8)
    line(d, [(32, 12), (32, 52)], 8)


def g_book(d):
    rect(d, 12, 8, 52, 56, 5)
    rect(d, 20, 16, 44, 24, 2, fill=CLEAR)
    rect(d, 12, 44, 52, 48, 0, fill=CLEAR)


def g_undo(d):
    d.arc([u(14), u(16), u(54), u(56)], 200, 90, fill=W, width=int(u(7)))
    poly(d, [(6, 22), (26, 16), (20, 38)])


def g_warn(d):
    poly(d, [(32, 6), (60, 54), (4, 54)])
    rect(d, 28.5, 22, 35.5, 40, 3, fill=CLEAR)
    circle(d, 32, 47, 3.6, CLEAR)


def g_dots(d):
    for x in (14, 32, 50):
        circle(d, x, 32, 5.5)


def g_lock(d):
    rect(d, 12, 28, 52, 56, 6)
    d.arc([u(19), u(8), u(45), u(40)], 180, 360, fill=W, width=int(u(7)))
    circle(d, 32, 42, 4.5, CLEAR)


def g_nav(d):
    poly(d, [(32, 6), (54, 56), (32, 44), (10, 56)])


def g_interact(d):
    ring(d, 32, 32, 18, 6)
    for a, b in (((32, 4), (32, 16)), ((32, 48), (32, 60)), ((4, 32), (16, 32)), ((48, 32), (60, 32))):
        line(d, [a, b], 6)
    circle(d, 32, 32, 5)


def g_box(d):
    rect(d, 9, 9, 55, 55, 9, outline=True, w=6)


def g_boxcheck(d):
    rect(d, 9, 9, 55, 55, 9)
    pts = [(u(19), u(33)), (u(28), u(42)), (u(45), u(22))]
    d.line(pts, fill=CLEAR, width=int(u(7)), joint="curve")


def g_explore(d):
    line(d, [(16, 8), (16, 58)], 6)
    poly(d, [(18, 10), (54, 18), (18, 34)])


def g_bug(d):
    d.ellipse([u(18), u(20), u(46), u(56)], fill=W)
    circle(d, 32, 16, 8)
    for y in (28, 38, 48):
        line(d, [(8, y), (18, y + 2)], 5)
        line(d, [(56, y), (46, y + 2)], 5)


def g_users(d):
    circle(d, 22, 20, 10)
    d.pieslice([u(4), u(34), u(40), u(76)], 180, 360, fill=W)
    circle(d, 44, 24, 8)
    d.pieslice([u(32), u(36), u(60), u(72)], 180, 360, fill=W)


def g_clock(d):
    ring(d, 32, 32, 22, 6)
    line(d, [(32, 18), (32, 32), (42, 38)], 6)


def g_search(d):
    ring(d, 27, 27, 16, 7)
    line(d, [(39, 39), (54, 54)], 8)


def g_pinoff(d):
    g_goto(d)
    d.line([(u(10), u(10)), (u(54), u(54))], fill=CLEAR, width=int(u(12)))
    line(d, [(12, 12), (52, 52)], 6)


def g_star(d):
    pts = []
    for k in range(10):
        r = 25 if k % 2 == 0 else 10.5
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((32 + r * math.cos(a), 34 + r * math.sin(a)))
    poly(d, pts)


def g_grip(d):
    # three diagonal ridges in the bottom-right corner, as on a resizable window
    for k in (0, 1, 2):
        o = 20 + k * 13
        line(d, [(o, 56), (56, o)], 6)


def g_chart(d):
    rect(d, 10, 34, 20, 54, 2)
    rect(d, 27, 20, 37, 54, 2)
    rect(d, 44, 8, 54, 54, 2)


def g_layout(d):
    rect(d, 8, 8, 56, 20, 3)
    rect(d, 8, 26, 56, 38, 3)
    rect(d, 8, 44, 34, 56, 3)


def g_bolt(d):
    poly(d, [(36, 4), (14, 36), (30, 36), (24, 60), (50, 24), (34, 24), (42, 4)])


DRAW = {
    "accept": g_accept, "turnin": g_turnin, "kill": g_kill, "collect": g_collect, "talk": g_talk, "goto": g_goto,
    "use": g_use, "fly": g_fly, "home": g_home, "train": g_train, "level": g_level, "vendor": g_vendor,
    "note": g_note, "check": g_check, "skip": g_skip, "left": g_left, "right": g_right, "down": g_down,
    "gear": g_gear, "list": g_list, "close": g_close, "minus": g_minus, "plus": g_plus, "book": g_book,
    "undo": g_undo, "warn": g_warn, "dots": g_dots, "lock": g_lock, "nav": g_nav, "interact": g_interact,
    "box": g_box, "explore": g_explore, "up": g_up, "bug": g_bug, "users": g_users, "clock": g_clock,
    "boxcheck": g_boxcheck, "search": g_search, "pinoff": g_pinoff, "star": g_star,
    "grip": g_grip, "chart": g_chart, "layout": g_layout, "bolt": g_bolt,
}


ART = os.path.join(os.path.dirname(OUT), "..", "art", "icons")


def silhouette(path):
    """Any picture of a glyph -> white shape with alpha, trimmed to its content, as a square."""
    im = Image.open(path).convert("RGBA")
    r, g, b, a = im.split()
    if a.getextrema()[0] < 250:
        alpha = a                                   # already cut out: keep its shape
    else:
        lum = im.convert("L")                       # light on dark: brightness is the shape
        lo, hi = lum.getextrema()
        if hi - lo < 30:
            raise ValueError("%s has no visible shape" % path)
        alpha = lum.point(lambda v: max(0, min(255, int((v - lo - 20) * 255.0 / max(1, hi - lo - 40)))))
    box = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    if not box:
        raise ValueError("%s is empty" % path)
    alpha = alpha.crop(box)
    side = max(alpha.size)
    square = Image.new("L", (side, side), 0)
    square.paste(alpha, ((side - alpha.size[0]) // 2, (side - alpha.size[1]) // 2))
    out = Image.new("RGBA", (side, side), (255, 255, 255, 0))
    out.putalpha(square)
    return out


def custom(name):
    for ext in ("png", "webp", "jpg", "jpeg"):
        path = os.path.join(ART, name + "." + ext)
        if os.path.exists(path):
            return silhouette(path)
    return None


def slice_sheet(path, grid):
    cols, rows = (int(v) for v in grid.lower().split("x"))
    im = Image.open(path).convert("RGBA")
    cw, ch = im.size[0] / cols, im.size[1] / rows
    os.makedirs(ART, exist_ok=True)
    for i, name in enumerate(NAMES[:cols * rows]):
        c, r = i % cols, i // cols
        im.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch))).save(os.path.join(ART, name + ".png"))
    print("sliced %d cells into art/icons/ (check each file shows the glyph its name says)" % min(len(NAMES), cols * rows))


def main():
    import sys
    if "--sheet" in sys.argv:
        grid = sys.argv[sys.argv.index("--grid") + 1] if "--grid" in sys.argv else "8x5"
        slice_sheet(sys.argv[sys.argv.index("--sheet") + 1], grid)
    sheet = Image.new("RGBA", (512, 512), (255, 255, 255, 0))
    used = []
    for i, name in enumerate(NAMES):
        art = custom(name)
        if art:
            used.append(name)
            cell = art
        else:
            cell = Image.new("RGBA", (N, N), (255, 255, 255, 0))
            DRAW[name](ImageDraw.Draw(cell))
        # shrink a little inside the cell so neighbours never bleed when scaled
        small = cell.resize((CELL - 8, CELL - 8), Image.LANCZOS)
        sheet.paste(small, ((i % COLS) * CELL + 4, (i // COLS) * CELL + 4))
    if used:
        print("used your art for: " + ", ".join(used))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "Icons.tga"), compression=None, orientation=1)
    print("wrote Icons.tga with %d glyphs" % len(NAMES))
    return sheet


if __name__ == "__main__":
    main()
