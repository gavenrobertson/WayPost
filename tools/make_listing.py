#!/usr/bin/env python3
"""Draws the store listing images in listing/ (CurseForge, Wago): logo, banner, arrow strip.
Everything comes from Waypost's own art (the logo and the 3D arrow sheet). Needs Pillow."""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

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


SRC = os.path.join(OUT, "source")


def logo(size):
    return make_art.logo(size)


def avatar(size=400):
    """Square avatar: the emblem on its own dark ground, as painted."""
    src = os.path.join(SRC, "emblem.webp")
    if not os.path.exists(src):
        return logo(size)
    cx, cy, r = make_art.EMBLEM_CIRCLE
    m = 60
    im = Image.open(src).convert("RGB")
    box = (max(0, cx - r - m), max(0, cy - r - m), min(im.size[0], cx + r + m), min(im.size[1], cy + r + m))
    return im.crop(box).resize((size, size), Image.LANCZOS)


def banner(w=1600, h=400):
    """The painted landscape with the name set in the dark foreground at the lower left."""
    src = os.path.join(SRC, "banner.webp")
    if not os.path.exists(src):
        img = background(w, h)
        d = ImageDraw.Draw(img)
        img.alpha_composite(logo(200), (90, (h - 200) // 2))
        d.text((340, 108), "Waypost", font=font(118), fill=GOLD)
        d.text((346, 246), "Leveling guides for WoW Forever", font=font(38, False), fill=CREAM)
        return img
    img = Image.open(src).convert("RGBA").resize((w, h), Image.LANCZOS)
    shade = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shade).ellipse([-260, 150, 760, 620], fill=175)
    shade = shade.filter(ImageFilter.GaussianBlur(70))
    img = Image.composite(Image.new("RGBA", (w, h), (12, 9, 6, 255)), img, shade)
    tx, ty = 46, 232
    f1, f2 = font(104), font(30, False)
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    ds.text((tx + 3, ty + 5), "Waypost", font=f1, fill=(0, 0, 0, 220))
    ds.text((tx + 5, ty + 112), "Leveling guides for WoW Forever", font=f2, fill=(0, 0, 0, 220))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
    d = ImageDraw.Draw(img)
    d.text((tx, ty), "Waypost", font=f1, fill=GOLD, stroke_width=2, stroke_fill=(60, 38, 6))
    d.text((tx + 4, ty + 110), "Leveling guides for WoW Forever", font=f2, fill=CREAM)
    return img


def arrow_strip(w=1200, h=220):
    """The arrow at a spread of headings, straight from the sprite sheet the addon ships."""
    img = background(w, h)
    picks = [81, 90, 99, 0, 9, 18, 27, 40, 54]
    for k, idx in enumerate(picks):
        fr = arrow_frame(idx, 1.15)
        img.alpha_composite(fr, (int(20 + k * (w - 40) / len(picks)), (h - fr.size[1]) // 2))
    return img


def frame_screenshot(path, out_path, w=1920, h=1080):
    """Sets a game screenshot inside the leather-and-bronze backdrop for the gallery."""
    back = Image.open(os.path.join(SRC, "backdrop.webp")).convert("RGB").resize((w, h), Image.LANCZOS)
    shot = Image.open(path).convert("RGB")
    box_w, box_h = int(w * 0.90), int(h * 0.86)
    scale = min(box_w / shot.size[0], box_h / shot.size[1])
    shot = shot.resize((int(shot.size[0] * scale), int(shot.size[1] * scale)), Image.LANCZOS)
    back.paste(shot, ((w - shot.size[0]) // 2, (h - shot.size[1]) // 2))
    back.save(out_path)
    return out_path


def main():
    os.makedirs(OUT, exist_ok=True)
    if len(sys.argv) >= 3 and sys.argv[1] == "--frame":
        # tools/make_listing.py --frame screenshot.png [more.png ...]
        for i, shot in enumerate(sys.argv[2:], 1):
            print("wrote", frame_screenshot(shot, os.path.join(OUT, "gallery-%d.png" % i)))
        return
    avatar(400).convert("RGB").save(os.path.join(OUT, "logo-400.png"))
    logo(256).save(os.path.join(OUT, "logo-256.png"))
    banner().convert("RGB").save(os.path.join(OUT, "banner-1600x400.png"))
    arrow_strip().convert("RGB").save(os.path.join(OUT, "arrow-headings.png"))
    road = os.path.join(SRC, "arrow-road.webp")
    if os.path.exists(road):
        Image.open(road).convert("RGB").resize((1920, 1076), Image.LANCZOS).save(os.path.join(OUT, "gallery-art.jpg"), quality=90)
    print("wrote listing images")


if __name__ == "__main__":
    main()
