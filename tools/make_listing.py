#!/usr/bin/env python3
"""Draws the store listing images in listing/ (CurseForge, Wago): logo, banner, arrow strip.
Everything comes from Waypost's own art (the logo and the 3D arrow sheet). Needs Pillow."""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "listing")
sys.path.insert(0, HERE)
import make_art  # noqa: E402

GOLD, CREAM = (255, 209, 0), (236, 228, 208)


def font(size, bold=True):
    for path in (
        "/usr/share/fonts/truetype/crosextra/Caladea-Bold.ttf" if bold else "/usr/share/fonts/truetype/crosextra/Caladea-Regular.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
    ):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def background(w, h):
    """Flat dark brown with a little grain. No glow, no frame."""
    img = Image.new("RGB", (w, h), (27, 22, 16))
    noise = Image.effect_noise((w, h), 10).convert("RGB")
    return ImageChops.blend(img, ImageChops.multiply(img, noise), 0.5).convert("RGBA")


def arrow_frame(index, size, colour=(255, 214, 64)):
    sheet = Image.open(os.path.join(ROOT, "Waypost", "Media", "Arrow3D.tga")).convert("RGBA")
    cw, ch = 112, 84
    f = sheet.crop(((index % 9) * cw, (index // 9) * ch, (index % 9) * cw + cw, (index // 9) * ch + ch))
    a = f.split()[3]
    f = ImageChops.multiply(f, Image.new("RGBA", f.size, colour + (255,)))
    f.putalpha(a)
    return f.resize((int(cw * size), int(ch * size)), Image.LANCZOS)


def logo(size):
    return make_art.logo(size)


def banner(w=1600, h=400):
    """Logo, name, one line. The arrow on the right is the in-game arrow, tinted as it is in game."""
    img = background(w, h)
    d = ImageDraw.Draw(img)
    img.alpha_composite(logo(200), (90, (h - 200) // 2))
    d.text((340, 108), "Waypost", font=font(118), fill=GOLD)
    d.text((346, 246), "Leveling guides for WoW Forever", font=font(38, False), fill=CREAM)
    fr = arrow_frame(100, 3.0)
    img.alpha_composite(fr, (w - fr.size[0] - 110, (h - fr.size[1]) // 2 - 6))
    return img


def arrow_strip(w=1200, h=220):
    """The arrow at a spread of headings, straight from the sprite sheet the addon ships."""
    img = background(w, h)
    picks = [81, 90, 99, 0, 9, 18, 27, 40, 54]
    for k, idx in enumerate(picks):
        fr = arrow_frame(idx, 1.15)
        img.alpha_composite(fr, (int(20 + k * (w - 40) / len(picks)), (h - fr.size[1]) // 2))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    logo(400).save(os.path.join(OUT, "logo-400.png"))
    logo(256).save(os.path.join(OUT, "logo-256.png"))
    banner().convert("RGB").save(os.path.join(OUT, "banner-1600x400.png"))
    arrow_strip().convert("RGB").save(os.path.join(OUT, "arrow-headings.png"))
    print("wrote listing images")


if __name__ == "__main__":
    main()
