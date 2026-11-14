-- Saved settings and progress.
--
-- WaypostDB       account-wide: profiles, custom guides, recordings, guild board, export
-- WaypostCharDB   per character: active guide, step progress, timers, flight points
-- WaypostBackup   a copy of both written at logout; restored if a file comes back
--                 broken (Forever's beta has lost SavedVariables before)

local W = Waypost
local L = W.L

local DB_VERSION = 1

W.defaults = {
	ui = {
		skin = "panel",          -- panel | glass | bare
		scale = 1.0,
		alpha = 1.0,
		font = "game",
		fontSize = 12,
		locked = false,
		compact = false,
		showNext = 3,
		listOpen = false,
		width = 320,
		showDone = false,
		gameMenu = true,
		hideInCombat = false,
		fadeOutOfCombat = false,
		hidden = false,
	},
	arrow = {
		enabled = true,
		scale = 1.0,
		alpha = 1.0,
		color = "gold",          -- gold | distance
		colorblind = false,
		showDistance = true,
		showETA = true,
		tomtom = false,
		locked = false,
		arriveSound = true,
	},
	map = { world = true, minimap = true, spots = true, upcoming = true },
	auto = {
		accept = true,
		turnin = true,
		gossip = true,
		flight = true,
		singleReward = true,
		pauseOnChoice = true,
	},
	route = {
		autoAdvance = true,
		xpSkips = false,
		saferRoute = false,
		hideOptional = false,
		dungeons = false,
		groupQuests = false,
	},
	buttons = { item = true, target = true, mark = true },
	group = { sync = true, chat = false },
	guild = { board = true, banner = true },
	talents = { enabled = true, build = "" },
	upgrades = { enabled = true, pawn = true },
	minimap = { hide = false, angle = 205 },
	sound = true,
	combatUpdates = true,    -- objectives tick off the moment they happen, in combat too
}

W.charDefaults = {
	guide = nil,
	progress = {},           -- [guideId] = { step = n, skipped = { [i] = true }, manual = { ["i:j"] = true } }
	undo = {},
	skippedQuests = {},
	fps = {},                -- known flight points by name
	labels = {},
	xp = { levels = {}, guides = {}, runs = {}, played = 0, levelStart = nil },
	profile = nil,
	seenWelcome = false,
}

local function merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			merge(dst[k], v)
		elseif dst[k] == nil or type(dst[k]) ~= type(v) then
			dst[k] = v
		end
	end
	return dst
end
W.MergeDefaults = merge

local function valid(t) return type(t) == "table" end

local function charKey()
	local p = W.player
	return (p.name or "?") .. "-" .. (p.realm or "?")
end
W.CharKey = charKey

W.On("WP_INIT", function()
	local restored = false
	if not valid(WaypostDB) or (WaypostDB.version and WaypostDB.version > DB_VERSION) then
		if valid(WaypostBackup) and valid(WaypostBackup.db) then
			WaypostDB = W.CopyTable(WaypostBackup.db)
			restored = true
		else
			WaypostDB = {}
		end
	end
	if not valid(WaypostCharDB) or not valid(WaypostCharDB.progress) then
		local bk = valid(WaypostBackup) and valid(WaypostBackup.chars) and WaypostBackup.chars[charKey()]
		if valid(bk) then
			WaypostCharDB = W.CopyTable(bk)
			restored = true
		else
			WaypostCharDB = {}
		end
	end

	local db = WaypostDB
	db.version = DB_VERSION
	db.profiles = valid(db.profiles) and db.profiles or {}
	db.profileKeys = valid(db.profileKeys) and db.profileKeys or {}
	db.custom = valid(db.custom) and db.custom or {}
	db.recordings = valid(db.recordings) and db.recordings or {}
	db.guild = valid(db.guild) and db.guild or {}
	db.export = valid(db.export) and db.export or {}
	db.export.characters = valid(db.export.characters) and db.export.characters or {}

	merge(WaypostCharDB, W.charDefaults)
	W.char = WaypostCharDB
	W.db = db
	W.SelectProfile(db.profileKeys[charKey()] or "Default", true)
	if restored then
		W.After(3, function() W.Print(L["Settings were restored from the backup copy."]) end)
	end
end)

function W.SelectProfile(name, silent)
	local db = W.db
	if not valid(db.profiles[name]) then db.profiles[name] = {} end
	merge(db.profiles[name], W.defaults)
	db.profileKeys[charKey()] = name
	W.profileName = name
	W.opt = db.profiles[name]
	if not silent then W.Fire("WP_SETTINGS", "*") end
end

function W.ProfileList()
	local out = {}
	for k in pairs(W.db.profiles) do out[#out + 1] = k end
	table.sort(out)
	return out
end

function W.DeleteProfile(name)
	if name == "Default" or name == W.profileName then return false end
	W.db.profiles[name] = nil
	for k, v in pairs(W.db.profileKeys) do if v == name then W.db.profileKeys[k] = nil end end
	return true
end

function W.ResetProfile()
	W.db.profiles[W.profileName] = {}
	W.SelectProfile(W.profileName)
end

-- Get/Set by dotted path: W.Get("arrow.scale")
function W.Get(path)
	local t = W.opt
	for part in path:gmatch("[^%.]+") do
		if type(t) ~= "table" then return nil end
		t = t[part]
	end
	return t
end

function W.Set(path, value)
	local t = W.opt
	local parts = {}
	for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
	for i = 1, #parts - 1 do
		if type(t[parts[i]]) ~= "table" then t[parts[i]] = {} end
		t = t[parts[i]]
	end
	t[parts[#parts]] = value
	W.Fire("WP_SETTINGS", path, value)
end

-- Backup at logout: a plain copy, cheap and robust.
W.On("PLAYER_LOGOUT", function()
	if not (valid(WaypostDB) and valid(WaypostCharDB)) then return end
	WaypostBackup = valid(WaypostBackup) and WaypostBackup or {}
	WaypostBackup.db = {
		version = WaypostDB.version,
		profiles = WaypostDB.profiles,
		profileKeys = WaypostDB.profileKeys,
		custom = WaypostDB.custom,
	}
	WaypostBackup.chars = valid(WaypostBackup.chars) and WaypostBackup.chars or {}
	WaypostBackup.chars[charKey()] = WaypostCharDB
	WaypostBackup.saved = time and time() or 0
end)
