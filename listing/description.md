![Waypost](banner-1600x400.png)

Waypost is a leveling guide addon for WoW Forever. It's free, the source is on GitHub, and there's no account to link.

It comes with routes from 1 to 60 for every race on both factions, plus guides for class quests, professions and reputations. The routes are [Polestar's](https://github.com/fitzforge/polestar), converted to run in this addon, so the credit for the routing work is theirs.

## While you play

- Shows what to do now, who it involves and where it is (distance and direction), then the rest of the step and what's next. There's a compact mode too.
- An arrow points to the next objective. It's a 3D arrow that turns as you turn, with distance and a rough time to get there. Pins go on the map and minimap too.
- Picks up and hands in the guide's quests for you. It stops when there's a reward to choose. Hold Shift when you open an NPC if you'd rather do it yourself.
- A button for the step's quest item and one to target the mob or NPC. Both can be bound to keys.
- Keeps track of your flight paths and takes the flight the guide wants.
- Skip a step, undo the skip, or peek ahead and come back.
- XP per hour and time to level sit in the corner of the window.

## Other things it does

- Suggests a talent when you level up.
- Flags quest rewards and vendor items that beat what you're wearing. Uses Pawn if you have it.
- `/waypost orphans` lists quests in your log that the route will never finish, so you can drop them.
- Party panel: see where everyone is in the guide, pull them onto your step, share a quest someone missed.
- Guild board: who's on which guide and what level. Officers can set a guide for the guild.
- Write your own guides in a simple text format, or record one by playing it. Guides can be shared as import strings.

## Combat

Objectives tick off as they happen, in combat too. If you'd rather Waypost stayed idle during a fight and caught up afterwards, there's a setting for that.

## Commands

`/waypost` shows or hides the window. `/waypost guides` picks a guide. `/waypost config` opens settings. `/waypost help` lists the rest.

## What's missing

- No mailbox automation.
- No auction house scanning for upgrades.
- Guide text is English only. The interface is partly translated (German, French, Spanish, Portuguese, Chinese).

## Wrong step?

Type `/waypost report` in game and paste what it gives you into an issue on [GitHub](https://github.com/gavenrobertson/waypost/issues).

Licensed GPL-3.0. Full credits are in the addon's About window.
