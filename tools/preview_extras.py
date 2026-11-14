#!/usr/bin/env python3
"""Layout drawings of the level chart and the level-up banner (docs/preview-*.png).
Same sizes, colours and art as the addon; not screenshots. Needs Pillow."""
import os

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 2
C = dict(bg=(19, 16, 12), band=(34, 27, 18), well=(9, 7, 6), trim=(143, 112, 56), gold=(255, 209, 0), text=(245, 237, 219),
         dim=(189, 176, 150), muted=(133, 122, 102))
STEPS = [60, 120, 300, 600, 900, 1800, 3600, 7200, 14400, 28800, 43200, 86400]


def font(size, bold=False):
    p = "/usr/share/fonts/truetype/crosextra/Caladea-%s.ttf" % ("Bold" if bold else "Regular")
    return ImageFont.truetype(p, int(size * S))


def axis(sec):
    if sec >= 3600:
        h = sec / 3600
        return "%dh" % h if h == int(h) else "%.1fh" % h
    return "%dm" % round(sec / 60)


def chart(levels, live):
    W, H = 412, 200
    img = Image.new("RGB", (W * S, H * S), C["well"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * S - 1, H * S - 1], outline=(58, 46, 26))
    d.text((10 * S, 8 * S), "Time spent on each level", font=font(12), fill=C["gold"])
    done = [v for v in levels]
    d.text((10 * S, 25 * S), "%d levels, %dm on average" % (len(done), sum(done) / len(done) / 60), font=font(11), fill=C["muted"])
    L, R, T, B = 44, 10, 46, 20
    pw, ph = W - L - R, H - T - B
    data = [(i + 1, v, False) for i, v in enumerate(levels)] + [(len(levels) + 1, live, True)]
    mx = max(v for _, v, _ in data)
    step = next((s for s in STEPS if mx <= s * 3), STEPS[-1])
    top = step * 3
    for i in (1, 2, 3):
        y = T + ph - ph * (step * i) / top
        d.line([(L * S, y * S), ((L + pw) * S, y * S)], fill=(28, 25, 22))
        d.text(((L - 6) * S, y * S), axis(step * i), font=font(11), fill=C["muted"], anchor="rm")
    d.line([(L * S, (T + ph) * S), ((L + pw) * S, (T + ph) * S)], fill=(106, 98, 82))
    n = len(data)
    col = min(24, pw / n)
    bw = max(2, int(col - 2))
    every = next(k for k in (1, 2, 5, 10, 20) if col * k >= 24 or k == 20)
    for i, (lv, v, is_live) in enumerate(data):
        cx = L + i * col + col / 2
        bh = max(1, (ph - 1) * v / top)
        colr = (102, 84, 0) if is_live else (242, 199, 0)
        d.rectangle([(cx - bw / 2) * S, (T + ph - 1 - bh) * S, (cx + bw / 2) * S - 1, (T + ph - 1) * S], fill=colr)
        if lv % every == 0 or n < 3:
            d.text((cx * S, (T + ph + 4) * S), str(lv), font=font(11), fill=C["muted"], anchor="mt")
    return img


def ding():
    W, H = 320, 150
    img = Image.new("RGBA", (W * S, H * S), C["bg"] + (255,))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * S - 1, H * S - 1], outline=C["trim"])
    d.text((12 * S, 78 * S), "The kobold camp", font=font(15, True), fill=C["gold"])
    d.text((12 * S, 100 * S), "Kobold Vermin dig in the vineyards north-east of the", font=font(10.5), fill=C["dim"])
    banner = Image.new("RGBA", ((W - 2) * S, 66 * S), C["well"] + (255,))
    def add(name, size, pos, colour, alpha):
        t = Image.open(os.path.join(ROOT, "Waypost", "Media", name + ".tga")).convert("RGBA").resize((size[0] * S, size[1] * S), Image.LANCZOS)
        layer = Image.new("RGBA", banner.size, (0, 0, 0, 0))
        tint = ImageChops.multiply(t, Image.new("RGBA", t.size, colour + (255,)))
        tint.putalpha(t.split()[3].point(lambda v: int(v * alpha)))
        layer.paste(tint, (int(pos[0] * S - t.size[0] / 2), int(pos[1] * S - t.size[1] / 2)), tint)
        # additive blend
        r = ImageChops.add(banner.convert("RGB"), Image.composite(layer.convert("RGB"), Image.new("RGB", banner.size), layer.split()[3]))
        banner.paste(r)
    add("Burst", (260, 260), (159, 29), (255, 184, 51), 0.55)
    add("Glow", (300, 90), (159, 27), (255, 204, 77), 0.7)
    bd = ImageDraw.Draw(banner)
    bd.line([(0, 0), (banner.size[0], 0)], fill=C["gold"])
    bd.line([(0, banner.size[1] - 1), (banner.size[0], banner.size[1] - 1)], fill=C["gold"])
    bd.text((159 * S + 2, 24 * S + 4), "Level 12", font=font(24), fill=(0, 0, 0), anchor="mm")
    bd.text((159 * S, 24 * S), "Level 12", font=font(24), fill=C["gold"], anchor="mm")
    bd.text((159 * S, 47 * S), "Level 11 took 42m 10s", font=font(11), fill=C["text"], anchor="mm")
    img.paste(banner, (S, S))
    return img.convert("RGB")


if __name__ == "__main__":
    lv = [420, 540, 780, 900, 1260, 1500, 1320, 1980, 2400, 2100, 2940, 3300, 2700, 3900, 4500, 4200, 5400]
    chart(lv, 1500).save(os.path.join(ROOT, "docs", "preview-level-chart.png"))
    ding().save(os.path.join(ROOT, "docs", "preview-level-up.png"))
    print("wrote docs/preview-level-chart.png, docs/preview-level-up.png")


def tracker():
    """The live XP tracker, at its default width."""
    W, H = 250, 188
    img = Image.new("RGB", (W * S, H * S), C["bg"])
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W * S - 1, H * S - 1], outline=C["trim"])
    d.text((10 * S, 8 * S), "Level 14", font=font(17), fill=C["gold"])
    d.text((206 * S, 11 * S), "62.4%", font=font(12), fill=C["gold"], anchor="ra")
    d.text((226 * S, 10 * S), "|||", font=font(10), fill=C["dim"])
    d.text((240 * S, 9 * S), "x", font=font(10), fill=C["dim"])
    bx, by, bw, bh = 10, 32, 230, 12
    d.rectangle([bx * S, by * S, (bx + bw) * S, (by + bh) * S], fill=(0, 0, 0))
    d.rectangle([bx * S, by * S, (bx + bw * 0.624) * S, (by + bh) * S], fill=(158, 82, 235))
    d.rectangle([(bx + bw * 0.624) * S, by * S, (bx + bw * 0.78) * S, (by + bh) * S], fill=(48, 70, 120))
    d.rectangle([bx * S, by * S, (bx + bw) * S, (by + bh) * S], outline=C["trim"])
    d.text(((bx + bw * 0.6) * S, (by - 15) * S), "+420", font=font(12), fill=C["gold"], anchor="ma")
    d.text((10 * S, 49 * S), "12,345 / 19,800", font=font(11), fill=C["text"])
    d.text((240 * S, 49 * S), "7,455 to go", font=font(11), fill=C["muted"], anchor="ra")
    d.text((10 * S, 66 * S), "21.4k", font=font(26), fill=C["gold"])
    d.text((240 * S, 72 * S), "0:20:54", font=font(17), fill=C["text"], anchor="ra")
    d.text((10 * S, 96 * S), "XP per hour, last 10 minutes", font=font(11), fill=C["muted"])
    d.text((240 * S, 96 * S), "to level 15", font=font(11), fill=C["muted"], anchor="ra")
    vals = [800, 1200, 0, 600, 1500, 2100, 900, 1800, 2400, 700]
    top = max(vals)
    bw2 = (230 - 9 * 2) / 10
    for i, v in enumerate(vals):
        x0 = 10 + i * (bw2 + 2)
        h = max(1, 26 * v / top)
        col = (255, 209, 0) if v > 0 else (60, 50, 20)
        if i == 9:
            col = (128, 105, 0)
        d.rectangle([x0 * S, (138 - h) * S, (x0 + bw2) * S, 138 * S], fill=col)
    d.line([(10 * S, 139 * S), (240 * S, 139 * S)], fill=(106, 98, 82))
    d.text((10 * S, 147 * S), "Session +34.5k in 1h 12m", font=font(11), fill=C["text"])
    d.text((240 * S, 147 * S), "Quests 22.1k (9)", font=font(11), fill=C["text"], anchor="ra")
    d.text((10 * S, 163 * S), "About 38 kills or 4 quests", font=font(11), fill=C["muted"])
    d.text((240 * S, 163 * S), "Kills 12.4k (63)", font=font(11), fill=C["text"], anchor="ra")
    return img


if __name__ == "__main__":
    tracker().save(os.path.join(ROOT, "docs", "preview-xp-tracker.png"))
    print("wrote docs/preview-xp-tracker.png")
