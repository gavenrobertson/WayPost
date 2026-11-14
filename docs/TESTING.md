# In-game test checklist

The automated tests run the addon against a mock of the game API. These checks need the real client.

## First login (new character)

- [ ] The welcome window opens a couple of seconds after the first login on the account, and its
      Start button loads the suggested guide. `/waypost help` reopens it; every topic shows text.
- [ ] No Lua errors on login (`/console scriptErrors 1`).
- [ ] The Waypost window appears and recommends your race's starting guide. **Start** loads it.
- [ ] The arrow points at the first quest giver and turns smoothly as you turn.
- [ ] Pins show on the minimap and the world map.

## Playing the first ten steps

- [ ] Guide quests are accepted and turned in automatically; Shift at the NPC stops that.
- [ ] Kill and collect counts tick up; the step advances on its own.
- [ ] Counts and ticks update during combat. With "Keep updating during combat" off, the window
      waits and catches up when combat ends.
- [ ] The Now card shows distance and direction, and they change as you move.
- [ ] Esc shows a Waypost button inside the menu, in its own section after Options/Shop; it opens
      settings, right-click opens the guide list. The menu's other buttons are not moved or broken.
- [ ] Reward choices are not picked for you.
- [ ] The quest item button appears for a "use" step and its key binding works.
- [ ] The target button targets the step's enemy.

## Controls

- [ ] Later on a step sets its quests aside; `/waypost later` lists them; Go back returns to the step.
- [ ] Solo, a group quest is passed over; joining a party shows a notice offering it back.
- [ ] At a "Reach level N" step below that level, the card shows the XP missing and the two links work.
- [ ] Skip, `/waypost undo`, Shift-click Next (look ahead), Back.
- [ ] Compact mode, each window style, font size, scale, lock.
- [ ] Step titles and window titles are in the quest-log title font; "Heading font" in settings switches it.
- [ ] Drag the window and the arrow; `/reload`; both stay where they were.
- [ ] Settings search finds "arrow".

## Layouts, resizing, XP tracker

- [ ] Simple, Standard and Detailed (... menu) each look right; ticking a part in Settings makes Custom.
- [ ] Drag the guide window's corner: it gets wider and narrower. Drag the step list's bottom edge.
- [ ] Every other window resizes from its corner and keeps the size after closing; double-click resets.
- [ ] `/waypost tracker`: the countdown ticks every second, XP/h rises on kills and falls while idle,
      "+N" pops over the bar, the per-minute bars fill from the right.

## Level-up and chart

- [ ] `/waypost ding` plays the banner in the guide window; a real level-up does too and names the time the level took.
- [ ] `/waypost xp` shows a bar per level; hovering a bar gives its time.

## Travel

- [ ] Opening a flight master marks the flight point learned and takes the guide's flight.
- [ ] `/waypost nearest trainer` points at a class trainer; `/waypost resume` returns.

## Group and guild

- [ ] Two characters in a party see each other's step in `/waypost party`.
- [ ] "Sync party to my guide" asks the other player and switches their guide.
- [ ] `/waypost guild` lists guild members using Waypost.

## Saved data

- [ ] Log out and back in: guide, step and timers are kept.
- [ ] `WTF/.../SavedVariables/WaypostDB.lua` contains an `export` block.

Report anything wrong with `/waypost report`.
