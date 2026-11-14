-- Waypost: free leveling guide for WoW Forever.
-- Core namespace: events, timers, combat queue and small shared helpers.
--
-- Performance rules every module follows:
--   * event driven; no OnUpdate unless a frame is visible and needs motion
--   * no work in combat beyond the arrow; anything else queues for PLAYER_REGEN_ENABLED
--   * nothing allocates per frame (reuse tables, cache API lookups)

local ADDON, ns = ...
Waypost = Waypost or {}
local W = Waypost
W.ns = ns
ns.W = W

W.name = ADDON
W.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"
if W.version:find("@") then W.version = "dev" end

local type, pairs, select, pcall, tostring = type, pairs, select, pcall, tostring
local geterrorhandler = geterrorhandler

---------------------------------------------------------------------------
-- Locale (filled by Locales/*.lua; missing keys fall back to the key)
---------------------------------------------------------------------------
W.L = W.L or setmetatable({}, { __index = function(_, k) return k end })

---------------------------------------------------------------------------
-- Secret-value safety (Forever applies Midnight restrictions)
---------------------------------------------------------------------------
local issecretvalue = issecretvalue
function W.Readable(v)
	if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
	return v
end

function W.Safe(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok and W.debug then geterrorhandler()(err) end
		return ok and err or nil
	end
end

---------------------------------------------------------------------------
-- Event bus: Blizzard events and internal messages share one dispatcher
---------------------------------------------------------------------------
local frame = CreateFrame("Frame", "WaypostEventFrame")
W.eventFrame = frame
local handlers = {}

function W.On(event, fn)
	local list = handlers[event]
	if not list then
		list = {}
		handlers[event] = list
		if not event:find("^WP_") then
			pcall(frame.RegisterEvent, frame, event)
		end
	end
	list[#list + 1] = fn
end

function W.Fire(event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then
			W.lastError = err
			if W.debug then geterrorhandler()(err) end
		end
	end
end

frame:SetScript("OnEvent", function(_, event, ...) W.Fire(event, ...) end)

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------
function W.After(sec, fn)
	if C_Timer and C_Timer.After then C_Timer.After(sec, fn) else fn() end
end

-- Coalesce bursts (QUEST_LOG_UPDATE fires in storms): calls within `delay`
-- of the first one collapse into a single run.
function W.Debounce(delay, fn)
	local pending = false
	local function run()
		pending = false
		fn()
	end
	return function()
		if pending then return end
		pending = true
		W.After(delay, run)
	end
end

function W.Throttle(interval, fn)
	local last, queued = 0, false
	local function run()
		queued = false
		last = GetTime()
		fn()
	end
	return function()
		local now = GetTime()
		if now - last >= interval then
			run()
		elseif not queued then
			queued = true
			W.After(interval - (now - last), run)
		end
	end
end

---------------------------------------------------------------------------
-- Combat: queue protected work until combat ends
---------------------------------------------------------------------------
local combatQueue = {}
function W.InCombat()
	return (InCombatLockdown and InCombatLockdown()) and true or false
end

function W.OutOfCombat(key, fn)
	if not W.InCombat() then
		fn()
	else
		combatQueue[key] = fn
	end
end

W.On("PLAYER_REGEN_ENABLED", function()
	for k, fn in pairs(combatQueue) do
		combatQueue[k] = nil
		local ok, err = pcall(fn)
		if not ok and W.debug then geterrorhandler()(err) end
	end
	W.Fire("WP_COMBAT_ENDED")
end)
W.On("PLAYER_REGEN_DISABLED", function() W.Fire("WP_COMBAT_STARTED") end)

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------
W.COLOR = "|cffffd100"   -- Blizzard gold
W.BRAND = "|cffe8c35cWaypost|r"

function W.Print(msg, ...)
	if select("#", ...) > 0 then msg = msg:format(...) end
	DEFAULT_CHAT_FRAME:AddMessage(W.BRAND .. ": " .. tostring(msg))
end

function W.Debug(msg, ...)
	if W.debug then W.Print("|cff888888" .. tostring(msg) .. "|r", ...) end
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
function W.Contains(list, v)
	if type(list) ~= "table" then return false end
	for i = 1, #list do if list[i] == v then return true end end
	return false
end

function W.CopyTable(src, dst)
	dst = dst or {}
	for k, v in pairs(src) do
		if type(v) == "table" then dst[k] = W.CopyTable(v, {}) else dst[k] = v end
	end
	return dst
end

function W.Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function W.FormatTime(sec)
	if not sec or sec ~= sec or sec == math.huge or sec < 0 then return "--" end
	sec = math.floor(sec + 0.5)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	if h > 0 then return ("%dh %02dm"):format(h, m) end
	local s = sec % 60
	if m > 0 then return ("%dm %02ds"):format(m, s) end
	return ("%ds"):format(s)
end

function W.FormatNumber(n)
	if not n then return "0" end
	if n >= 1e6 then return ("%.1fm"):format(n / 1e6) end
	if n >= 1e4 then return ("%.1fk"):format(n / 1e3) end
	return tostring(math.floor(n + 0.5))
end

-- Player facts, cached at login and refreshed on level up.
W.player = {}
function W.RefreshPlayer()
	local p = W.player
	local _, class = UnitClass("player")
	local _, race = UnitRace("player")
	p.class = W.Readable(class) or p.class
	p.race = W.Readable(race) or p.race
	p.faction = W.Readable(UnitFactionGroup("player")) or p.faction
	p.level = W.Readable(UnitLevel("player")) or p.level or 1
	p.name = W.Readable(UnitName("player")) or p.name
	p.realm = W.Readable(GetRealmName and GetRealmName()) or p.realm or ""
	-- Polestar names the Forsaken "Scourge"; the client reports "Scourge" too.
	if p.race == "Undead" then p.race = "Scourge" end
	return p
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
W.On("ADDON_LOADED", function(name)
	if name ~= ADDON then
		W.Fire("WP_ADDON_LOADED", name)
		return
	end
	W.RefreshPlayer()
	W.Fire("WP_INIT")          -- DB ready after this
end)

W.On("PLAYER_LOGIN", function()
	W.RefreshPlayer()
	W.loggedIn = true
	W.Fire("WP_LOGIN")
	W.After(0.5, function() W.Fire("WP_READY") end)
end)

W.On("PLAYER_LEVEL_UP", function(level)
	W.player.level = W.Readable(level) or (W.player.level or 1) + 1
	W.Fire("WP_LEVEL", W.player.level)
end)
