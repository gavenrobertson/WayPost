# Midjourney prompts for the listing art

Midjourney is unreliable at lettering, so every prompt asks for no text. Add the "Waypost" name
afterwards (or drop the result into `listing/source/` and `tools/make_listing.py` can put the name
on it). Generate a few variations of each and pick one.

## Logo / avatar (square)

```
game addon emblem, a weathered wooden signpost with two pointing boards inside a round bronze-gold medallion, hand-painted fantasy MMO icon style, thick painterly brushwork, warm rim light, dark brown leather background inside the ring, centered, bold readable silhouette, no text, no letters --ar 1:1 --style raw --stylize 250
```

Simpler variant that stays readable at 32 px:

```
flat heraldic emblem of a wooden signpost with two arrow boards, gold on dark brown, thick bronze circular border, hand-painted fantasy game icon, strong silhouette, minimal detail, centered, no text --ar 1:1 --style raw --stylize 100
```

## Banner (wide header)

```
wide fantasy landscape banner, a lone wooden signpost at a fork in a dirt road at golden hour, rolling green hills and a distant stone abbey, hand-painted stylized MMO concept art, soft painterly brushstrokes, warm light from the left, large area of calm darker sky on the left third for a title, no text, no characters --ar 4:1 --style raw --stylize 300
```

Darker variant that sits well behind gold lettering:

```
wide fantasy banner, wooden signpost silhouette at dusk on a forest road, lanterns glowing warm gold, deep brown and teal shadows, hand-painted stylized game art, empty dark space on the left half for a logo, no text, no characters --ar 4:1 --style raw --stylize 300
```

## Arrow hero image

```
a chunky golden 3D arrow lying on a cobblestone road pointing forward down the path, low camera angle, stylized hand-painted fantasy game art, soft glow around the arrow, forest road receding into warm morning light, no text, no characters --ar 16:9 --style raw --stylize 250
```

## Gallery backdrop (to sit behind real screenshots)

```
dark worn leather texture with a thin embossed bronze border and subtle corner filigree, top-down, even lighting, hand-painted fantasy game UI panel background, no text --ar 16:9 --style raw --stylize 100
```

## Notes

- Keep `no text` in every prompt. If letters still appear, add `--no text, letters, words, watermark`.
- The prompts describe the style rather than naming a game, which keeps the art clear of anyone's trademarks.
- Sizes to export: avatar 400x400 or larger, banner 1600x400, gallery 1920x1080.
- The in-game logo is `Waypost/Media/Logo.tga` (64x64). If you pick a new emblem, a 256x256 PNG of it
  can be converted for the addon so the minimap button and window match the listing.
