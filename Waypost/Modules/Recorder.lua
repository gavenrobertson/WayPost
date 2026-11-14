-- Route recorder: play normally and get a draft guide.
--   /waypost record start    begin (survives /reload and logout)
--   /waypost record stop     stop and open the draft in the editor
-- It listens to a handful of quest and travel events; no combat log.

local W = Waypost
local L = W.L
local C, Q = W.Coords, W.Quest
local R = {}
W.Recorder = R

local rec           -- W.db.recordings.active
local objState = {} -- [questID] = { [i] = finished }

local function where()
	local map, x, y = C.PlayerMapPos()
	if not map then return "" end
	return (" @%.1f,%.1f,%d"):format(x, y, map)
end

local function place()
	local sub = GetSubZoneText and GetSubZoneText()
	local zone = GetRealZoneText and GetRealZoneText()
	if sub and sub ~= "" then return sub end
	return zone or "Step"
end

local function add(line)
	if not rec then return end
	local here = place()
	if rec.place ~= here or rec.fresh then
		rec.lines[#rec.lines + 1] = ""
		rec.lines[#rec.lines + 1] = "step " .. here
		rec.place, rec.fresh = here, false
	end
	rec.lines[#rec.lines + 1] = "  " .. line
end

local function npcName()
	local n = W.Readable(UnitName("npc")) or W.Readable(UnitName("target"))
	return n and (" -- " .. n) or ""
end

local function snapshot(q)
	local objs = Q.Objectives(q)
	local t = {}
	if objs then for i, o in ipairs(objs) do t[i] = o.finished and true or false end end
	objState[q] = t
end

function R.Active() return rec ~= nil end

function R.Start()
	if rec then return W.Print(L["Already recording. /waypost record stop to finish."]) end
	local p = W.player
	rec = { started = time(), lines = {}, fresh = true, minLevel = p.level, faction = p.faction, race = p.race }
	W.db.recordings.active = rec
	for _, q in ipairs(Q.Log()) do snapshot(q.id) end
	W.Print(L["Recording your route. Play normally, then type /waypost record stop."])
end

function R.Text()
	if not rec then return nil end
	local p = W.player
	local head = {
		"title " .. (GetRealZoneText and GetRealZoneText() or "My route") .. " (recorded)",
		"faction " .. (rec.faction or p.faction or "Alliance"),
		("levels %d-%d"):format(rec.minLevel or 1, math.max(rec.minLevel or 1, p.level or 1)),
		"# Recorded with Waypost. Tidy the step titles and add tips, then Save.",
	}
	return table.concat(head, "\n") .. "\n" .. table.concat(rec.lines, "\n") .. "\n"
end

function R.Stop()
	if not rec then return W.Print(L["Not recording."]) end
	local text = R.Text()
	local count = #rec.lines
	rec = nil
	W.db.recordings.active = nil
	W.db.recordings.last = text
	if count == 0 then return W.Print(L["Nothing was recorded."]) end
	W.Print(L["Recording stopped. Your draft is in the editor."])
	W.Editor.Open(nil, text)
end

W.On("WP_LOGIN", function()
	local a = W.db.recordings.active
	if type(a) == "table" and type(a.lines) == "table" then
		rec = a
		rec.fresh = true
		for _, q in ipairs(Q.Log()) do snapshot(q.id) end
		W.After(4, function() W.Print(L["Still recording your route. /waypost record stop to finish."]) end)
	end
end)

W.On("QUEST_ACCEPTED", function(q)
	if not rec or not q then return end
	W.After(0.3, function()
		if not rec then return end
		add(("accept %d %s%s%s"):format(q, Q.Title(q) or "", where(), npcName()))
		snapshot(q)
	end)
end)

W.On("QUEST_TURNED_IN", function(q)
	if not rec or not q then return end
	add(("turnin %d %s%s%s"):format(q, Q.Title(q) or "", where(), npcName()))
	objState[q] = nil
end)

local scan = W.Debounce(0.5, function()
	if not rec then return end
	for _, q in ipairs(Q.Log()) do
		local objs = Q.Objectives(q.id)
		local old = objState[q.id]
		if objs and old then
			for i, o in ipairs(objs) do
				if o.finished and not old[i] then
					local text = (o.text or ""):gsub("%s*:?%s*%d+/%d+%s*", " "):gsub("^%s+", ""):gsub("%s+$", "")
					local n = o.numRequired or 1
					if o.type == "monster" then
						add(("kill %d %s quest %d obj %d%s"):format(n, text ~= "" and text or "?", q.id, i, where()))
					elseif o.type == "item" then
						add(("note Collect %d %s (quest %d, objective %d)%s"):format(n, text, q.id, i, where()))
					else
						add(("note %s (quest %d, objective %d)%s"):format(text ~= "" and text or "Objective", q.id, i, where()))
					end
				end
			end
		end
		snapshot(q.id)
	end
end)
W.On("QUEST_LOG_UPDATE", function() if rec and not W.InCombat() then scan() end end)
W.On("WP_COMBAT_ENDED", function() if rec then scan() end end)

W.On("WP_LEVEL", function(level) if rec then add("level " .. level) end end)
W.On("HEARTHSTONE_BOUND", function() if rec then add("sethome " .. (GetBindLocation and GetBindLocation() or place()) .. where() .. npcName()) end end)
W.On("TAXIMAP_OPENED", function()
	if not rec or not (NumTaxiNodes and TaxiNodeGetType) then return end
	for i = 1, NumTaxiNodes() do
		if TaxiNodeGetType(i) == "CURRENT" then
			local name = (TaxiNodeName(i) or ""):match("^(.-),%s") or TaxiNodeName(i)
			if name and rec.lastFp ~= name then
				rec.lastFp = name
				add("getfp " .. name .. where() .. npcName())
			end
		end
	end
end)
if hooksecurefunc and TakeTaxiNode then
	hooksecurefunc("TakeTaxiNode", function(slot)
		if not rec or not TaxiNodeName then return end
		local name = (TaxiNodeName(slot) or ""):match("^(.-),%s") or TaxiNodeName(slot)
		if name then add("fly " .. name) end
	end)
end
