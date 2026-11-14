# In-game test checklist

The automated tests run the addon against a mock of the game API. These checks need the real client.

## First login (new character)

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
- [ ] Esc shows a Waypost button under the game menu; it opens the guide list.
- [ ] Reward choices are not picked for you.
- [ ] The quest item button appears for a "use" step and its key binding works.
- [ ] The target button targets the step's enemy.

## Controls

- [ ] Skip, `/waypost undo`, Shift-click Next (look ahead), Back.
- [ ] Compact mode, each window style, font size, scale, lock.
- [ ] Drag the window and the arrow; `/reload`; both stay where they were.
- [ ] Settings search finds "arrow".

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
