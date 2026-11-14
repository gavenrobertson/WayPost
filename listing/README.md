# Store listing files (CurseForge, Wago)

| File | Use |
|---|---|
| `logo-400.png` | Project avatar (square, on its dark ground). CurseForge wants 400x400 or larger. |
| `logo-256.png` | The emblem cut out round, transparent corners, for Wago or Discord. |
| `banner-1600x400.png` | Header image for the top of the description. |
| `gallery-art.jpg` | The golden arrow on the road, for the gallery. |
| `source/` | The original pictures the files above are built from. |
| `arrow-headings.png` | The arrow at different headings, cut from the sprite sheet the addon ships. |
| `midjourney-prompts.md` | Prompts for generating better logo, banner and gallery art. |
| `summary.txt` | The short summary field. |
| `description.md` | The description, ready to paste. Its three images load from this repository on GitHub (pinned to a commit, so they keep working after the branch is merged). |
| `../CHANGELOG.md` | Paste the newest section into the file's changelog when uploading. |

The images are made by `tools/make_listing.py`.

## Listing fields

- Name: Waypost
- Game version: World of Warcraft, Forever
- Categories: Quests & Leveling, Map & Minimap, Guild
- License: GPLv3
- Source: https://github.com/gavenrobertson/waypost
- Issues: https://github.com/gavenrobertson/waypost/issues
- File: `dist/Waypost-<version>.zip` from `tools/package.sh`

## Screenshots

There are none in here because they have to come from the game. Once you have them,
`python3 tools/make_listing.py --frame shot1.png shot2.png` sets each inside the leather backdrop.
These would cover it:

1. The guide window on a new character, arrow pointing at the first quest giver.
2. The guide list.
3. The world map with a step's pins on it.
4. The party panel with two people on the same guide.
5. The guild board.
6. Settings, with something typed in the search box.
