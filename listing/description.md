![Waypost](https://raw.githubusercontent.com/gavenrobertson/WayPost/1f9b81f155c3b1974717946da8cbb88bcb1581d8/listing/banner-1600x400.png)

# Waypost

Waypost is a leveling guide addon for WoW Forever. It's free, the source is on GitHub, and there's no account to link.

It comes with routes from 1 to 60 for every race on both factions, plus guides for class quests, professions and reputations. The routes are [Polestar's](https://github.com/fitzforge/polestar), converted to run in this addon, so the credit for the routing work is theirs.

The first time you log in, a welcome window explains the basics and offers the guide for your character. Press Start and follow the arrow.

## The guide window

- A card at the top says the one thing to do right now: the quest, mob or item, who gives or takes the quest, what drops the item, and how far away it is and in which direction.
- Under it are the rest of the step's goals. They tick themselves off as you do them, in combat too.
- Below that is what's coming next and how far away it is.
- A live XP tracker: XP per hour over the last ten minutes (it climbs as you earn and drops when you stop), time to level counting down second by second, XP for each of the last ten minutes, and about how many kills or quests are left to level.
- A graph of how long each level took.
- When you ding, a level-up banner plays in the window.
- Three layouts: Simple (just what to do and where), Standard, and Detailed (everything). Or tick the parts you want and make your own.
- Every window resizes from its corner, and three window styles. It uses the game's own fonts.

## The arrow

![The arrow at different headings](https://raw.githubusercontent.com/gavenrobertson/WayPost/1f9b81f155c3b1974717946da8cbb88bcb1581d8/listing/arrow-headings.png)

- A 3D gold arrow points at your next objective and turns as you turn.
- Distance and a rough time to get there are under it.
- It points down and goes green when you arrive.
- Pins for the step go on the world map and minimap, with dots where the step's mobs or items are found.
- If you use TomTom, a setting hands the waypoint to TomTom instead.

## Less clicking

- Picks up and hands in the guide's quests for you. It stops when there's a reward to choose, and it never touches quests that aren't in the guide.
- Hold Shift when you open an NPC if you'd rather do it yourself.
- A button for the step's quest item and one to target the mob or NPC. Both can be bound to keys.
- Keeps track of your flight paths and takes the flight the guide wants.

## When you're stuck

- **Skip** drops a step. Anything later that needed its quests is dropped too, so the guide never waits on something you skipped. Undo brings it back.
- **Later** sets the step's quests aside instead. You get them offered back when you join a party or gain a couple of levels.
- Group quests are left out while you're solo and set aside for you. Join a party and it tells you they can be done.
- If the route needs a level you haven't reached, it shows how much XP you're short and points you at the quests you set aside or the nearest mobs your level.
- Did some quests without the addon? "Re-read my quest log" in the menu catches the guide up.

![Golden arrow on a forest road](https://raw.githubusercontent.com/gavenrobertson/WayPost/1f9b81f155c3b1974717946da8cbb88bcb1581d8/listing/gallery-art.jpg)

## Leveling with friends

- Party panel: see which guide and step everyone is on, pull the party onto your guide, share a quest someone missed.
- Guild board: who's on which guide and what level. Officers can set a guide for the guild and send notices.
- Everyone needs Waypost for these. People without it show as "no data".

## Other things it does

- Suggests a talent when you level up.
- Flags quest rewards and vendor items that beat what you're wearing. Uses Pawn if you have it.
- Lists quests in your log that your route will never finish, so you can drop them.
- "Why?" on any step explains what the step is for.
- Warns about elite and group quests, and has a safer route for Hardcore.
- Write your own guides in a simple text format, or record one by playing it. Guides can be shared as import strings.

## Commands

| Command | What it does |
|---|---|
| `/waypost` | Show or hide the guide window |
| `/waypost guides` | Pick a guide |
| `/waypost config` | Settings |
| `/waypost help` | The welcome and help window |
| `/waypost later` | Quests you set aside |
| `/waypost tracker` | The live XP tracker |
| `/waypost xp` | Leveling speed and the time-per-level graph |
| `/waypost layout detailed` | Switch layout (simple, standard, detailed) |
| `/waypost party` | Party progress |
| `/waypost guild` | Guild leveling board |
| `/waypost report` | A report to paste when a step is wrong |

The game menu (Esc) has a Waypost button for settings, and there's a minimap button.

## What's missing

- No mailbox automation.
- No auction house scanning for upgrades.
- Guide text is English only. The interface is partly translated (German, French, Spanish, Portuguese, Chinese).

## Wrong step?

Type `/waypost report` in game and paste what it gives you into an issue on [GitHub](https://github.com/gavenrobertson/waypost/issues).

## Credits

Routes and talent plans are from [Polestar Guides](https://github.com/fitzforge/polestar) by The Polestar authors, used under the GPL-3.0. Waypost is GPL-3.0 too. Full credits are in the addon's About window.
