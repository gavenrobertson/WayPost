# Waypost guide format

A guide is plain text. The in-game editor (`/waypost editor`), the browser editor
(`tools/editor.html`) and the recorder all read and write this format. Lines starting with `#` are
comments.

```
title Goldshire loop
faction Alliance
races Human
levels 5-10
map 1429

step Marshal Dughan
  tip He stands outside the inn.
  accept 62 The Fargodeep Mine @42.1,65.9
  accept 76 The Jasperlode Mine @42.1,65.9

step The Fargodeep Mine
  danger The lower tunnel is full of level 8 kobolds.
  kill 10 Kobold Miner quest 62 obj 1 @40.5,79.0
  goto 38.9,82.4 The back of the mine

step Goldshire
  turnin 62 @42.1,65.9 -- Marshal Dughan
  level 7
```

## Header

| Line | Meaning |
|---|---|
| `title <text>` | Required. The guide's name. |
| `faction Alliance` / `Horde` | Who sees it by default. |
| `races Human, Dwarf` | Optional. `NightElf`, `Scourge` (Forsaken) and `Skyborne` are spelled like that. |
| `classes Warrior, Mage` | Optional. |
| `levels 5-10` | Level band, used by the picker and the suggestion. |
| `zone <text>`, `next <guide id>`, `why <text>` | Optional. `next` loads that guide when this one is finished. |
| `map <uiMapID>` | Default map for coordinates below. May appear again later to change it. Add ` era` after the ID for classic-era coordinates. |

`/waypost where` prints the map ID and your coordinates, ready to paste.

## Steps

`step <title>` starts a step. Indented lines under it:

| Line | Meaning |
|---|---|
| `tip <text>` | Shown under the step title. |
| `why <text>` | Shown when the player clicks "Why?". Without it Waypost works an explanation out. |
| `danger <text>` | A red warning line. `danger skip` drops the step when "Safer route" is on. |
| `only Warrior, Mage` / `only Human` / `only Horde` | The step is only for those classes, races or faction. |
| `label <name>` | Names the step (for conditions in converted guides). |

## Goals

| Line | Completes when |
|---|---|
| `accept <questID> [title]` | the quest is in your log |
| `turnin <questID> [title]` | the quest is handed in |
| `complete <questID> [title]` | the quest is ready to hand in |
| `kill <count> <name> quest <id> obj <n>` | that objective of the quest is done |
| `collect <count> <itemID> [name] [quest <id> obj <n>]` | the objective is done, or the bags hold that many |
| `buy <count> <itemID> [name]` | the bags hold that many |
| `use <itemID> [name] [quest <id> obj <n>]` | the objective is done (shows the item button) |
| `talk <name>`, `interact <name>` | with `quest <id> obj <n>`: the objective; otherwise ticked by hand |
| `goto <x>,<y>[,<mapID>] [text]` | you arrive (also `explore`, `enter`) |
| `level <n>` | you reach the level |
| `train`, `vendor`, `hearth` | you close the trainer or vendor window, or tick it |
| `getfp <name>`, `fly <name>`, `sethome <name>` | the flight point is learned, the flight lands, the hearthstone is bound |
| `learn <spellID> [name]`, `money <copper>` | you know the spell, you have the money |
| `note <text>` | informational; a step of only notes waits for Next |

Any goal line may end with:

- `@x,y` or `@x,y,<mapID>` (and `,era`): where it is. The arrow and pins use this.
- `optional`: does not hold the step up.
- `-- text`: a note shown under the goal.

## Sharing

**Export string** in the editor turns the text into one line starting with `WP1:` (base64) or `WP2:`
(compressed by the game client). **Import string** turns it back. The browser editor reads and
writes `WP1:` strings.

## From Lua

```lua
Waypost.RegisterGuide({
  id = "mine/goldshire", title = "Goldshire loop", faction = "Alliance", minLevel = 5, maxLevel = 10,
  steps = {
    { title = "Marshal Dughan", goals = {
      { t = "accept", quest = 62, title = "The Fargodeep Mine", map = 1429, x = 42.1, y = 65.9 },
    } },
  },
})
```
