-- Leveling speed: XP per hour, time to level, time per level and per guide,
-- and a history of finished guides with the time saved against your best.
-- Costs one handler on PLAYER_XP_UPDATE; nothing ticks.

local W = Waypost
local L = W.L
local UI = W.UI
local X = {}
W.XP = X

local now = function() return (GetTime and GetTime()) or 0 end
local wall = function() return (time and time()) or 0 end

local sessionStart, sessionXP = nil, 0
local lastXP, lastMax
local samples = {}          -- { t, totalGained } ring for a 15 minute window
local WINDOW = 900
local mark                  -- wall clock at login or last accounting point
local timedGuide            -- the guide the time since `mark` belongs to

local function account()
	-- Move elapsed online time into the level and guide timers.
	local x = W.char.xp
	local t = wall()
	if mark then
		local d = math.max(0, math.min(t - mark, 6 * 3600))
		x.levelTime = (x.levelTime or 0) + d
		local id = timedGuide
		if id then x.guides[id] = (x.guides[id] or 0) + d end
		x.played = (x.played or 0) + d
	end
	mark = t
end

function X.Rate()
	local t = now()
	while #samples > 2 and t - samples[1].t > WINDOW do table.remove(samples, 1) end
	local first, last = samples[1], samples[#samples]
	if first and last and last.t - first.t >= 60 and last.g > first.g then
		return (last.g - first.g) / (last.t - first.t) * 3600
	end
	if sessionStart and t - sessionStart >= 60 and sessionXP > 0 then
		return sessionXP / (t - sessionStart) * 3600
	end
	return 0
end

function X.TimeToLevel()
	local rate = X.Rate()
	if rate <= 0 or not lastXP or not lastMax then return nil end
	return (lastMax - lastXP) / rate * 3600
end

function X.ShortText()
	local rate = X.Rate()
	if rate <= 0 then return "" end
	local ttl = X.TimeToLevel()
	return ("%s %s  |cffffffff%s|r"):format(W.FormatNumber(rate), L["XP/h"], ttl and W.FormatTime(ttl) or "")
end

function X.TooltipText()
	account()
	local x = W.char.xp
	local rate = X.Rate()
	local lines = {}
	lines[#lines + 1] = (L["XP per hour: %s"]):format(rate > 0 and W.FormatNumber(rate) or "--")
	lines[#lines + 1] = (L["Time to next level: %s"]):format(W.FormatTime(X.TimeToLevel()))
	lines[#lines + 1] = (L["Time on this level: %s"]):format(W.FormatTime(x.levelTime or 0))
	if W.char.guide then
		lines[#lines + 1] = (L["Time on this guide: %s"]):format(W.FormatTime(x.guides[W.char.guide] or 0))
	end
	lines[#lines + 1] = L["Click for your level history."]
	return table.concat(lines, "\n")
end

local function onXP()
	local cur, max = W.Readable(UnitXP("player")), W.Readable(UnitXPMax("player"))
	if type(cur) ~= "number" or type(max) ~= "number" then return end
	if lastXP then
		local gained = cur - lastXP
		if gained < 0 then gained = (lastMax - lastXP) + cur end   -- leveled
		if gained > 0 then
			sessionXP = sessionXP + gained
			samples[#samples + 1] = { t = now(), g = sessionXP }
		end
	else
		samples[1] = { t = now(), g = 0 }
	end
	lastXP, lastMax = cur, max
	W.Fire("WP_XP")
end

W.On("WP_LOGIN", function()
	sessionStart = now()
	mark = wall()
	local x = W.char.xp
	x.levels = x.levels or {}
	x.guides = x.guides or {}
	x.runs = x.runs or {}
	timedGuide = W.char.guide
	onXP()
end)
W.On("PLAYER_XP_UPDATE", function(unit) if unit == nil or unit == "player" then onXP() end end)

W.On("WP_LEVEL", function(level)
	account()
	local x = W.char.xp
	x.levels[level - 1] = x.levelTime or 0
	x.levelTime = 0
end)

W.On("WP_GUIDE", function(guide)
	account()                       -- time so far goes to the guide we are leaving
	timedGuide = guide and guide.id or nil
end)

W.On("WP_GUIDE_DONE", function(guide)
	account()
	local x = W.char.xp
	local secs = x.guides[guide.id] or 0
	W.db.best = W.db.best or {}
	local best = W.db.best[guide.id]
	local run = { guide = guide.id, title = guide.title, seconds = secs, finished = wall(), level = W.player.level }
	x.runs[#x.runs + 1] = run
	if #x.runs > 100 then table.remove(x.runs, 1) end
	local text
	if best and best > 0 and secs > 0 then
		local d = best - secs
		if d > 0 then
			text = (L["Finished in %s: %s faster than your best."]):format(W.FormatTime(secs), W.FormatTime(d))
		else
			text = (L["Finished in %s. Your best is %s."]):format(W.FormatTime(secs), W.FormatTime(best))
		end
	else
		text = (L["Finished in %s."]):format(W.FormatTime(secs))
	end
	if secs > 0 and (not best or secs < best) then W.db.best[guide.id] = secs end
	UI.Toast((L["%s complete"]):format(guide.title or guide.id), text, "Interface\\Icons\\INV_Misc_Map_01", function() X.ToggleWindow(true) end)
end)

W.On("PLAYER_LOGOUT", function() account() end)

---------------------------------------------------------------------------
-- History window
---------------------------------------------------------------------------
local win, view
local function items()
	account()
	local x = W.char.xp
	local out = {}
	out[#out + 1] = { header = L["This session"] }
	out[#out + 1] = { a = L["XP per hour"], b = X.Rate() > 0 and W.FormatNumber(X.Rate()) or "--" }
	out[#out + 1] = { a = L["Time to next level"], b = W.FormatTime(X.TimeToLevel()) }
	out[#out + 1] = { a = (L["Level %d so far"]):format(W.player.level or 1), b = W.FormatTime(x.levelTime or 0) }
	out[#out + 1] = { header = L["Guides"] }
	local any = false
	for i = #x.runs, 1, -1 do
		local r = x.runs[i]
		local best = W.db.best and W.db.best[r.guide]
		out[#out + 1] = { a = r.title or r.guide, b = W.FormatTime(r.seconds), c = (best and best == r.seconds) and L["best"] or "" }
		any = true
	end
	if W.char.guide and W.Guides.Meta(W.char.guide) then
		out[#out + 1] = { a = (W.Guides.Meta(W.char.guide).title or W.char.guide) .. " |cff9d9d9d(" .. L["in progress"] .. ")|r",
			b = W.FormatTime(x.guides[W.char.guide] or 0) }
		any = true
	end
	if not any then out[#out + 1] = { a = "|cff9d9d9d" .. L["No finished guides yet."] .. "|r", b = "" } end
	out[#out + 1] = { header = L["Levels"] }
	local levels = {}
	for lv in pairs(x.levels) do levels[#levels + 1] = lv end
	table.sort(levels, function(p, q) return p > q end)
	for _, lv in ipairs(levels) do
		out[#out + 1] = { a = (L["Level %d"]):format(lv), b = W.FormatTime(x.levels[lv]) }
	end
	if #levels == 0 then out[#out + 1] = { a = "|cff9d9d9d" .. L["Level up once to start the history."] .. "|r", b = "" } end
	return out
end

function X.ToggleWindow(show)
	if not win then
		win = UI.Window("WaypostXP", L["Leveling Speed"], 380, 420)
		local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 14, -40)
		box:SetPoint("BOTTOMRIGHT", -14, 14)
		UI.Backdrop(box, "inset")
		view = UI.VirtualList(box, 20, function(row)
			row.a = row:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
			row.a:SetPoint("LEFT", 8, 0)
			row.a:SetWidth(200)
			row.a:SetJustifyH("LEFT")
			row.a:SetWordWrap(false)
			row.c = row:CreateFontString(nil, "ARTWORK", "WaypostFontGreen")
			row.c:SetPoint("RIGHT", -6, 0)
			row.b = row:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
			row.b:SetPoint("RIGHT", -50, 0)
			row:EnableMouse(false)
		end, function(row, it)
			if it.header then
				row.a:SetFontObject("WaypostFontGold")
				row.a:SetText(it.header)
				row.b:SetText("")
				row.c:SetText("")
			else
				row.a:SetFontObject("WaypostFontSmall")
				row.a:SetText(it.a)
				row.b:SetText(it.b or "")
				row.c:SetText(it.c or "")
			end
		end)
		view:SetPoint("TOPLEFT", 6, -8)
		view:SetPoint("BOTTOMRIGHT", -6, 8)
		win:HookScript("OnShow", function() view.SetItems(items()) end)
	end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then view.SetItems(items()) end
end
