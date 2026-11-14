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

## Interface icons

The addon's icons are single-colour shapes that it tints itself (gold for quests, red for enemies),
and most are shown at 12 to 18 pixels. So they need bold, simple silhouettes: light shape, black
background, no shading. Generate them one at a time and they come out much more consistent than a
sheet.

Template (swap in the subject):

```
single fantasy RPG interface glyph of SUBJECT, solid white silhouette on a pure black background, bold simple shape, thick strokes, slightly chiseled hand-cut edges, flat, no shading, no gradient, no outline, centered with wide margins, no text --ar 1:1 --style raw --stylize 50
```

Once one comes out the way you like, add `--sref <its image URL>` to every other prompt so the rest
match it.

Subjects, with the file name each one should be saved as in `art/icons/`:

| File | SUBJECT |
|---|---|
| `accept.png` | a bold exclamation mark |
| `turnin.png` | a bold question mark |
| `kill.png` | a short sword pointing up and to the right |
| `collect.png` | a drawstring loot pouch |
| `talk.png` | a speech bubble |
| `goto.png` | a map pin marker |
| `use.png` | a gauntlet hand with one finger raised |
| `fly.png` | a single spread bird wing |
| `home.png` | a small cottage with a pitched roof |
| `train.png` | an open spellbook |
| `level.png` | two upward chevrons stacked |
| `vendor.png` | a stack of three coins |
| `note.png` | a lowercase letter i inside a ring |
| `check.png` | a check mark |
| `skip.png` | two right-pointing triangles and a vertical bar |
| `left.png` | a chevron pointing left |
| `right.png` | a chevron pointing right |
| `down.png` | a chevron pointing down |
| `up.png` | a chevron pointing up |
| `gear.png` | a cogwheel |
| `list.png` | three horizontal lines with a dot before each |
| `close.png` | a diagonal cross |
| `minus.png` | a horizontal bar |
| `plus.png` | a plus sign |
| `book.png` | a closed book seen from the front |
| `undo.png` | an arrow curving back to the left |
| `warn.png` | a triangle with an exclamation mark cut out of it |
| `dots.png` | three dots in a horizontal row |
| `lock.png` | a padlock |
| `nav.png` | a navigation arrowhead pointing up |
| `interact.png` | a crosshair ring |
| `box.png` | an empty rounded square outline |
| `boxcheck.png` | a filled rounded square with a check mark cut out of it |
| `explore.png` | a pennant flag on a pole |
| `bug.png` | a beetle seen from above |
| `users.png` | two hooded figures, head and shoulders |
| `clock.png` | a clock face |
| `search.png` | a magnifying glass |
| `pinoff.png` | a map pin with a diagonal line through it |
| `star.png` | a five-pointed star |

To explore a style first, a sheet works as a mood board (do not rely on its order):

```
sheet of fantasy RPG interface glyphs in a neat grid, sword, pouch, speech bubble, map pin, cogwheel, book, wing, cottage, coin stack, padlock, flag, star, solid white silhouettes on a pure black background, bold simple shapes, slightly chiseled hand-cut edges, flat, no shading, no text --ar 8:5 --style raw --stylize 50
```

Using them: save each picture under the file name above in `art/icons/`, then

```bash
python3 tools/make_icons.py
```

rebuilds the addon's icon sheet. Any icon without a file keeps the built-in drawing, so you can
replace a few at a time. Painted, multi-colour icons will not work here: they are reduced to their
outline shape.

## Notes

- Keep `no text` in every prompt. If letters still appear, add `--no text, letters, words, watermark`.
- The prompts describe the style rather than naming a game, which keeps the art clear of anyone's trademarks.
- Sizes to export: avatar 400x400 or larger, banner 1600x400, gallery 1920x1080.
- The pictures in `listing/source/` are the ones in use: `emblem.webp` (also the in-game logo, via
  `tools/make_art.py`), `banner.webp`, `arrow-road.webp` and `backdrop.webp`. Replace a file and run
  `python3 tools/make_art.py` and `python3 tools/make_listing.py` to rebuild.
- `python3 tools/make_listing.py --frame shot1.png shot2.png` sets game screenshots inside the backdrop
  and writes `listing/gallery-1.png`, `gallery-2.png`, ...
