-- Waypost test suite. Run from the repository root:  lua5.1 tests/run.lua
local M = dofile("tests/wowmock.lua")
M.install()

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. name) end
end
local function section(name) print("== " .. name) end

---------------------------------------------------------------------------
section("load")
M.loadAddon("Waypost")
local W = Waypost
-- live maps answer with the Era bounds, so live and era coordinates agree in tests
do
	local f = assert(loadfile("Waypost/Data/MapFrames.lua"))
	local saved = W.RegisterMapFrames
	W.RegisterMapFrames = function(t) M.bounds = t; saved(t) end
	f("Waypost", {})
	W.RegisterMapFrames = saved
end
M.login()
check(W.opt ~= nil and W.char ~= nil, "saved variables initialised")
check(#W.Guides.index > 200, "guide index registered (" .. #W.Guides.index .. ")")
check(WaypostFrame ~= nil and WaypostArrow ~= nil and WaypostItemButton ~= nil, "frames built")
check(W.lastError == nil, "no handler errors during login: " .. tostring(W.lastError))

local E, G, P = W.Engine, W.Guides, W.Parser
G.keepAll = true     -- the suite walks every guide; in play, other races' and classes' guides are dropped

---------------------------------------------------------------------------
section("guide suggestion")
local s = G.Suggest()
check(s and s.id == "alliance/human/01-elwynn-forest", "human level 1 -> Elwynn (" .. tostring(s and s.id) .. ")")
M.player.level = 12; W.RefreshPlayer()
s = G.Suggest()
check(s and s.id == "alliance/02-westfall", "human level 12 -> Westfall (" .. tostring(s and s.id) .. ")")
M.player.level = 34; W.RefreshPlayer()
s = G.Suggest()
check(s and s.minLevel <= 34 and s.maxLevel >= 34, "level 34 gets a guide covering 34 (" .. tostring(s and s.id) .. ")")
M.player.level = 1; W.RefreshPlayer()

---------------------------------------------------------------------------
section("engine: walking the first steps of Elwynn")
check(E.Load("alliance/human/01-elwynn-forest"), "guide loads (route pack loads on demand)")
check(M.addons["Waypost_Routes_Alliance"], "Alliance pack loaded on demand")
check(not M.addons["Waypost_Routes_Horde"], "Horde pack not loaded")
check(E.index == 1, "starts at step 1 (" .. tostring(E.index) .. ")")
local step = E.guide.steps[1]
local vis = E.Visible(step)
local hasWarlock = false
for _, g in ipairs(vis) do if g.only and g.only.classes and g.only.classes[1] == "WARLOCK" then hasWarlock = true end end
check(not hasWarlock, "warlock-only goal hidden from a warrior")
local target = E.Target()
check(target and target.quest == 783 and target.t == "accept", "arrow targets the first accept")
check(W.Coords.GoalDistance(target) ~= nil, "distance to target computes")

M.accept(783, "A Threat Within")
check(E.GoalState(vis[1], 1) == true, "accept goal done after QUEST_ACCEPTED")
check(E.index == 1, "still on step 1")
M.turnin(783)
M.accept(7, "Kobold Camp Cleanup", { { text = "Kobold Vermin slain: 0/10", finished = false, numFulfilled = 0, numRequired = 10, type = "monster" } })
M.accept(5261, "Eagan Peltskinner")
M.turnin(5261)
M.accept(33, "Wolves Across the Border", { { text = "Tough Wolf Meat: 0/8", finished = false, numFulfilled = 0, numRequired = 8, type = "item" } })
check(E.index == 2, "step 1 complete -> step 2 (" .. tostring(E.index) .. ")")
check(E.guide.steps[2].title == "Wolves", "step 2 is Wolves")
local wolf = E.Visible(E.guide.steps[2])[1]
local _, cur, need = E.GoalState(wolf, 2)
check(cur == 0 and need == 8, "objective progress read from the quest log")
local text = E.GoalText(wolf, 2)
check(text:find("Tough Wolf Meat") and text:find("0/8"), "goal text shows item and count: " .. text)

-- combat: by default objectives tick off as they happen
check(W.opt.combatUpdates == true, "live updates in combat are the default")
M.player.combat = true
M.fire("PLAYER_REGEN_DISABLED")
M.quests[33].objectives[1].numFulfilled = 5
M.update()
local _, midFight = E.GoalState(wolf, 2)
check(midFight == 5, "progress is read during combat (" .. tostring(midFight) .. "/8)")
-- with "keep updating during combat" off: quiet, then catches up
W.Set("combatUpdates", false)
M.quests[33].objectives[1].finished = true
M.quests[33].objectives[1].numFulfilled = 8
M.update()
check(E.index == 2, "no advance during combat when live updates are off")
M.player.combat = false
M.fire("PLAYER_REGEN_ENABLED")
M.advance(0.5)
check(E.index == 3, "advances once combat ends (" .. tostring(E.index) .. ")")
W.Set("combatUpdates", true)

-- and with the default, a step finished mid-fight advances at once
do
	local at = E.index
	M.player.combat = true
	M.fire("PLAYER_REGEN_DISABLED")
	E.Next()
	check(E.index > at, "step completes during combat with live updates on")
	M.player.combat = false
	M.fire("PLAYER_REGEN_ENABLED")
	M.advance(0.5)
	E.Back()
	if E.view then E.Look(0) end
end

---------------------------------------------------------------------------
section("engine: skip, undo, look ahead, back")
local at = E.index
E.Skip()
check(E.index > at and E.IsSkipped(at), "skip moves on and marks the step")
local afterSkip = E.index
E.Look(1)
check(E.view and E.view > afterSkip and E.index == afterSkip, "look ahead does not lose place")
E.Look(0)
check(E.view == nil, "return from look ahead")
check(E.UndoSkip() and E.index == at and not E.IsSkipped(at), "undo returns to the skipped step")
E.Skip()
E.Back()
check(E.index == at, "back un-skips the previous step")
check(type(E.Why()) == "string" and #E.Why() > 10, "why-this-step text")

---------------------------------------------------------------------------
section("engine: xp skips and conditions")
M.player.level = 30; W.RefreshPlayer()
W.Set("route.xpSkips", true)
check(W.Quest.IsTrivial(5, 30) and not W.Quest.IsTrivial(28, 30), "grey-level rule")
W.Set("route.xpSkips", false)
M.player.level = 1; W.RefreshPlayer()

---------------------------------------------------------------------------
section("group quests: left out when solo, and nothing later waits for them")
do
	W.RegisterGuide({ id = "test/group", title = "Group test", steps = {
		{ title = "Elite quest", when = { { k = "group", q = 9001 } }, goals = { { t = "accept", quest = 9001, title = "Big Bad", group = true } } },
		{ title = "Kill it", when = { { k = "group", q = 9001 } }, goals = { { t = "kill", quest = 9001, oi = 1, target = "Big Bad", count = 1 } } },
		{ title = "Hand it in", goals = { { t = "turnin", quest = 9001, title = "Big Bad" } } },
		{ title = "Carry on", goals = { { t = "accept", quest = 9002, title = "Next Quest" } } },
	} })
	M.player.inGroup = false
	E.Load("test/group", true)
	check(E.index == 4, "solo: the group quest and its hand-in are passed over (step " .. tostring(E.index) .. ")")
	check(W.char.setAside[9001] and W.char.setAside[9001].reason == "group", "the passed-over group quest is set aside")
	M.player.inGroup = true
	M.chat = {}
	M.fire("GROUP_ROSTER_UPDATE")
	local offered = false
	for _, line in ipairs(M.chat) do if line:find("group quest") then offered = true end end
	check(offered, "joining a party offers the set-aside group quest back")
	E.Rescan()
	check(E.index == 1, "in a party: the group quest is back in the route (step " .. tostring(E.index) .. ")")
	M.player.inGroup = false
	W.Set("route.groupQuests", true)
	E.Rescan()
	check(E.index == 1, "solo with 'include group quests' on: kept (step " .. tostring(E.index) .. ")")
	W.Set("route.groupQuests", false)
	-- a quest that cannot be done right now: Skip drops its later goals too, Undo restores it
	E.Rescan()
	M.accept(9002, "Next Quest")
	W.Guides.Unregister("test/group")
	W.char.skippedQuests, W.char.setAside = {}, {}
	M.quests = {}
	M.fire("GROUP_ROSTER_UPDATE")
end

---------------------------------------------------------------------------
section("later: set aside, catch up at a level gate, offered back, returned to")
do
	W.RegisterGuide({ id = "test/later", title = "Later test", steps = {
		{ title = "Hard quest", goals = { { t = "accept", quest = 9101, title = "Too Hard" } } },
		{ title = "Do it", goals = { { t = "kill", quest = 9101, oi = 1, target = "Ogre", count = 5, map = 1429, x = 50, y = 50, era = true, mobLevel = 1 } } },
		{ title = "Hand in", goals = { { t = "turnin", quest = 9101, title = "Too Hard" } } },
		{ title = "Level gate", goals = { { t = "level", level = 5 } } },
	} })
	E.Load("test/later", true)
	E.Later()
	check(E.index == 4, "Later moves past the quest and everything that needed it (step " .. tostring(E.index) .. ")")
	check(W.SetAside.Count() == 1, "the quest is on the set-aside list")
	local info = table.concat(E.GoalInfo(E.Current(), 4), " | ")
	check(info:find("XP to level 2") ~= nil, "level gate says how much XP is missing: " .. info)
	local spot = E.GrindSpot()
	check(spot and spot.text == "Ogre", "a grind spot of the right level is offered")
	local okRender = pcall(W.StepFrame.Render)
	check(okRender, "the catch-up card renders")
	M.chat = {}
	M.player.level = 3
	M.fire("PLAYER_LEVEL_UP", 3)
	M.advance(1)
	local offered = false
	for _, line in ipairs(M.chat) do if line:find("set aside") then offered = true end end
	check(offered, "two levels later the quest is offered back")
	check(E.ReturnTo(9101) and E.index == 1, "Go back makes its step current again (step " .. tostring(E.index) .. ")")
	check(W.SetAside.Count() == 0 and not W.char.skippedQuests[9101], "and it is no longer skipped or set aside")
	local okWin = pcall(function() E.Later() W.SetAside.Toggle(true) W.SetAside.Toggle(false) E.Forget(9101) end)
	check(okWin and W.SetAside.Count() == 0, "set-aside window opens; Forget removes the entry")
	-- a quest you have but cannot finish: Later stops it holding the route up
	W.char.skippedQuests, W.char.setAside, W.char.undo = {}, {}, {}
	E.Load("test/later", true)
	M.accept(9101, "Too Hard", { { text = "Ogre slain: 0/5", finished = false, numFulfilled = 0, numRequired = 5, type = "monster" } })
	check(E.index == 2, "on the kill step with the quest in the log (step " .. tostring(E.index) .. ")")
	E.Later()
	check(E.index == 4, "Later on a quest you hold passes its objective and hand-in (step " .. tostring(E.index) .. ")")
	check(W.SetAside.Count() == 1, "and keeps it on the set-aside list")
	E.UndoSkip()
	check(E.index == 2 and W.SetAside.Count() == 0, "Undo puts it back")
	M.quests = {}
	M.player.level = 1
	W.RefreshPlayer()
	W.Guides.Unregister("test/later")
	W.char.deferred = {}
	W.char.skippedQuests, W.char.setAside, W.char.undo = {}, {}, {}
end

---------------------------------------------------------------------------
section("fast-forward for a character who already did part of the guide")
M.quests, M.completed = {}, {}
for _, q in ipairs({ 783, 7, 5261, 33, 18, 15, 21, 54 }) do M.completed[q] = true end
W.char.skippedQuests = {}
E.Load("alliance/human/01-elwynn-forest", true)
check(E.index == 5, "passes finished steps (and their walk/train goals), stops at the first unfinished quest (step " .. tostring(E.index) .. ")")

---------------------------------------------------------------------------
section("automation")
M.quests, M.completed, M.selected = {}, {}, {}
E.Load("alliance/human/01-elwynn-forest", true)
M.gossip.available = { { questID = 99999 }, { questID = 783 } }
M.gossip.active = {}
M.fire("GOSSIP_SHOW")
check(M.selected[1] == "available:783", "auto-picks the guide quest, ignores others (" .. tostring(M.selected[1]) .. ")")
M.selected = {}
M.shift = true
M.fire("GOSSIP_SHOW")
check(#M.selected == 0, "Shift bypasses automation")
M.shift = false
M.questFrameID = 783
M.fire("QUEST_DETAIL")
check(M.selected[1] == "accept:783", "auto-accept")
M.selected = {}
M.questFrameID = 4242
M.fire("QUEST_DETAIL")
check(#M.selected == 0, "does not accept quests outside the guide")
M.questFrameID, M.questChoices = 783, 3
M.fire("QUEST_COMPLETE")
check(#M.selected == 0, "pauses at reward choices")
M.questChoices = 0
M.fire("QUEST_COMPLETE")
check(M.selected[1] == "reward:1", "turns in when there is no choice")

---------------------------------------------------------------------------
section("parser")
local sample = [[
title Test route
faction Alliance
levels 3-7
map 1429

step First stop
  tip Talk to the marshal.
  only Warrior, Mage
  accept 62 The Fargodeep Mine @42.1,65.9
  kill 10 Kobold Vermin quest 62 obj 1 @40.5,79 optional
  collect 8 750 Tough Wolf Meat quest 33 obj 1 @50,44,1429,era -- wolves
  goto 48.2,42.9 The abbey

step Second
  turnin 62 @42.1,65.9 -- back at the inn
  level 5
  fly Sentinel Hill
]]
local guide, errs = P.Parse(sample)
check(guide ~= nil, "sample parses" .. (errs and (": " .. errs[1].line .. " " .. errs[1].msg) or ""))
if guide then
	check(#guide.steps == 2 and #guide.steps[1].goals == 4, "steps and goals counted")
	local g = guide.steps[1].goals
	check(g[1].quest == 62 and g[1].x == 42.1 and g[1].map == 1429, "accept with coordinates and default map")
	check(g[2].optional and g[2].oi == 1 and g[2].count == 10 and g[2].target == "Kobold Vermin", "kill line")
	check(g[3].item == 750 and g[3].era == true and g[3].note == "wolves", "collect with era frame and note")
	check(g[4].t == "goto" and g[4].text == "The abbey", "goto with text")
	check(guide.steps[1].only.classes[1] == "WARRIOR", "only filter")
	check(guide.minLevel == 3 and guide.maxLevel == 7, "levels")
	local again = P.Parse(P.Serialize(guide))
	check(again and #again.steps == 2 and again.steps[1].goals[3].item == 750, "serialize -> parse round trip")
end
local bad, e2 = P.Parse("title X\nstep A\n  accept\n  frobnicate 1\n")
check(bad == nil and e2[1].line == 3 and e2[2].line == 4, "errors carry line numbers")
local str = P.Export(sample)
check(str:find("^WP1:") ~= nil, "export string")
check(P.Import(str) == sample, "import restores the text exactly")
check(P.Import("garbage") == nil, "rejects junk")
check(W.RegisterGuide(guide) and G.Meta(guide.id) ~= nil, "custom guide registers")

---------------------------------------------------------------------------
section("every shipped guide builds, applies and round-trips through the text format")
local KNOWN = { accept = 1, turnin = 1, complete = 1, kill = 1, collect = 1, interact = 1, talk = 1, use = 1, ["goto"] = 1,
	enter = 1, explore = 1, level = 1, train = 1, fly = 1, getfp = 1, sethome = 1, buy = 1, vendor = 1, note = 1,
	learn = 1, skill = 1, rep = 1, money = 1, die = 1, task = 1, craft = 1 }
for _, pack in ipairs({ "Waypost_Routes_Horde", "Waypost_Routes_Extras" }) do C_AddOns.LoadAddOn(pack) end
local guides, steps, goals, located, unlocated, badType, badText, rt = 0, 0, 0, 0, 0, 0, 0, 0
local badMaps = {}
for _, meta in ipairs(G.index) do
	if meta.pack then
		local st = G.Peek(meta.id)
		check(st ~= nil, "steps exist for " .. meta.id)
		if st then
			guides = guides + 1
			check(#st == meta.steps, "index step count matches for " .. meta.id)
			for _, s2 in ipairs(st) do
				steps = steps + 1
				for _, g in ipairs(s2.goals) do
					goals = goals + 1
					if not KNOWN[g.t] then badType = badType + 1 end
					if g.map then
						-- era coordinates must resolve from the shipped frames; live ones need the real client
						if not g.era then located = located + 1
						elseif W.Coords.ToWorld(g.map, g.x, g.y, true) then located = located + 1
						else unlocated = unlocated + 1; badMaps[g.map] = (badMaps[g.map] or 0) + 1 end
					end
					local ok, t = pcall(E.GoalText, g, 1)
					if not ok or type(t) ~= "string" or t:find("{%a+:%d+}") then badText = badText + 1 end
				end
			end
			if meta.category == "Leveling" then
				local full = setmetatable({ steps = st }, { __index = meta })
				local back, perr = P.Parse(P.Serialize(full))
				if not back or #back.steps ~= #st then
					rt = rt + 1
					if rt <= 3 then print("  round trip failed: " .. meta.id .. " " .. (perr and (perr[1].line .. ": " .. perr[1].msg) or "step count")) end
				end
			end
		end
	end
end
print(("  %d guides, %d steps, %d goals, %d located"):format(guides, steps, goals, located))
check(badType == 0, "all goal types known (" .. badType .. " unknown)")
check(badText == 0, "all goals render text with no unresolved placeholders (" .. badText .. ")")
for m, n in pairs(badMaps) do print("  no era frame for map " .. m .. " (" .. n .. " goals)") end
check(unlocated == 0, "every coordinate converts to world position (" .. unlocated .. " failed)")
check(rt == 0, "leveling guides round-trip through the text format (" .. rt .. " failed)")

-- chain: every leveling guide's `next` exists, and both factions reach 60
for _, meta in ipairs(G.index) do
	if meta.next then check(G.Meta(meta.next) ~= nil, "next exists: " .. meta.id .. " -> " .. meta.next) end
end
for _, start in ipairs({ "alliance/human/01-elwynn-forest", "alliance/dwarf/01-dun-morogh", "alliance/nightelf/01-teldrassil",
	"alliance/gnome/01-dun-morogh", "horde/orc/01-durotar", "horde/tauren/01-mulgore", "horde/troll/01-durotar", "horde/undead/01-tirisfal-glades" }) do
	local id, top, n = start, 0, 0
	while id and n < 60 do
		local m = G.Meta(id)
		top = math.max(top, m.maxLevel)
		id, n = m.next, n + 1
	end
	check(top == 60, start .. " chain reaches level 60 (" .. top .. ")")
end

---------------------------------------------------------------------------
section("every guide loads into the engine and renders")
do
	local broken = 0
	local savedGuide = W.char.guide
	for _, meta in ipairs(G.index) do
		if meta.pack then
			W.char.progress[meta.id] = nil
			local ok, err = pcall(function()
				E.Load(meta.id, true)
				W.StepFrame.Render()
				for _ = 1, 3 do if E.guide and E.guide.id == meta.id then E.Next() end end
				W.Pins.Refresh()
				W.Buttons.Refresh()
			end)
			if not ok or W.lastError then
				broken = broken + 1
				if broken <= 3 then print("  " .. meta.id .. ": " .. tostring(err or W.lastError)) end
				W.lastError = nil
			end
			W.char.progress[meta.id] = nil
		end
	end
	check(broken == 0, "all guides load, advance and render (" .. broken .. " failed)")
	W.char.guide = savedGuide
	W.char.undo, W.char.skippedQuests = {}, {}
end

---------------------------------------------------------------------------
section("UI code paths")
local function try(name, fn)
	local ok, err = pcall(fn)
	check(ok, name .. (ok and "" or (": " .. tostring(err))))
end
E.Load("alliance/human/01-elwynn-forest", true)
try("render step frame", function() W.StepFrame.Render() end)
try("compact mode", function() W.Set("ui.compact", true) W.StepFrame.Render() W.Set("ui.compact", false) end)
try("step list", function() W.Set("ui.listOpen", true) M.advance(0.2) W.StepFrame.Render() W.StepFrame.RenderList(true) end)
try("each skin", function() for _, sk in ipairs(W.UI.SKINS) do W.Set("ui.skin", sk[1]) W.StepFrame.Render() end W.Set("ui.skin", "panel") end)
try("heading font: quest-log face by default, switchable", function()
	check(W.opt.ui.headFont == "quest" and W.UI.HeadFace():find("MORPHEUS") ~= nil, "headings use the quest-log title face")
	W.Set("ui.headFont", "text")
	check(W.UI.HeadFace():find("FRIZ") ~= nil, "or the text face")
	W.Set("ui.headFont", "quest")
end)
try("game menu button", function()
	GameMenuFrame:Show()
	check(W.opt.ui.gameMenu == true, "game menu button is on by default")
	GameMenuFrame:Hide()
end)
try("arrow refresh + update", function()
	W.Arrow.Refresh()
	local f = WaypostArrow
	for i = 1, 30 do M.player.facing = i * 0.3; f._scripts.OnUpdate(f, 0.05) end
end)
try("arrow in every colour mode", function()
	for _, mode in ipairs({ "gold", "distance" }) do W.Set("arrow.color", mode) WaypostArrow._scripts.OnUpdate(WaypostArrow, 0.3) end
	W.Set("arrow.colorblind", true) WaypostArrow._scripts.OnUpdate(WaypostArrow, 0.3) W.Set("arrow.colorblind", false)
end)
try("pins", function() WorldMapFrame._shown = true W.Pins.Refresh() M.advance(0.5) end)
try("buttons", function() W.Buttons.Refresh() end)
try("picker", function()
	W.Picker.Toggle(true)
	for _, cat in ipairs(G.Categories()) do end
	W.Picker.Toggle(false)
end)
try("options", function() W.Options.Toggle(true) W.Options.Refresh() W.Options.Toggle(false) end)
try("about", function() W.About.Show() end)
try("editor", function() W.Editor.Open() end)
try("xp window with the level chart", function()
	W.char.xp.levels = { [1] = 600, [2] = 900, [3] = 2400, [4] = 1500 }
	W.char.xp.levelTime = 300
	M.player.level = 5; W.RefreshPlayer()
	W.XP.ToggleWindow(true)
	local series = W.XP.LevelSeries()
	check(#series == 5 and series[1].level == 1 and series[5].live == true, "chart series: four finished levels and the one in progress")
	check(series[3].secs == 2400, "bars carry the time for their level")
	W.XP.RenderChart()
	W.char.xp.levels = {}
	W.char.xp.levelTime = 0
	W.XP.RenderChart()
	M.player.level = 1; W.RefreshPlayer()
end)
try("level-up animation", function()
	W.StepFrame.Toggle(true)
	check(W.Ding.Play(7, "Level 6 took 12m 30s") == true, "ding plays in the guide window")
	W.Set("ui.ding", false)
	check(W.Ding.Play(8) == false, "and can be switched off")
	W.Set("ui.ding", true)
	W.StepFrame.Toggle(false)
	check(W.Ding.Play(8) == false, "no animation while the window is hidden")
	W.StepFrame.Toggle(true)
	M.fire("PLAYER_LEVEL_UP", 2)
	M.advance(1)
	M.player.level = 1; W.RefreshPlayer()
end)
try("talents window", function() W.Talents.Toggle(true) end)
try("party window", function() W.Group.Toggle(true) end)
try("guild window (no guild)", function() W.Guild.Toggle(true) end)
try("guild window (guild)", function() M.player.guild = "Dragon Warriors" W.Guild.Toggle(false) W.Guild.Toggle(true) end)
try("orphans window", function() M.quests[424242] = { title = "Stray quest" } W.Orphans.Toggle(true) end)
check(#W.Orphans.Find() == 1 and W.Orphans.Find()[1].id == 424242, "orphan detection finds the stray quest only")
try("report", function() W.Report.Open("test note") end)
try("welcome and help topics", function()
	for _, key in ipairs({ "welcome", "window", "arrow", "auto", "stuck", "group", "own", "commands" }) do W.Help.Open(key) end
	W.Help.Toggle()
end)
check(W.db.seenWelcome == true, "the welcome was shown on first login")
try("toast", function() W.UI.Toast("Title", "Body") end)
try("empty state", function() E.Unload() W.StepFrame.Render() end)
try("slash commands", function()
	for _, c in ipairs({ "help", "commands", "later", "ding", "guides", "config", "why", "where", "xp", "talents", "party", "guild", "orphans", "editor",
		"nearest trainer", "resume", "rescan", "reset", "version", "next", "back", "skip", "undo", "show" }) do
		SlashCmdList["WAYPOST"](c)
	end
end)
check(W.lastError == nil, "no handler errors during UI tests: " .. tostring(W.lastError))

---------------------------------------------------------------------------
section("talents, xp, recorder, comm, export")
check(W.Talents.Build() ~= nil and W.Talents.PicksAt(10) ~= nil, "warrior talent plan has a level 10 pick")
M.player.xp = 100; M.fire("PLAYER_XP_UPDATE", "player")
M.advance(120)
M.player.xp = 300; M.fire("PLAYER_XP_UPDATE", "player")
check(W.XP.Rate() > 0 and W.XP.TimeToLevel() ~= nil, "xp per hour and time to level")
check(type(W.XP.ShortText()) == "string", "xp footer text")

E.Load("alliance/human/01-elwynn-forest", true)
W.Recorder.Start()
M.accept(777001, "Recorded Quest")
M.turnin(777001)
local draft = W.Recorder.Text()
check(draft and draft:find("accept 777001 Recorded Quest") and draft:find("turnin 777001"), "recorder captures accept and turn-in")
local parsed, perr = P.Parse(draft)
check(parsed ~= nil, "recorded draft parses" .. (perr and (": line " .. perr[1].line .. " " .. perr[1].msg) or ""))
W.Recorder.Stop()

M.player.inGroup = true
M.sent = {}
M.fire("GROUP_ROSTER_UPDATE")
M.advance(3)
local sentParty = false
for _, m in ipairs(M.sent) do if m.channel == "PARTY" and m.msg:find("^S\t") then sentParty = true end end
check(sentParty, "party state broadcast on joining a group")
M.fire("CHAT_MSG_ADDON", "Waypost", "S\talliance/02-westfall\t5\t65\tGoldshire\t12\t", "PARTY", "Friend-Mockrealm")
check(W.lastError == nil, "incoming party state handled")
M.trial = true
M.sent = {}
for i = 1, 5 do W.Comm.Send("PARTY", "R") end
check(W.Comm.available == false and #M.sent == 0, "send failures disable sync quietly (trial accounts)")
check(E.guide ~= nil, "engine unaffected by sync failure")

W.Export.Update()
local ex = WaypostDB.export.characters["Tester-Mockrealm"]
check(ex and ex.guide == "alliance/human/01-elwynn-forest" and ex.level == 1, "export block written for the companion app")

M.fire("PLAYER_LOGOUT")
check(WaypostBackup and WaypostBackup.chars["Tester-Mockrealm"] ~= nil, "backup copy written at logout")

---------------------------------------------------------------------------
section("memory")
E.Load("alliance/human/01-elwynn-forest")
collectgarbage("collect"); collectgarbage("collect")
print(("  Lua heap with all three packs loaded (test worst case): %.2f MB"):format(collectgarbage("count") / 1024))

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
