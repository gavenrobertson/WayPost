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

---------------------------------------------------------------------------
-- Chart: how long each level took
--
-- One bar per level, height = time spent at that level, from a zero
-- baseline. One colour, since there is one series; the level in progress is
-- drawn fainter. Three quiet gridlines carry the scale, hovering a bar gives
-- its exact time, and the same numbers are in the list under the chart.
---------------------------------------------------------------------------
local chart
local PLOT_LEFT, PLOT_RIGHT, PLOT_TOP, PLOT_BOTTOM = 44, 10, 46, 20
local STEPS = { 60, 120, 300, 600, 900, 1800, 3600, 7200, 14400, 28800, 43200, 86400 }

local function axisTime(sec)
	if sec >= 3600 then
		local h = sec / 3600
		return (h == math.floor(h)) and ("%dh"):format(h) or ("%.1fh"):format(h)
	end
	return ("%dm"):format(math.floor(sec / 60 + 0.5))
end

-- Levels in order, with the level in progress last.
function X.LevelSeries()
	account()
	local x = W.char.xp
	local out = {}
	for lv, secs in pairs(x.levels) do
		if type(lv) == "number" and type(secs) == "number" then out[#out + 1] = { level = lv, secs = secs } end
	end
	table.sort(out, function(p, q) return p.level < q.level end)
	local cur = W.player.level or 1
	if (x.levelTime or 0) > 0 and (#out == 0 or out[#out].level < cur) then
		out[#out + 1] = { level = cur, secs = x.levelTime, live = true }
	end
	return out
end

local function buildChart(parent)
	local c = CreateFrame("Frame", nil, parent)
	UI.Backdrop(c, "well")
	c.title = c:CreateFontString(nil, "ARTWORK", "WaypostFontGold")
	c.title:SetPoint("TOPLEFT", 10, -8)
	c.title:SetText(L["Time spent on each level"])
	c.sub = c:CreateFontString(nil, "ARTWORK", "WaypostFontMuted")
	c.sub:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
	c.empty = c:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
	c.empty:SetPoint("CENTER", 0, -8)
	c.empty:SetText(L["Play for a minute and the first bar appears here."])
	c.plot = CreateFrame("Frame", nil, c)
	c.plot:SetPoint("TOPLEFT", PLOT_LEFT, -PLOT_TOP)
	c.plot:SetPoint("BOTTOMRIGHT", -PLOT_RIGHT, PLOT_BOTTOM)
	c.base = c.plot:CreateTexture(nil, "ARTWORK")
	c.base:SetTexture(UI.WHITE)
	c.base:SetVertexColor(UI.C.muted[1], UI.C.muted[2], UI.C.muted[3], 0.8)
	c.base:SetHeight(1)
	c.base:SetPoint("BOTTOMLEFT")
	c.base:SetPoint("BOTTOMRIGHT")
	c.grid, c.bars, c.xlabels = {}, {}, {}
	for i = 1, 3 do
		local line = c.plot:CreateTexture(nil, "BACKGROUND")
		line:SetTexture(UI.WHITE)
		line:SetVertexColor(1, 1, 1, 0.07)
		line:SetHeight(1)
		local label = c:CreateFontString(nil, "ARTWORK", "WaypostFontMuted")
		label:SetJustifyH("RIGHT")
		c.grid[i] = { line = line, label = label }
	end
	return c
end

local function barTooltip(self)
	local d = self.data
	if not d then return end
	self.fill:SetVertexColor(1, 0.93, 0.6, 1)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText((L["Level %d"]):format(d.level), 1, 0.82, 0)
	GameTooltip:AddLine(W.FormatTime(d.secs) .. (d.live and ("  " .. L["so far"]) or ""), 1, 1, 1)
	if d.rank then GameTooltip:AddLine(d.rank, 0.7, 0.7, 0.7) end
	GameTooltip:Show()
end

local function barLeave(self)
	local d = self.data
	local a = d and d.live and 0.4 or 0.95
	self.fill:SetVertexColor(UI.C.gold[1], UI.C.gold[2], UI.C.gold[3], a)
	GameTooltip:Hide()
end

function X.RenderChart()
	if not chart or not chart:IsShown() then return end
	local data = X.LevelSeries()
	local n = #data
	local c = chart
	local w, h = c.plot:GetWidth(), c.plot:GetHeight()
	c.empty:SetShown(n == 0)
	c.plot:SetShown(n > 0)
	for i = 1, #c.bars do c.bars[i]:Hide() end
	for i = 1, #c.xlabels do c.xlabels[i]:Hide() end
	for i = 1, 3 do c.grid[i].label:SetShown(n > 0) end
	if n == 0 or w <= 0 then
		c.sub:SetText("")
		return
	end

	-- scale: the smallest round step that covers the tallest bar in at most three gridlines
	local maxSecs, total, done, slow, fast = 0, 0, 0, nil, nil
	for _, d in ipairs(data) do
		if d.secs > maxSecs then maxSecs = d.secs end
		if not d.live then
			total, done = total + d.secs, done + 1
			if not slow or d.secs > slow.secs then slow = d end
			if not fast or d.secs < fast.secs then fast = d end
		end
	end
	local step = STEPS[#STEPS]
	for _, st in ipairs(STEPS) do
		if maxSecs <= st * 3 then step = st break end
	end
	local top = step * 3
	for i = 1, 3 do
		local y = h * (step * i) / top
		local g = c.grid[i]
		g.line:ClearAllPoints()
		g.line:SetPoint("BOTTOMLEFT", 0, y)
		g.line:SetPoint("BOTTOMRIGHT", 0, y)
		g.label:ClearAllPoints()
		g.label:SetPoint("RIGHT", c.plot, "BOTTOMLEFT", -6, y)
		g.label:SetText(axisTime(step * i))
	end
	if done > 0 then
		c.sub:SetText((L["%d levels, %s on average"]):format(done, W.FormatTime(total / done)))
		if done > 1 then
			slow.rank, fast.rank = L["Your slowest level"], L["Your fastest level"]
		end
	else
		c.sub:SetText(L["Your first level in progress"])
	end

	-- bars: a 2 px gap between neighbours, never wider than 22 px
	local col = math.min(24, w / n)
	local barW = math.max(2, math.floor(col - 2))
	local every = 1
	for _, k in ipairs({ 1, 2, 5, 10, 20 }) do
		every = k
		if col * k >= 24 then break end
	end
	local xl = 0
	for i, d in ipairs(data) do
		local b = c.bars[i]
		if not b then
			b = CreateFrame("Button", nil, c.plot)
			b.fill = b:CreateTexture(nil, "ARTWORK")
			b.fill:SetTexture(UI.WHITE)
			b.fill:SetPoint("BOTTOM", 0, 1)
			b:SetScript("OnEnter", barTooltip)
			b:SetScript("OnLeave", barLeave)
			c.bars[i] = b
		end
		b.data = d
		-- the whole column is the hover target, so thin and short bars are easy to hit
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", (i - 1) * col, 0)
		b:SetSize(col, h)
		b.fill:SetSize(barW, math.max(1, (h - 1) * d.secs / top))
		barLeave(b)
		b:Show()
		if d.level % every == 0 or n < 3 then
			xl = xl + 1
			local t = c.xlabels[xl]
			if not t then
				t = c:CreateFontString(nil, "ARTWORK", "WaypostFontMuted")
				c.xlabels[xl] = t
			end
			t:ClearAllPoints()
			t:SetPoint("TOP", b, "BOTTOM", 0, -4)
			t:SetText(d.level)
			t:Show()
		end
	end
end

function X.ToggleWindow(show)
	if not win then
		win = UI.Window("WaypostXP", L["Leveling Speed"], 440, 560)
		chart = buildChart(win)
		chart:SetPoint("TOPLEFT", 14, -40)
		chart:SetPoint("TOPRIGHT", -14, -40)
		chart:SetHeight(200)
		local box = CreateFrame("Frame", nil, win)
		box:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -8)
		box:SetPoint("BOTTOMRIGHT", -14, 14)
		UI.Backdrop(box, "well")
		view = UI.VirtualList(box, 20, function(row)
			row.a = row:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
			row.a:SetPoint("LEFT", 8, 0)
			row.a:SetWidth(230)
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
		win:HookScript("OnShow", function()
			view.SetItems(items())
			X.RenderChart()
		end)
		chart.plot:SetScript("OnSizeChanged", function() X.RenderChart() end)
	end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then
		view.SetItems(items())
		X.RenderChart()
	end
end

W.On("WP_LEVEL", function()
	W.After(0.5, function()
		if win and win:IsShown() then
			view.SetItems(items())
			X.RenderChart()
		end
	end)
end)
