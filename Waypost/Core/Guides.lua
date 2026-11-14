-- Guide registry.
--
-- The index (Data/GuideIndex.lua) lists every guide's metadata so the picker
-- works without loading any route data. Route packs are LoadOnDemand addons;
-- each registers its guides' steps as a function that builds the tables only
-- when that guide is opened, so only the active guide costs memory.

local W = Waypost
local L = W.L
local G = {}
W.Guides = G

local index, byId, stepFns, built = {}, {}, {}, {}
G.index, G.byId = index, byId

function W.RegisterIndex(list)
	for _, meta in ipairs(list) do
		if not byId[meta.id] then index[#index + 1] = meta end
		byId[meta.id] = meta
	end
end

-- Route packs hold guides for every race and class. Guides this character can
-- never use are dropped as the pack loads, so their data is garbage collected
-- (a Warrior's client does not keep eight other classes' quest chains).
local pruned = {}
function W.RegisterSteps(id, fn)
	local meta = byId[id]
	if meta and not G.keepAll and id ~= G.wanted and W.player.class and not G.Matches(meta) then
		pruned[id] = true
		return
	end
	pruned[id] = nil
	stepFns[id] = fn
	built[id] = nil
end

-- Third-party / custom guides: Waypost.RegisterGuide{ id=..., title=..., steps={...} }
function W.RegisterGuide(g)
	if type(g) ~= "table" or not g.id or type(g.steps) ~= "table" then return false end
	local meta = byId[g.id] or {}
	for k, v in pairs(g) do if k ~= "steps" then meta[k] = v end end
	meta.steps = #g.steps
	meta.category = meta.category or "Custom"
	meta.minLevel = meta.minLevel or 1
	meta.maxLevel = meta.maxLevel or 60
	if not byId[g.id] then index[#index + 1] = meta end
	byId[g.id] = meta
	local steps = g.steps
	stepFns[g.id] = function() return steps end
	built[g.id] = nil
	W.Fire("WP_GUIDES_CHANGED")
	return true
end

function G.Unregister(id)
	local meta = byId[id]
	if not meta then return end
	byId[id] = nil
	stepFns[id] = nil
	built[id] = nil
	for i = #index, 1, -1 do if index[i] == meta then table.remove(index, i) end end
	W.Fire("WP_GUIDES_CHANGED")
end

local function loadPack(pack)
	if not pack then return true end
	local A = C_AddOns
	if A and A.IsAddOnLoaded and A.IsAddOnLoaded(pack) then return true end
	if not (A and A.LoadAddOn) then return false end
	local ok, loaded, reason = pcall(A.LoadAddOn, pack)
	if not ok or not loaded then
		W.Print(L["Could not load route pack %s (%s). Enable it in the AddOns list."], pack, tostring(reason or "?"))
		return false
	end
	return true
end

-- Returns the guide with its steps (building them on first use), or nil.
function G.Get(id)
	if not id then return nil end
	local meta = byId[id]
	if not meta then return nil end
	if built[id] then return built[id] end
	if not stepFns[id] then
		G.wanted = id
		loadPack(meta.pack)
		G.wanted = nil
	end
	local fn = stepFns[id]
	if not fn then
		if pruned[id] then
			W.Print(L["That guide is for another race or class and was left out to save memory. Type /reload, then pick it first."])
		end
		return nil
	end
	local ok, steps = pcall(fn)
	if not ok or type(steps) ~= "table" then return nil end
	local guide = setmetatable({ steps = steps }, { __index = meta })
	-- Free the previously built guide unless it is the next one (prefetch).
	local active = W.char and W.char.guide
	for k in pairs(built) do
		if k ~= id and k ~= active and k ~= meta.next then built[k] = nil end
	end
	built[id] = guide
	return guide
end

function G.Meta(id) return byId[id] end

-- Steps of a guide without making it the cached one (for scans across a chain).
function G.Peek(id)
	local meta = byId[id]
	if not meta then return nil end
	if built[id] then return built[id].steps end
	if not stepFns[id] then loadPack(meta.pack) end
	local fn = stepFns[id]
	if not fn then return nil end
	local ok, steps = pcall(fn)
	return ok and steps or nil
end

---------------------------------------------------------------------------
-- Who a guide is for
---------------------------------------------------------------------------
local function listOk(list, v)
	if not list or #list == 0 then return true end
	return W.Contains(list, v)
end

function G.Matches(meta, p)
	p = p or W.player
	if meta.faction and meta.faction ~= "Both" and p.faction and meta.faction ~= p.faction then return false end
	if not listOk(meta.races, p.race) then return false end
	if not listOk(meta.classes, p.class) then return false end
	return true
end

-- `only` filters on a step or goal: { classes=, races=, factions= }
function G.OnlyOk(only, p)
	if not only then return true end
	p = p or W.player
	if only.classes and not W.Contains(only.classes, p.class) then return false end
	if only.races and not W.Contains(only.races, p.race) then return false end
	if only.factions and p.faction and not W.Contains(only.factions, p.faction) then return false end
	return true
end

-- Leveling guides for this character, sorted by level.
function G.ForPlayer(category)
	local out = {}
	for _, m in ipairs(index) do
		if (not category or m.category == category) and G.Matches(m) then out[#out + 1] = m end
	end
	table.sort(out, function(a, b)
		if a.minLevel ~= b.minLevel then return (a.minLevel or 0) < (b.minLevel or 0) end
		return (a.title or "") < (b.title or "")
	end)
	return out
end

function G.Categories()
	local seen, out = {}, {}
	for _, m in ipairs(index) do
		local c = m.category or "Other"
		if not seen[c] then seen[c] = true; out[#out + 1] = c end
	end
	local order = { Leveling = 1, Class = 2, Custom = 3, Reputation = 4, Professions = 5, Exploration = 6, Collectibles = 7 }
	table.sort(out, function(a, b) return (order[a] or 99) < (order[b] or 99) end)
	return out
end

-- Best leveling guide for the character's level, race and quest log.
-- Race starting guides win at the very start; otherwise the guide whose band
-- holds the level, preferring one in progress or whose quests are in the log.
local suggestKey, suggestResult
local function logKey()
	local n = (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries()) or 0
	return (W.player.level or 1) .. ":" .. n .. ":" .. #index
end

function G.Suggest()
	local k = logKey()
	if k == suggestKey then return suggestResult end
	local p = W.player
	local level = p.level or 1
	local best, bestScore
	local inBand = {}
	for _, m in ipairs(G.ForPlayer("Leveling")) do
		local score
		if level >= (m.minLevel or 1) and level <= (m.maxLevel or 60) then
			score = 100 - ((m.maxLevel or 60) - (m.minLevel or 1))
			if m.races then score = score + 50 end
			local prog = W.char and W.char.progress[m.id]
			if prog and prog.finished then
				score = score - 60
			elseif prog and prog.step and prog.step > 1 then
				score = score + 30
			end
			inBand[#inBand + 1] = m
		elseif level < (m.minLevel or 1) then
			score = 40 - ((m.minLevel or 1) - level) * 5
		else
			score = 20 - (level - (m.maxLevel or 60)) * 5
		end
		m._score = score
		if not bestScore or score > bestScore then best, bestScore = m, score end
	end
	-- Quest log: a guide that uses quests you already carry is the one you are on.
	local log = W.Quest and W.Quest.Log() or {}
	if #log > 0 and #inBand > 1 and #inBand <= 6 then
		local have = {}
		for _, q in ipairs(log) do have[q.id] = true end
		for _, m in ipairs(inBand) do
			local steps = G.Peek(m.id)
			local hits = 0
			if steps then
				for _, s in ipairs(steps) do
					for _, g in ipairs(s.goals) do
						if g.t == "turnin" and have[g.quest] then hits = hits + 1 end
					end
				end
			end
			local score = m._score + math.min(45, hits * 9)
			if score > bestScore then best, bestScore = m, score end
		end
	end
	suggestKey, suggestResult = k, best
	return best
end
