# Waypost

A leveling guide addon for World of Warcraft: Forever. Routes from 1 to 60 for every race, an arrow
to follow, and party and guild features. Free, GPL-3.0, no account linking.

## Install

1. Download the latest zip from the Releases page (or run `tools/package.sh`).
2. Unzip it into `World of Warcraft/_forever_/Interface/AddOns/`. You should end up with four folders:
   `Waypost`, `Waypost_Routes_Alliance`, `Waypost_Routes_Horde`, `Waypost_Routes_Extras`.
3. Start the game. The Waypost window suggests the right guide for your character: press **Start**.

From a clone of this repository, copy (or symlink) those same four folders into `Interface/AddOns/`.

## Using it

| | |
|---|---|
| `/waypost` | show or hide the guide window |
| `/waypost guides` | choose a guide |
| `/waypost config` | settings (searchable) |
| `/waypost skip`, `undo`, `next`, `back` | move through the guide; `undo` brings a skipped step back |
| `/waypost later` | quests you set aside to come back to |
| `/waypost help` | the welcome and help window |
| `/waypost party`, `/waypost guild` | party progress and the guild leveling board |
| `/waypost nearest trainer` | point the arrow at the nearest class trainer (also `vendor`, `flight`, `inn`) |
| `/waypost record start` / `stop` | record your own route as a draft guide |
| `/waypost report` | a copyable report when a step or coordinate is wrong |
| `/waypost commands` | the full command list in chat |

Key bindings (step, skip, quest item button, target button) are under **Options > Keybindings > Waypost**.
Hold **Shift** while opening an NPC to switch automation off for that conversation.

## What it does

- Guide window with a "Now" card: what to do, who or what it involves, and where it is, with live
  distance and direction. Under it the step's other goals, what is done, and what comes next. It
  uses the game's typeface and colours (quest gold, item quality, hostile red) on its own panels.
  `docs/preview-guide-window.png` is a drawing of the layout.
- 3D arrow with distance and time to arrive, pins on the world map and minimap, optional TomTom
  hand-off.
- Accepts and turns in the guide's quests (it stops at reward choices). Buttons for the step's quest
  item and target. Tracks flight points.
- Skip, undo, look ahead, "why this step", warnings on elite and group quests, a safer route for
  Hardcore.
- Later: set a step's quests aside and get them offered back when you join a party or gain two
  levels. Group quests are set aside automatically while you are solo. At a level checkpoint the
  window shows how much XP you are short and points you at set-aside quests or enemies your level.
- A welcome window on first login and a help window (`/waypost help`).
- XP per hour, level and guide timers, a history of finished guides.
- Talent suggestions, gear upgrade hints (uses Pawn when installed), a list of quests the route will
  not finish.
- Party panel: everyone's step, sync the party to your guide, share a missing quest.
- Guild board, a guild route set by officers, officer notices.
- Your own guides: a text format (`docs/GUIDE_FORMAT.md`), an in-game editor with line-numbered
  errors, import/export strings, a browser editor (`tools/editor.html`), and a recorder.
- Progress export for dragonwarriors.app (`tools/upload_progress.py`).

Waypost is event driven. Objectives tick off as they happen; a setting makes it wait until combat
ends instead. Only the guide you are on is held in memory. In the test harness that comes to about 2.5 MB
with one faction's routes loaded; it has not been measured in the game client yet.

## Not in this release

- Mailbox automation.
- Auction-house scanning for upgrades.
- Uploading to dragonwarriors.app needs the site's endpoint; the uploader's `--dry-run` shows the data.

## Developing

```bash
lua5.1 tests/run.lua
```

```bash
luacheck Waypost tests/run.lua
```

```bash
python3 tools/check_toc.py
```

The tests load every addon file against a mock of the game API (`tests/wowmock.lua`), walk a guide,
and check all 259 shipped guides. They cannot replace playing: see `docs/TESTING.md` for the in-game
checklist.

Routes are regenerated from a Polestar checkout:

```bash
python3 -I tools/import_polestar.py /path/to/polestar
```

## License and credits

GPL-3.0-only. The routes come from [Polestar Guides](https://github.com/fitzforge/polestar)
(GPL-3.0); see `CREDITS.md`. Nothing is taken from RestedXP's guides.
