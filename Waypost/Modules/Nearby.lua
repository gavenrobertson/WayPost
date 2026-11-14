-- "Take me to the nearest ...": class trainer, vendor, flight master, innkeeper.
-- Trainers come from Data/Trainers.lua; the rest are the stops your guide
-- itself uses, so no extra database is carried.

local W = Waypost
local L = W.L
local E, C = W.Engine, W.Coords
local N = {}
W.Nearby = N

local trainers = {}
function W.RegisterTrainers(t) trainers = t end

-- Keep only trainers this character can use.
W.On("WP_LOGIN", function()
	local p = W.player
	if not p.class then return end
	local f = p.faction == "Alliance" and "A" or "H"
	local keep = {}
	for id, t in pairs(trainers) do
		if W.Contains(t.classes, p.class) and (t.faction or "AH"):find(f, 1, true) then keep[id] = t end
	end
	trainers = keep
end)

local KIND_GOALS = {
	vendor = { vendor = true, buy = true },
	flight = { getfp = true },
	inn = { sethome = true },
}
local LABEL = { trainer = "class trainer", vendor = "vendor", flight = "flight master", inn = "innkeeper" }

local function candidates(kind)
	local out = {}
	if kind == "trainer" then
		local p = W.player
		local f = p.faction == "Alliance" and "A" or "H"
		for _, t in pairs(trainers) do
			if W.Contains(t.classes, p.class) and (t.faction or "AH"):find(f, 1, true) then
				out[#out + 1] = { t = "goto", map = t.map, x = t.x, y = t.y, era = t.era, text = t.name, npc = t.name }
			end
		end
	elseif E.guide and KIND_GOALS[kind] then
		for _, s in ipairs(E.guide.steps) do
			for _, g in ipairs(s.goals) do
				if KIND_GOALS[kind][g.t] and g.x and g.map then
					out[#out + 1] = { t = "goto", map = g.map, x = g.x, y = g.y, era = g.era, text = g.npc or g.location or LABEL[kind], npc = g.npc }
				end
			end
		end
	end
	return out
end

function N.Go(kind)
	if not LABEL[kind] then
		return W.Print(L["Usage: /waypost nearest trainer | vendor | flight | inn"])
	end
	local best, bestDist
	for _, g in ipairs(candidates(kind)) do
		local d = C.GoalDistance(g)
		if d and (not bestDist or d < bestDist) then best, bestDist = g, d end
	end
	if not best then
		return W.Print((L["No %s known near you on this continent."]):format(L[LABEL[kind]]))
	end
	W.Print((L["Nearest %s: %s, %d yd. The arrow points there; /waypost resume returns to your step."]):format(L[LABEL[kind]], best.text or "?", bestDist))
	E.SetOverride(best)
	-- Give the arrow back to the guide on arrival.
	local ticker
	ticker = C_Timer.NewTicker(1, function()
		if E.override ~= best then ticker:Cancel() return end
		local d = C.GoalDistance(best)
		if d and d < 8 then
			ticker:Cancel()
			E.SetOverride(nil)
		end
	end)
end

function N.Resume() E.SetOverride(nil) end
