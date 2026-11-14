-- The guide engine: which step is current, which goals are done, when to advance.
--
-- Event driven. Quest, bag, level and zone events mark the engine dirty; one
-- debounced Evaluate() then re-reads only the current step's goals. Proximity
-- goals (goto / explore / enter) use a half-second ticker that only exists
-- while such a goal is the current target, and it sleeps in combat.

local W = Waypost
local L = W.L
local E = {}
W.Engine = E

local G, C = W.Guides, W.Coords
local Readable = W.Readable
local floor = math.floor

---------------------------------------------------------------------------
-- Quest log access
---------------------------------------------------------------------------
local Q = {}
W.Quest = Q
local QL = C_QuestLog
local turnedIn = {}      -- handed in this session (the flag can lag a frame behind the event)

function Q.IsDone(q)
	if turnedIn[q] then return true end
	return (QL and QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(q)) and true or false
end

function Q.IsOn(q)
	return (QL and QL.IsOnQuest and QL.IsOnQuest(q)) and true or false
end

function Q.IsReady(q)
	if not Q.IsOn(q) then return false end
	if QL.ReadyForTurnIn and QL.ReadyForTurnIn(q) then return true end
	if QL.IsComplete and QL.IsComplete(q) then return true end
	return false
end

function Q.Objectives(q)
	if not (QL and QL.GetQuestObjectives) then return nil end
	local t = QL.GetQuestObjectives(q)
	if type(t) ~= "table" or #t == 0 then return nil end
	return t
end

function Q.Title(q)
	local t = QL and QL.GetTitleForQuestID and QL.GetTitleForQuestID(q)
	if t and t ~= "" then return t end
	return nil
end

-- Quests in the log: list of { id=, title=, level= }
function Q.Log()
	local out = {}
	if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return out end
	for i = 1, QL.GetNumQuestLogEntries() do
		local info = QL.GetInfo(i)
		if info and not info.isHeader and not info.isHidden and info.questID then
			out[#out + 1] = { id = info.questID, title = info.title, level = info.level }
		end
	end
	return out
end

local function greyLevel(level)
	if level <= 5 then return 0 end
	if level <= 39 then return level - floor(level / 10) - 5 end
	if level <= 59 then return level - floor(level / 5) - 1 end
	return level - 9
end
function Q.IsTrivial(qlvl, level)
	if not qlvl or qlvl <= 0 then return false end
	return qlvl <= greyLevel(level or W.player.level or 1)
end

local function itemCount(id)
	local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
	if not fn then return 0 end
	return Readable(fn(id)) or 0
end
E.ItemCount = itemCount

local function spellKnown(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) and true or false end
	if IsPlayerSpell then return IsPlayerSpell(id) and true or false end
	if IsSpellKnown then return IsSpellKnown(id) and true or false end
	return false
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
E.guide = nil        -- active guide table (with steps)
E.index = nil        -- current step index
E.view = nil         -- step index being looked at (nil = current)
local prog           -- W.char.progress[guide.id]

local PROXIMITY = { ["goto"] = 14, explore = 35, enter = 25, die = 40 }
local SOFT = { ["goto"] = 1, explore = 1, enter = 1, train = 1, vendor = 1, note = 1, fly = 1, sethome = 1,
	getfp = 1, buy = 1, die = 1, task = 1, hearth = 1, skill = 1, craft = 1, rep = 1, money = 1, learn = 1 }
local MANUAL = { train = 1, vendor = 1, task = 1, craft = 1, skill = 1, hearth = 1 }

local function key(si, gi) return si .. ":" .. gi end

local function latched(si, gi) return prog and prog.done[key(si, gi)] end
local function latch(si, gi) if prog then prog.done[key(si, gi)] = true end end
E.Latch = latch

---------------------------------------------------------------------------
-- Conditions (`when`) and filters (`only`)
---------------------------------------------------------------------------
local function cmp(a, op, b)
	if op == "<" then return a < b elseif op == "<=" then return a <= b
	elseif op == ">" then return a > b elseif op == "==" then return a == b end
	return a >= b
end

local function wantsGroup()
	if W.opt.route.saferRoute then return false end
	if E.forceGroup then return true end
	if IsInGroup and IsInGroup() then return true end
	return W.opt.route.groupQuests and true or false
end
E.WantsGroup = wantsGroup

local function condition(w)
	local k, r = w.k, true
	if k == "onquest" then
		r = false
		local q = w.q
		if type(q) == "table" then
			for i = 1, #q do if Q.IsOn(q[i]) then r = true break end end
		elseif q then r = Q.IsOn(q) end
	elseif k == "has" then
		r = itemCount(w.item) >= (w.n or 1)
	elseif k == "money" then
		return cmp(Readable(GetMoney and GetMoney()) or 0, w.op, w.n or 0)
	elseif k == "level" then
		return cmp(W.player.level or 1, w.op, w.n or 1)
	elseif k == "turnedin" then
		r = Q.IsDone(w.q)
	elseif k == "complete" then
		r = Q.IsReady(w.q)
	elseif k == "available" then
		r = not Q.IsDone(w.q) and not Q.IsOn(w.q) and (W.player.level or 1) >= (w.minLevel or 1)
		if r and w.closedBy then
			for i = 1, #w.closedBy do if Q.IsDone(w.closedBy[i]) then r = false break end end
		end
	elseif k == "group" then
		r = wantsGroup()
	elseif k == "dungeon" then
		r = W.opt.route.dungeons and true or false
	elseif k == "knows" then
		r = spellKnown(w.spell)
	elseif k == "bound" then
		local loc = GetBindLocation and GetBindLocation()
		r = (loc ~= nil and loc == w.name)
	elseif k == "zone" then
		local zone, sub = GetRealZoneText and GetRealZoneText(), GetSubZoneText and GetSubZoneText()
		r = (zone == w.name or sub == w.name)
	elseif k == "done" then
		r = (W.char.labels[w.label] and true or false)
	elseif k == "skill" then
		r = true    -- weapon/profession skill checks: assume the step applies
		if w.neg then return true end
	end
	if w.neg then return not r end
	return r
end

local function whenOk(step)
	local ws = step.when
	if not ws then return true end
	for i = 1, #ws do
		if not condition(ws[i]) then return false end
	end
	return true
end

local function stepApplies(step)
	if not G.OnlyOk(step.only) then return false end
	if W.opt.route.saferRoute and step.danger == "skip" then return false end
	return whenOk(step)
end

-- Goals of a step that apply to this character: cached list of { goal, originalIndex }
local function visible(step)
	local v = step._vis
	if v then return v end
	v = {}
	local goals = step.goals
	for i = 1, #goals do
		local g = goals[i]
		if G.OnlyOk(g.only) then
			g._i = i
			v[#v + 1] = g
		end
	end
	step._vis = v
	return v
end
E.Visible = visible

---------------------------------------------------------------------------
-- Goal state
--   returns done, current, needed
---------------------------------------------------------------------------
local function questSkipped(q)
	return q and W.char.skippedQuests[q] and not Q.IsOn(q) and not Q.IsDone(q)
end

local function objectiveState(g)
	local q = g.quest
	if Q.IsDone(q) or Q.IsReady(q) then return true, g.count, g.count end
	if not Q.IsOn(q) then return questSkipped(q) or false, 0, g.count end
	local objs = Q.Objectives(q)
	local o = objs and g.oi and objs[g.oi]
	if o then
		return o.finished and true or false, o.numFulfilled or 0, o.numRequired or g.count
	end
	return false, nil, nil
end

-- A quest you have but put off (Skip or Later on a step you could not finish):
-- its goals stop holding the route up until the quest is ready to hand in.
local function deferred(q)
	return q and W.char.deferred[q] and Q.IsOn(q) and not Q.IsReady(q)
end

local function goalState(g, si)
	local t = g.t
	local gi = g._i or 0
	if latched(si, gi) then return true end
	if g.quest and t ~= "accept" and deferred(g.quest) then return true end

	if t == "accept" then
		local q = g.quest
		if Q.IsOn(q) or Q.IsDone(q) then return true end
		if questSkipped(q) then return true end
		if W.opt.route.xpSkips and not g.class and Q.IsTrivial(g.qlvl) then
			W.char.skippedQuests[q] = true
			return true
		end
		return false
	elseif t == "turnin" then
		if Q.IsDone(g.quest) then return true end
		return questSkipped(g.quest) or false
	elseif t == "complete" then
		if Q.IsDone(g.quest) or Q.IsReady(g.quest) then return true end
		return questSkipped(g.quest) or false
	elseif g.quest and g.oi then
		return objectiveState(g)
	elseif g.quest and (t == "kill" or t == "collect" or t == "interact" or t == "talk" or t == "use") then
		if Q.IsDone(g.quest) or Q.IsReady(g.quest) then return true end
		if questSkipped(g.quest) then return true end
		if t == "collect" and g.item then
			local n = itemCount(g.item)
			return n >= (g.count or 1), n, g.count or 1
		end
		return false
	elseif t == "collect" or t == "buy" then
		local n = itemCount(g.item)
		return n >= (g.count or 1), n, g.count or 1
	elseif t == "level" then
		return (W.player.level or 1) >= (g.level or 1)
	elseif t == "learn" then
		return g.spell and spellKnown(g.spell) or false
	elseif t == "money" then
		return (Readable(GetMoney and GetMoney()) or 0) >= (g.money or 0)
	elseif t == "getfp" then
		return (g.location and W.char.fps[g.location]) and true or false
	elseif t == "sethome" then
		local loc = GetBindLocation and GetBindLocation()
		return (loc and g.location and loc == g.location) and true or false
	end
	return false
end

function E.GoalState(g, si)
	return goalState(g, si or E.view or E.index)
end

-- A step whose goals are all informational needs an explicit "continue".
local function onlyNotes(vis)
	for i = 1, #vis do if vis[i].t ~= "note" then return false end end
	return #vis > 0
end

local function blocks(g, vis)
	if g.optional then return false end
	if g.t == "note" then return onlyNotes(vis) end
	return true
end

local function stepComplete(si, softBefore)
	local step = E.guide.steps[si]
	local vis = visible(step)
	if #vis == 0 then return not step.note end
	for i = 1, #vis do
		local g = vis[i]
		if blocks(g, vis) and not goalState(g, si) then
			if not (softBefore and si < softBefore and SOFT[g.t]) then return false end
		end
	end
	return true
end
E.StepComplete = function(si) return stepComplete(si) end

---------------------------------------------------------------------------
-- Targets: the goal the arrow points at
---------------------------------------------------------------------------
function E.Target()
	if E.override then return E.override, E.index end
	if not E.guide then return nil end
	local si = E.view or E.index
	local step = E.guide.steps[si]
	if not step then return nil end
	local vis = visible(step)
	local fallback
	for i = 1, #vis do
		local g = vis[i]
		if g.x and g.map and not goalState(g, si) then
			if not g.optional then return g, si end
			fallback = fallback or g
		end
	end
	return fallback, si
end

---------------------------------------------------------------------------
-- Moving through the guide
---------------------------------------------------------------------------
local function skipped(si) return prog.skipped[si] end

local proximityTicker
local function updateProximity()
	local need = false
	if E.guide and E.index and not E.view then
		local vis = visible(E.guide.steps[E.index])
		for i = 1, #vis do
			local g = vis[i]
			if PROXIMITY[g.t] and g.x and not latched(E.index, g._i) then need = true break end
		end
	end
	if need and not proximityTicker and C_Timer and C_Timer.NewTicker then
		proximityTicker = C_Timer.NewTicker(0.5, function()
			if (W.InCombat() and not W.opt.combatUpdates) or not E.guide or E.view then return end
			local si = E.index
			local vis = visible(E.guide.steps[si])
			local hit = false
			for i = 1, #vis do
				local g = vis[i]
				local r = PROXIMITY[g.t]
				if r and g.x and not latched(si, g._i) then
					local d = C.GoalDistance(g)
					if d and d <= r then
						latch(si, g._i)
						hit = true
					end
					if not g.optional then break end   -- ordered: only the first required waypoint counts
				end
			end
			if hit then E.Evaluate() end
		end)
	elseif not need and proximityTicker then
		proximityTicker:Cancel()
		proximityTicker = nil
	end
end

local lastSig
local function setIndex(si, quiet)
	E.index = si
	E.view = nil
	prog.step = si
	lastSig = nil
	updateProximity()
	if not quiet then
		W.Fire("WP_STEP", si)
	end
end

local function finishGuide()
	local g = E.guide
	prog.finished = true
	W.Fire("WP_GUIDE_DONE", g)
	local nextId = g.next
	if nextId and G.Meta(nextId) then
		W.Print(L["%s complete. Next: %s."], g.title or g.id, G.Meta(nextId).title or nextId)
		E.Load(nextId)
	else
		W.Print(L["%s complete. Pick your next guide with /waypost guides."], g.title or g.id)
		setIndex(#g.steps)
	end
end

-- Find the next step at or after `from` that applies and is not complete.
-- A step the route passes over because its condition does not hold (a group
-- quest while solo, a dungeon step with dungeons off): the quests it would
-- have picked up are left out of later steps too, so a hand-in further on
-- never waits for a quest the route chose not to take. If the player picks
-- the quest up anyway, its goals count again.
-- Quests set aside to come back to: [questID] = { guide, step, title, reason, level, at }
-- reason: "later" (the player chose Later) or "group" (a group quest passed over while solo)
local function setAside(q, si, title, reason)
	local t = W.char.setAside
	if t[q] then return end
	t[q] = { guide = E.guide.id, step = si, title = title, reason = reason, level = W.player.level or 1, at = time and time() or 0 }
end

local function isGroupStep(step)
	local ws = step.when
	if not ws then return false end
	for i = 1, #ws do if ws[i].k == "group" and not ws[i].neg then return true end end
	return false
end

local function passOver(step, si)
	local goals = step.goals
	local group = isGroupStep(step) and not wantsGroup()
	for i = 1, #goals do
		local g = goals[i]
		if g.t == "accept" and g.quest and G.OnlyOk(g.only) and not Q.IsOn(g.quest) and not Q.IsDone(g.quest) then
			W.char.skippedQuests[g.quest] = true
			if group then setAside(g.quest, si, g.title, "group") end
		end
	end
end

local function seek(from, softBefore)
	local steps = E.guide.steps
	for si = from, #steps do
		local step = steps[si]
		if not skipped(si) then
			if stepApplies(step) then
				if not stepComplete(si, softBefore) then return si end
				if step.label then W.char.labels[step.label] = true end
			elseif G.OnlyOk(step.only) then
				passOver(step, si)
			end
		end
	end
	return nil
end

function E.Advance(from, softBefore)
	if not E.guide then return end
	local si = seek(from or E.index or 1, softBefore)
	if not si then return finishGuide() end
	if si ~= E.index or E.view then setIndex(si) else W.Fire("WP_PROGRESS") end
end

-- The last step that has a quest the character has already touched.
local function lastTouched()
	local steps = E.guide.steps
	for si = #steps, 1, -1 do
		local goals = steps[si].goals
		for i = 1, #goals do
			local g = goals[i]
			if g.quest and (g.t == "accept" or g.t == "turnin") and G.OnlyOk(g.only) and (Q.IsOn(g.quest) or Q.IsDone(g.quest)) then
				return si
			end
		end
	end
	return 0
end

function E.Load(id, restart)
	local guide = G.Get(id)
	if not guide then
		W.Print(L["Guide not found: %s"], tostring(id))
		return false
	end
	local previous = E.guide
	E.guide = guide
	W.char.guide = id
	local p = W.char.progress[id]
	local fresh = restart or type(p) ~= "table" or not p.step
	if fresh then
		p = { step = 1, skipped = {}, done = {}, started = time and time() or 0 }
		W.char.progress[id] = p
	end
	p.skipped = p.skipped or {}
	p.done = p.done or {}
	prog = p
	prog.finished = nil
	E.index, E.view = nil, nil
	W.Fire("WP_GUIDE", guide, previous)
	if fresh then
		E.Advance(1, lastTouched() + 1)
	else
		E.Advance(math.min(p.step, #guide.steps))
	end
	return true
end

function E.Unload()
	E.guide, E.index, E.view, prog = nil, nil, nil, nil
	W.char.guide = nil
	updateProximity()
	W.Fire("WP_GUIDE", nil)
end

-- Rescan the whole guide from the top (after doing quests without the addon).
function E.Rescan()
	if not E.guide then return end
	prog.skipped, prog.done = {}, {}
	-- forget which of this guide's quests were skipped or passed over, and decide again
	for q in pairs(E.QuestSet()) do
		W.char.skippedQuests[q] = nil
		W.char.deferred[q] = nil
		local e = W.char.setAside[q]
		if e and e.reason == "group" then W.char.setAside[q] = nil end
	end
	E.Advance(1, lastTouched() + 1)
end

-- A compact fingerprint of the current step's goal states, so the UI is only
-- told to redraw when something actually changed (QUEST_LOG_UPDATE is chatty).
local sigParts = {}
local function signature()
	local si = E.index
	local vis = visible(E.guide.steps[si])
	local n = 1
	sigParts[1] = si
	for i = 1, #vis do
		local done, cur = goalState(vis[i], si)
		n = n + 1
		sigParts[n] = done and "x" or (cur or "-")
	end
	for i = n + 1, #sigParts do sigParts[i] = nil end
	return table.concat(sigParts, ",")
end

local evaluating = false
local function evaluate()
	if W.opt.route.autoAdvance and stepComplete(E.index) then
		local step = E.guide.steps[E.index]
		if step.label then W.char.labels[step.label] = true end
		W.Fire("WP_STEP_DONE", E.index, step)
		lastSig = nil
		E.Advance(E.index + 1)
	else
		updateProximity()
		local sig = signature()
		if sig ~= lastSig then
			lastSig = sig
			W.Fire("WP_PROGRESS")
		end
	end
end

function E.Evaluate()
	if not E.guide or not E.index or evaluating then return end
	if prog.finished then return end
	evaluating = true
	local ok, err = pcall(evaluate)
	evaluating = false
	if not ok then
		W.lastError = err
		if W.debug then geterrorhandler()(err) end
	end
end

-- Quiet in combat: progress is re-read once when combat ends.
local evaluateDebounced = W.Debounce(0.15, function() E.Evaluate() end)
local function evaluateSoon()
	if W.InCombat() and not W.opt.combatUpdates then return end
	evaluateDebounced()
end
E.EvaluateSoon = evaluateSoon

---------------------------------------------------------------------------
-- Skip, back, look ahead, undo
---------------------------------------------------------------------------
local function pushUndo(entry)
	local u = W.char.undo
	u[#u + 1] = entry
	if #u > 20 then table.remove(u, 1) end
end

-- Skip the current step. Every quest it needs that you do not have is left out
-- of later steps too. With `later`, those quests are also set aside, to be
-- offered back when you join a party or gain a couple of levels.
local function skipStep(later)
	if not E.guide or not E.index then return end
	if E.view then E.view = nil end
	local si = E.index
	local quests = {}
	local vis = visible(E.guide.steps[si])
	for i = 1, #vis do
		local g = vis[i]
		local q = g.quest
		if q and not Q.IsDone(q) then
			if not Q.IsOn(q) then
				-- you do not have it: leave it out of later steps
				if not W.char.skippedQuests[q] then
					W.char.skippedQuests[q] = true
					quests[#quests + 1] = q
				end
				if later then setAside(q, si, g.title or Q.Title(q), g.group and "group" or "later") end
			elseif not Q.IsReady(q) and g.t ~= "accept" and not goalState(g, si) then
				-- you have it but cannot finish it now: stop its goals holding the route up
				if not W.char.deferred[q] then
					W.char.deferred[q] = true
					quests[#quests + 1] = q
				end
				if later then setAside(q, si, g.title or Q.Title(q), g.group and "group" or "later") end
			end
		end
	end
	prog.skipped[si] = true
	pushUndo({ guide = E.guide.id, step = si, quests = quests })
	E.Advance(si + 1)
	if later then W.Fire("WP_SET_ASIDE") end
end

function E.Skip() skipStep(false) end
function E.Later() skipStep(true) end

-- Go back to a quest that was set aside: its step becomes the current one again.
function E.ReturnTo(q)
	local entry = W.char.setAside[q]
	if not entry then return false end
	if not E.guide or E.guide.id ~= entry.guide then
		if not E.Load(entry.guide) then return false end
	end
	local si = entry.step
	-- everything set aside at that step comes back together
	for id, e in pairs(W.char.setAside) do
		if e.guide == entry.guide and e.step == si then
			W.char.setAside[id] = nil
			W.char.skippedQuests[id] = nil
			W.char.deferred[id] = nil
		end
	end
	if entry.reason == "group" then E.forceGroup = true end
	if E.guide.steps[si] then
		prog.skipped[si] = nil
		E.JumpTo(si)
	end
	W.Fire("WP_SET_ASIDE")
	return true
end

-- Forget a set-aside quest (it stays out of the route).
function E.Forget(q)
	W.char.setAside[q] = nil
	W.Fire("WP_SET_ASIDE")
end

-- Set-aside quests that are still worth offering (not picked up or finished since).
function E.SetAsideList()
	local out = {}
	for q, e in pairs(W.char.setAside) do
		if Q.IsDone(q) or (Q.IsOn(q) and not W.char.deferred[q]) or not G.Meta(e.guide) then
			W.char.setAside[q] = nil
			W.char.deferred[q] = nil
		else
			out[#out + 1] = { quest = q, title = e.title or Q.Title(q) or (L["Quest"] .. " " .. q), reason = e.reason,
				guide = e.guide, step = e.step, level = e.level, offered = e.offered }
		end
	end
	table.sort(out, function(a, b)
		if a.guide ~= b.guide then return a.guide < b.guide end
		if a.step ~= b.step then return a.step < b.step end
		return a.quest < b.quest
	end)
	return out
end

-- Somewhere to make up experience: the nearest enemies the route itself sends
-- you to that are about your level. Returns a goal for the arrow, or nil.
function E.GrindSpot()
	if not E.guide or not E.index then return nil end
	local level = W.player.level or 1
	local steps = E.guide.steps
	local best, bestScore
	for si = math.max(1, E.index - 40), math.min(#steps, E.index + 15) do
		local step = steps[si]
		if G.OnlyOk(step.only) then
			for _, g in ipairs(step.goals) do
				if g.t == "kill" and g.x and g.map and G.OnlyOk(g.only) and not g.group then
					local ml = g.mobLevel or level
					if ml >= level - 3 and ml <= level + 1 then
						local d = C.GoalDistance(g)
						if d then
							local score = d + math.abs(ml - level) * 150
							if not bestScore or score < bestScore then best, bestScore = g, score end
						end
					end
				end
			end
		end
	end
	if not best then return nil end
	return { t = "goto", map = best.map, x = best.x, y = best.y, era = best.era, spots = best.spots,
		text = best.target or best.npc or L["enemies"], mobLevel = best.mobLevel }
end

function E.UndoSkip()
	local u = W.char.undo
	local entry = u[#u]
	if not entry then
		W.Print(L["Nothing to undo."])
		return false
	end
	u[#u] = nil
	if not E.guide or E.guide.id ~= entry.guide then
		if not E.Load(entry.guide) then return false end
	end
	prog.skipped[entry.step] = nil
	for _, q in ipairs(entry.quests or {}) do
		W.char.skippedQuests[q] = nil
		W.char.deferred[q] = nil
		W.char.setAside[q] = nil
	end
	setIndex(entry.step)
	return true
end

-- Next: confirm the current step by hand (ticks manual goals) or leave a preview forward.
function E.Next()
	if not E.guide or not E.index then return end
	if E.view then return E.Look(1) end
	local si = E.index
	local vis = visible(E.guide.steps[si])
	local allSoft = true
	for i = 1, #vis do
		local g = vis[i]
		if blocks(g, vis) and not goalState(g, si) and not (SOFT[g.t] or (not g.quest)) then allSoft = false break end
	end
	if allSoft then
		for i = 1, #vis do latch(si, vis[i]._i) end
		local step = E.guide.steps[si]
		if step.label then W.char.labels[step.label] = true end
		W.Fire("WP_STEP_DONE", si, step)
		E.Advance(si + 1)
	else
		E.Skip()
	end
end

-- Look ahead / back without losing place. delta = +1 / -1; 0 returns to the current step.
function E.Look(delta)
	if not E.guide or not E.index then return end
	if delta == 0 then
		E.view = nil
	else
		local steps = E.guide.steps
		local si = (E.view or E.index) + delta
		while steps[si] and not G.OnlyOk(steps[si].only) do si = si + delta end
		if not steps[si] then return end
		E.view = (si ~= E.index) and si or nil
	end
	updateProximity()
	W.Fire("WP_STEP", E.view or E.index)
end

-- Back: un-skip the previous skipped step, otherwise just look at it.
function E.Back()
	if not E.guide or not E.index then return end
	local si = (E.view or E.index) - 1
	local steps = E.guide.steps
	while steps[si] and not G.OnlyOk(steps[si].only) do si = si - 1 end
	if not steps[si] then return end
	if prog.skipped[si] and not E.view then
		prog.skipped[si] = nil
		setIndex(si)
	else
		E.Look(-1)
	end
end

-- Make the viewed (or given) step the current one.
function E.JumpTo(si)
	if not E.guide or not E.guide.steps[si] then return end
	pushUndo({ guide = E.guide.id, step = E.index, quests = {} })
	prog.skipped[si] = nil
	setIndex(si)
end

-- Tick a goal by hand (click in the step frame).
function E.ToggleGoal(g)
	if not E.guide or not E.index or E.view then return end
	local k = key(E.index, g._i)
	if prog.done[k] then prog.done[k] = nil else prog.done[k] = true end
	E.Evaluate()
end

function E.IsSkipped(si) return prog and prog.skipped[si] and true or false end
function E.Applies(si) return E.guide and E.guide.steps[si] and stepApplies(E.guide.steps[si]) or false end

---------------------------------------------------------------------------
-- Display text
---------------------------------------------------------------------------
local GOLD, WHITE, GREY = "|cffffd100", "|cffffffff", "|cff9d9d9d"
local NPC, ENEMY, PLACE = "|cff8fe68f", "|cffff856b", "|cffffe69e"
local GOOD, WARN = "|cff4df259", "|cffff9933"

local function questName(g)
	return g.title or Q.Title(g.quest) or (L["Quest"] .. " " .. tostring(g.quest))
end

-- An item's name in its quality colour (white until the client has the item cached).
local function itemText(g)
	local name = g.itemName or ("item " .. tostring(g.item))
	local hex
	if g.item and C_Item and C_Item.GetItemQualityByID and ITEM_QUALITY_COLORS then
		local q = C_Item.GetItemQualityByID(g.item)
		local c = q and ITEM_QUALITY_COLORS[q]
		if c and c.hex then hex = c.hex end
	end
	return (hex or WHITE) .. name .. "|r"
end

local function counted(text, cur, need)
	if need and need > 1 or (need and cur and cur < need and need > 0) then
		return ("%s %s%d/%d|r"):format(text, WHITE, cur or 0, need)
	end
	return text
end

-- The main line for a goal, and one secondary line (who, or the route's note).
function E.GoalText(g, si)
	local t = g.t
	local _, cur, need = goalState(g, si or E.view or E.index)
	need = need or g.count
	local main
	if t == "accept" then
		main = L["Accept"] .. " " .. GOLD .. questName(g) .. "|r"
	elseif t == "turnin" then
		main = L["Turn in"] .. " " .. GOLD .. questName(g) .. "|r"
	elseif t == "complete" then
		main = L["Complete"] .. " " .. GOLD .. questName(g) .. "|r"
		if g.objs and g.objs[1] then main = main .. GREY .. ": " .. table.concat(g.objs, ", ") .. "|r" end
	elseif t == "kill" then
		main = counted(L["Kill"] .. " " .. ENEMY .. (g.target or g.npc or "?") .. "|r", cur, need)
	elseif t == "collect" then
		main = counted(L["Collect"] .. " " .. itemText(g), cur, need)
	elseif t == "buy" then
		main = counted(L["Buy"] .. " " .. itemText(g), cur, need)
	elseif t == "use" then
		main = L["Use"] .. " " .. itemText(g)
	elseif t == "interact" then
		main = L["Interact with"] .. " " .. PLACE .. (g.npc or g.text or "?") .. "|r"
	elseif t == "talk" then
		main = L["Talk to"] .. " " .. NPC .. (g.npc or "?") .. "|r"
	elseif t == "goto" then
		main = L["Go to"] .. " " .. PLACE .. (g.text or g.location or (g.x and C.Format(g.x, g.y)) or "?") .. "|r"
	elseif t == "enter" then
		main = L["Enter"] .. " " .. PLACE .. (g.location or g.text or "?") .. "|r"
	elseif t == "explore" then
		main = L["Explore"] .. " " .. PLACE .. (g.text or g.location or "?") .. "|r"
	elseif t == "level" then
		main = (L["Reach level %d"]):format(g.level or 1)
	elseif t == "train" then
		main = g.class and L["Visit your class trainer"] or (g.text or L["Train"])
	elseif t == "fly" then
		main = L["Fly to"] .. " " .. PLACE .. (g.location or "?") .. "|r"
	elseif t == "getfp" then
		main = L["Get the flight path"] .. ": " .. PLACE .. (g.location or "?") .. "|r"
	elseif t == "sethome" then
		main = L["Set your hearthstone"] .. ": " .. PLACE .. (g.location or "?") .. "|r"
	elseif t == "hearth" then
		main = L["Use your hearthstone"]
	elseif t == "vendor" then
		main = L["Sell junk and repair"]
	elseif t == "learn" then
		main = L["Learn"] .. " " .. WHITE .. (g.spellName or "?") .. "|r"
	elseif t == "skill" then
		main = (g.skillName or L["Skill"]) .. (g.skillRank and (" " .. g.skillRank) or "")
	elseif t == "rep" then
		main = (g.factionName or L["Reputation"]) .. (g.standing and (": " .. tostring(g.standing)) or "")
	elseif t == "money" then
		main = L["Have"] .. " " .. (GetCoinTextureString and GetCoinTextureString(g.money or 0) or tostring(g.money))
	elseif t == "die" then
		main = L["Die on purpose and resurrect at the spirit healer"] .. (g.location and (" (" .. g.location .. ")") or "")
	else
		main = g.text or g.title or t
	end
	if g.optional then main = main .. " " .. GREY .. "(" .. L["optional"] .. ")|r" end

	local sub
	if t == "note" then
		sub = nil
	elseif g.note then
		sub = g.note
	elseif g.npc and (t == "accept" or t == "turnin" or t == "buy" or t == "getfp" or t == "sethome") then
		sub = NPC .. g.npc .. "|r"
	end
	return main, sub
end

-- Everything else worth knowing about a goal, as short lines: who gives or
-- takes the quest, where an item drops, how tough the enemy is, and what is
-- holding the goal up if the game has not confirmed it.
function E.GoalInfo(g, si, out)
	out = out or {}
	for i = #out, 1, -1 do out[i] = nil end
	local t = g.t
	local function add(s) out[#out + 1] = s end
	if t == "accept" then
		if g.npc then add(L["From"] .. " " .. NPC .. g.npc .. "|r") end
		if g.startItemName then add(L["Starts from the item"] .. " " .. WHITE .. g.startItemName .. "|r") end
		local tags = {}
		if g.qlvl and g.qlvl > 0 then tags[#tags + 1] = (L["Level %d quest"]):format(g.qlvl) end
		if g.group then tags[#tags + 1] = WARN .. L["group quest"] .. "|r" end
		if g.escort then tags[#tags + 1] = WARN .. L["escort"] .. "|r" end
		if #tags > 0 then add(table.concat(tags, "  ")) end
	elseif t == "turnin" then
		if g.npc then add(L["To"] .. " " .. NPC .. g.npc .. "|r") end
		if Q.IsReady(g.quest) then
			add(GOOD .. L["Ready to hand in"] .. "|r")
		elseif Q.IsOn(g.quest) then
			add(WARN .. L["Its objectives are not finished yet"] .. "|r")
		elseif not Q.IsDone(g.quest) then
			add(WARN .. L["This quest is not in your log"] .. "|r")
		end
	elseif t == "kill" then
		if g.mobLevel then add((L["Level %d enemy"]):format(g.mobLevel)) end
	elseif t == "collect" then
		if g.src then
			add((g.srcKind == "object" and L["Loot"] or L["Drops from"]) .. " " .. (g.srcKind == "object" and PLACE or ENEMY) .. g.src .. "|r")
		end
		if g.mobLevel then add((L["Level %d enemy"]):format(g.mobLevel)) end
	elseif t == "level" then
		local level = W.player.level or 1
		if level < (g.level or 1) then
			local cur, max = Readable(UnitXP and UnitXP("player")), Readable(UnitXPMax and UnitXPMax("player"))
			if type(cur) == "number" and type(max) == "number" and max > 0 then
				add((L["You are level %d: %s XP to level %d"]):format(level, W.FormatNumber(max - cur), level + 1))
			end
			if (g.level or 1) - level > 1 then add((L["%d levels to go"]):format((g.level or 1) - level)) end
			local ttl = W.XP and W.XP.TimeToLevel()
			if ttl then add((L["About %s at your current pace"]):format(W.FormatTime(ttl))) end
			local rested = GetXPExhaustion and Readable(GetXPExhaustion())
			if type(rested) == "number" and rested > 0 then
				add(GOOD .. (L["Rested: the next %s XP from kills counts double"]):format(W.FormatNumber(rested)) .. "|r")
			end
			add(L["The next quests need this level. Make it up with the options below."])
		end
	elseif t == "fly" then
		if g.location and next(W.char.fps) and not W.char.fps[g.location] then
			add(WARN .. L["You have not learned this flight path yet: travel on foot."] .. "|r")
		end
	elseif (t == "talk" or t == "buy" or t == "getfp" or t == "sethome") and g.npc and t ~= "talk" then
		add(L["At"] .. " " .. NPC .. g.npc .. "|r")
	end
	if g.quest and t ~= "accept" and t ~= "turnin" and t ~= "complete" then
		add(L["For"] .. " " .. GOLD .. questName(g) .. "|r")
	end
	if g.quest and (t == "accept" or t == "kill" or t == "collect" or t == "interact" or t == "talk" or t == "use")
		and not Q.IsOn(g.quest) and not Q.IsDone(g.quest) and t ~= "accept" then
		add(WARN .. L["You are not on this quest"] .. "|r")
	end
	if g.note then add(g.note) end
	if t == "note" and g.text then add(g.text) end
	return out
end

-- The goal to act on now: the first one in the step that is not done.
function E.Current(si)
	if not E.guide then return nil end
	si = si or E.view or E.index
	local step = E.guide.steps[si]
	if not step then return nil end
	local vis = visible(step)
	local fallback
	for i = 1, #vis do
		local g = vis[i]
		if g.t ~= "note" and not goalState(g, si) then
			if not g.optional then return g end
			fallback = fallback or g
		end
	end
	return fallback
end

-- Danger line for a step: explicit text, group/elite quests, or enemies well above the character.
function E.Danger(step)
	if type(step.danger) == "string" and step.danger ~= "skip" then return step.danger end
	local vis = visible(step)
	local level = W.player.level or 1
	local worst = 0
	local group, escort = false, false
	for i = 1, #vis do
		local g = vis[i]
		if g.group then group = true end
		if g.escort then escort = true end
		if g.mobLevel and g.mobLevel - level > worst then worst = g.mobLevel - level end
	end
	if group then return L["Group quest: elite enemies. Bring help or skip it."] end
	if worst >= 3 then return (L["Enemies here are %d levels above you. Pull carefully."]):format(worst) end
	if escort then return L["Escort quest: clear the path first and keep the NPC alive."] end
	return nil
end

-- "Why this step": the step's own explanation, or one worked out from the route.
function E.Why(si)
	if not E.guide then return nil end
	si = si or E.view or E.index
	local step = E.guide.steps[si]
	if not step then return nil end
	if step.why then return step.why end
	local vis = visible(step)
	local accepts, turnins, work = 0, 0, 0
	local farthest = 0
	for i = 1, #vis do
		local g = vis[i]
		if g.t == "accept" then
			accepts = accepts + 1
			for sj = si, math.min(#E.guide.steps, si + 60) do
				local goals = E.guide.steps[sj].goals
				for j = 1, #goals do
					if goals[j].t == "turnin" and goals[j].quest == g.quest and sj - si > farthest then farthest = sj - si end
				end
			end
		elseif g.t == "turnin" then turnins = turnins + 1
		elseif g.quest then work = work + 1 end
	end
	local parts = {}
	if accepts > 0 and turnins > 0 then
		parts[#parts + 1] = (L["You hand in %d quest(s) and pick up %d more at the same stop, so no trip is wasted."]):format(turnins, accepts)
	elseif accepts > 1 then
		parts[#parts + 1] = (L["Picking up %d quests together lets you work on them in one loop."]):format(accepts)
	elseif accepts == 1 then
		parts[#parts + 1] = L["This quest is picked up now because its objectives are on the way."]
	elseif turnins > 0 then
		parts[#parts + 1] = (L["Handing in %d quest(s) here while you pass by."]):format(turnins)
	end
	if farthest > 0 then
		parts[#parts + 1] = (L["They are finished within the next %d steps."]):format(farthest)
	end
	if work > 1 then
		parts[#parts + 1] = (L["%d objectives overlap in this area, so they are done in one pass."]):format(work)
	end
	if #parts == 0 then
		local t = vis[1] and vis[1].t
		if t == "train" then parts[1] = L["Training now keeps your damage up for the next zone."]
		elseif t == "fly" or t == "getfp" then parts[1] = L["Flight paths save long walks later in the route."]
		elseif t == "sethome" then parts[1] = L["Binding here lets a later hearthstone skip the walk back."]
		elseif t == "level" then parts[1] = L["The next quests need this level."]
		else parts[1] = L["This is the shortest path to the next objective."] end
	end
	return table.concat(parts, " ")
end

-- A temporary waypoint that takes over the arrow (nearest trainer, a party member's spot).
function E.SetOverride(goal)
	E.override = goal
	W.Fire("WP_PROGRESS")
end

-- Quest IDs the active guide uses (for automation and orphan detection).
local questSet, questSetFor
function E.QuestSet()
	if not E.guide then return {} end
	if questSetFor ~= E.guide.id then
		questSet, questSetFor = {}, E.guide.id
		for _, step in ipairs(E.guide.steps) do
			if G.OnlyOk(step.only) then
				for _, g in ipairs(step.goals) do
					if g.quest and G.OnlyOk(g.only) then questSet[g.quest] = true end
				end
			end
		end
	end
	return questSet
end

function E.Summary()
	if not E.guide or not E.index then return nil end
	local step = E.guide.steps[E.index]
	return E.guide.id, E.index, #E.guide.steps, step and step.title or ""
end

function E.Progress()
	if not E.guide or not E.index then return 0 end
	return (E.index - 1) / math.max(1, #E.guide.steps)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
W.On("QUEST_TURNED_IN", function(q)
	if q then turnedIn[q] = true end
	evaluateSoon()
end)
for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_MONEY",
	"ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "SPELLS_CHANGED", "WP_COMBAT_ENDED", "GROUP_ROSTER_UPDATE" }) do
	W.On(ev, evaluateSoon)
end
W.On("WP_LEVEL", evaluateSoon)
W.On("UNIT_QUEST_LOG_CHANGED", function(unit) if unit == "player" then evaluateSoon() end end)

W.On("HEARTHSTONE_BOUND", function()
	if E.guide and E.index then
		local vis = visible(E.guide.steps[E.index])
		for i = 1, #vis do if vis[i].t == "sethome" then latch(E.index, vis[i]._i) end end
	end
	evaluateSoon()
end)

-- Manual-type goals that complete when their window closes.
local function latchType(t)
	if not (E.guide and E.index) or E.view then return end
	local vis = visible(E.guide.steps[E.index])
	local hit
	for i = 1, #vis do
		if vis[i].t == t and not latched(E.index, vis[i]._i) then latch(E.index, vis[i]._i); hit = true end
	end
	if hit then evaluateSoon() end
end
E.LatchType = latchType
W.On("TRAINER_CLOSED", function() latchType("train") end)
W.On("MERCHANT_CLOSED", function() latchType("vendor") end)
W.On("PLAYER_DEAD", function() latchType("die") end)

W.On("WP_SETTINGS", function(path)
	if path == "*" or (type(path) == "string" and path:find("^route")) then
		if E.guide then
			for _, s in ipairs(E.guide.steps) do s._vis = nil end
			evaluateSoon()
		end
	end
end)

W.On("WP_GUIDE", function() questSetFor = nil end)

W.On("WP_READY", function()
	local id = W.char.guide
	if id and G.Meta(id) then
		E.Load(id)
	end
	E.ready = true
	W.Fire("WP_ENGINE_READY")
end)

E.MANUAL, E.SOFT = MANUAL, SOFT
