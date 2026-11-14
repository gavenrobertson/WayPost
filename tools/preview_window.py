#!/usr/bin/env python3
"""Draws a layout preview of the guide window (docs/preview-guide-window.png).

This is a drawing made from the same sizes, colours and icon sheet the addon
uses, to check the design without the game. It is not a screenshot: in game
the text is in the game's own typeface. Needs Pillow."""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 2  # scale
C = dict(bg=(19, 16, 12), band=(34, 27, 18), well=(9, 7, 6), trim=(143, 112, 56), gold=(255, 209, 0), text=(245, 237, 219),
         dim=(189, 176, 150), muted=(133, 122, 102), npc=(143, 230, 143), enemy=(255, 133, 107), place=(255, 230, 158),
         good=(77, 242, 89), bad=(255, 84, 71), info=(128, 204, 255))
NAMES = ["accept", "turnin", "kill", "collect", "talk", "goto", "use", "fly", "home", "train", "level", "vendor", "note", "check",
         "skip", "left", "right", "down", "gear", "list", "close", "minus", "plus", "book", "undo", "warn", "dots", "lock", "nav",
         "interact", "box", "explore", "up", "bug", "users", "clock", "boxcheck", "search", "pinoff", "star"]
SHEET = Image.open(os.path.join(ROOT, "Waypost", "Media", "Icons.tga")).convert("RGBA")
LOGO = Image.open(os.path.join(ROOT, "Waypost", "Media", "Logo.tga")).convert("RGBA")


def font(size, bold=False):
    p = "/usr/share/fonts/truetype/crosextra/Caladea-%s.ttf" % ("Bold" if bold else "Regular")
    return ImageFont.truetype(p, int(size * S)) if os.path.exists(p) else ImageFont.load_default()


def icon(img, name, x, y, size, color):
    i = NAMES.index(name)
    cell = SHEET.crop(((i % 8) * 64, (i // 8) * 64, (i % 8) * 64 + 64, (i // 8) * 64 + 64)).resize((size * S, size * S), Image.LANCZOS)
    tint = ImageChops.multiply(cell, Image.new("RGBA", cell.size, color + (255,)))
    tint.putalpha(cell.split()[3])
    img.alpha_composite(tint, (int(x * S), int(y * S)))


def rich(d, x, y, parts, fnt):
    """parts: list of (text, colour). Returns the end x."""
    x *= S
    for text, col in parts:
        d.text((x + S, y * S + S), text, font=fnt, fill=(0, 0, 0))
        d.text((x, y * S), text, font=fnt, fill=col)
        x += d.textlength(text, font=fnt)
    return x / S


def main():
    Wd, H = 320, 372
    img = Image.new("RGBA", ((Wd + 80) * S, (H + 80) * S), (58, 78, 52, 255))
    d = ImageDraw.Draw(img)
    ox, oy = 40, 40

    def R(x0, y0, x1, y1, col):
        d.rectangle([(ox + x0) * S, (oy + y0) * S, (ox + x1) * S - 1, (oy + y1) * S - 1], fill=col)

    R(0, 0, Wd, H, C["trim"])
    R(1, 1, Wd - 1, H - 1, C["bg"])
    R(1, 1, Wd - 1, 25, C["band"])
    R(1, 25, Wd - 1, 27, (62, 50, 28))
    R(1, 25, 1 + int((Wd - 2) * 0.12), 27, C["gold"])
    img.alpha_composite(LOGO.resize((16 * S, 16 * S), Image.LANCZOS), ((ox + 8) * S, (oy + 5) * S))
    f, fs, fb, fn = font(12), font(10.5), font(15, True), font(14)
    rich(d, ox + 30, oy + 6, [("Elwynn Forest", C["gold"])], f)
    rich(d, ox + 208, oy + 7, [("4 / 93", C["dim"])], fs)
    icon(img, "dots", ox + 250, oy + 7, 12, C["dim"])
    icon(img, "minus", ox + 271, oy + 8, 10, C["dim"])
    icon(img, "close", ox + 291, oy + 8, 10, C["dim"])

    x, y = ox + 11, oy + 35
    rich(d, x, y, [("The kobold camp", C["gold"])], fb)
    y += 22
    for line in ("Kobold Vermin dig in the vineyards north-east of the", "Abbey. Now and then one drops a Nibbled-On Book."):
        rich(d, x, y, [(line, C["dim"])], fs)
        y += 14
    y += 6

    # Now card
    R(11, y - oy, Wd - 11, y - oy + 92, C["band"])
    R(11, y - oy, 13, y - oy + 92, C["gold"])
    icon(img, "kill", x + 10, y + 9, 18, C["enemy"])
    rich(d, x + 36, y + 7, [("Kill ", C["text"]), ("Kobold Vermin", C["enemy"]), ("  6/10", (255, 255, 255))], fn)
    icon(img, "box", x + 277, y + 9, 14, C["muted"])
    rich(d, x + 36, y + 28, [("Level 2 enemy", C["dim"])], fs)
    rich(d, x + 36, y + 42, [("For ", C["dim"]), ("Kobold Camp Cleanup", C["gold"])], fs)
    R(47, y - oy + 60, Wd - 23, y - oy + 64, (0, 0, 0))
    R(47, y - oy + 60, 47 + int((Wd - 70) * 0.6), y - oy + 64, C["gold"])
    icon(img, "nav", x + 14, y + 72, 11, C["place"])
    rich(d, x + 36, y + 70, [("64 yd north-east", C["text"]), ("  ·  Elwynn Forest 48.1, 37.0", C["place"])], fs)
    y += 100

    rows = [("collect", C["dim"], [("Collect ", C["text"]), ("Nibbled-On Book", (255, 255, 255)), (" (optional)", C["muted"])],
             [("Drops from ", C["dim"]), ("Kobold Vermin, Kobold Laborer", C["enemy"])]),
            ("accept", C["gold"], [("Accept ", C["text"]), ("Nibbled-On Book", C["gold"]), (" (optional)", C["muted"])], None)]
    for name, col, parts, sub in rows:
        icon(img, name, x + 1, y + 1, 14, col)
        rich(d, x + 22, y, parts, f)
        icon(img, "box", x + 281, y + 1, 14, C["muted"])
        y += 16
        if sub:
            rich(d, x + 22, y, sub, fs)
            y += 15
        y += 4
    icon(img, "check", x + 2, y + 2, 12, C["good"])
    rich(d, x + 22, y, [("2 done", C["dim"]), ("  show", C["muted"])], fs)
    y += 22

    R(11, y - oy, Wd - 11, y - oy + 1, (66, 53, 30))
    y += 7
    for k, (title, dist) in enumerate((("Northshire Abbey", "118 yd"), ("Echo Ridge Mine", "240 yd"), ("Northshire Abbey", "118 yd"))):
        if k == 0:
            rich(d, x, y, [("Next", C["muted"])], fs)
        rich(d, x + 36, y, [(title, C["dim"])], fs)
        rich(d, x + 262, y, [(dist, C["muted"])], fs)
        y += 16
    y += 4
    R(1, y - oy, Wd - 1, y - oy + 1, (66, 53, 30))
    icon(img, "left", x - 1, y + 7, 11, C["gold"])
    icon(img, "right", x + 16, y + 7, 11, C["gold"])
    rich(d, x + 40, y + 6, [("Skip", C["gold"]), ("     Why?", C["gold"]), ("     Steps", C["gold"])], fs)
    rich(d, x + 176, y + 6, [("3.6k XP/h  ", C["dim"]), ("52m 10s", (255, 255, 255))], fs)

    out = os.path.join(ROOT, "docs", "preview-guide-window.png")
    img.convert("RGB").save(out)
    print("wrote", os.path.relpath(out, ROOT), "content height", y - oy + 26)


if __name__ == "__main__":
    main()
