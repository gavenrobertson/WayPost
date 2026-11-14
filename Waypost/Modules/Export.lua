-- Progress export for dragonwarriors.app.
-- Addons cannot reach the web, so progress is written into SavedVariables
-- (WaypostDB.export) and a small companion script (companion/uploader.py)
-- reads that file and uploads it. Nothing leaves the game on its own.

local W = Waypost
local E = W.Engine
local X = {}
W.Export = X

function X.Update()
	if not (W.db and W.char) then return end
	local p = W.player
	if not p.name then return end
	local id, si, total, title = E.Summary()
	local meta = id and W.Guides.Meta(id)
	local x = W.char.xp or {}
	local runs = {}
	for i = math.max(1, #(x.runs or {}) - 19), #(x.runs or {}) do
		local r = x.runs[i]
		runs[#runs + 1] = { guide = r.guide, title = r.title, seconds = r.seconds, finished = r.finished, level = r.level }
	end
	local guild = IsInGuild and IsInGuild() and W.Readable(GetGuildInfo("player")) or nil
	W.db.export.schema = 1
	W.db.export.addon = W.version
	W.db.export.updated = time()
	W.db.export.characters[W.CharKey()] = {
		name = p.name, realm = p.realm, class = p.class, race = p.race, faction = p.faction, level = p.level,
		guild = guild,
		guide = id, guideTitle = meta and meta.title or nil, step = si, steps = total, stepTitle = title,
		xpPerHour = W.XP and math.floor(W.XP.Rate()) or 0,
		levelSeconds = x.levels or {},
		guideSeconds = x.guides or {},
		runs = runs,
		played = x.played or 0,
		updated = time(),
	}
end

W.On("PLAYER_LOGOUT", X.Update)
W.On("WP_LEVEL", function() W.After(1, X.Update) end)
W.On("WP_GUIDE_DONE", function() W.After(1, X.Update) end)
