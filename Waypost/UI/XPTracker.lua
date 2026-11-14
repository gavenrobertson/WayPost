-- Live XP tracker: a small movable panel that updates as you play.
--
--   Level 14                                    62.4%
--   [=================|rested|.............]
--   12,345 / 19,800 XP                     7,455 to go
--   21.4k XP/h                              0:20:54
--   last 10 minutes                      to level 15
--   [ per-minute bars for the last ten minutes ]
--   Session +34.5k in 1h 12m       Quests 22.1k (9)
--   About 38 kills or 4 quests     Kills 12.4k (63)
--
-- XP gains pop up as "+420" over the bar. While the panel is shown it
-- refreshes four times a second (the countdown, the falling or climbing
-- rate, the bars); hidden, it costs nothing. Drag to move, drag the corner
-- to change its width, right-click for options.

local W = Waypost
local L = W.L
local UI = W.UI
local Col = UI.C
local T = {}
W.Tracker = T

local floor, max, min = math.floor, math.max, math.min
local MIN_W, MAX_W = 210, 420
local BARS = 10

local frame, bar, rested, barText, levelText, pctText, rateText, rateLabel, ttlText, ttlLabel
local minutes, minuteBars, sessionText, sourceText, estimateText, killsText
local floaters = {}
local perMinute = {}

local function comma(n)
	n = floor((n or 0) + 0.5)
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clock(sec)
	if not sec or sec ~= sec or sec == math.huge or sec < 0 then return "--:--" end
	sec = floor(sec + 0.5)
	local h, m, s = floor(sec / 3600), floor(sec % 3600 / 60), sec % 60
	if h > 0 then return ("%d:%02d:%02d"):format(h, m, s) end
	return ("%d:%02d"):format(m, s)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function text(parent, font, justify)
	local f = parent:CreateFontString(nil, "OVERLAY", font)
	f:SetJustifyH(justify or "LEFT")
	f:SetWordWrap(false)
	return f
end

local function layout()
	if not frame then return end
	local w = frame:GetWidth()
	local inner = w - 20
	bar:SetWidth(inner)
	minutes:SetWidth(inner)
	local bw = (inner - (BARS - 1) * 2) / BARS
	for i = 1, BARS do
		local b = minuteBars[i]
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", minutes, "BOTTOMLEFT", (i - 1) * (bw + 2), 0)
		b:SetWidth(max(1, bw))
	end
end

local function savePosition()
	local x, y = frame:GetLeft(), frame:GetTop()
	if x then W.opt.tracker.pos = { x = x, y = y } end
	W.opt.tracker.width = floor(frame:GetWidth() + 0.5)
end

local function restore()
	local o = W.opt.tracker
	frame:SetWidth(min(MAX_W, max(MIN_W, o.width or 250)))
	frame:ClearAllPoints()
	if type(o.pos) == "table" and o.pos.x then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", o.pos.x, o.pos.y)
	else
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -120)
	end
	frame:SetScale(o.scale or 1)
	frame:SetAlpha(o.alpha or 1)
	layout()
end

local function menu(owner)
	local o = W.opt.tracker
	UI.ShowMenu(owner, {
		{ text = L["XP tracker"], title = true },
		{ text = L["Level history"], icon = "chart", func = function() W.XP.ToggleWindow(true) end },
		{ text = L["Lock in place"], checked = o.locked, func = function() W.Set("tracker.locked", not o.locked) end },
		{ text = L["Reset position"], func = function() o.pos = nil; restore() end },
		{ text = L["Hide"], func = function() T.Toggle(false) end },
	}, 170, "right")
end

local function build()
	frame = CreateFrame("Frame", "WaypostXPTracker", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, 60, MAX_W, 600) end
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) if not W.opt.tracker.locked then self:StartMoving() end end)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() savePosition() restore() end)
	frame:SetScript("OnMouseUp", function(self, b) if b == "RightButton" then menu(self) end end)
	UI.Backdrop(frame, "panel")

	levelText = text(frame, "WaypostFontHead")
	levelText:SetPoint("TOPLEFT", 10, -8)
	local close = UI.IconButton(frame, 9, "close", function() T.Toggle(false) end)
	close:SetPoint("TOPRIGHT", -3, -4)
	local hist = UI.IconButton(frame, 11, "chart", function() W.XP.ToggleWindow(true) end)
	hist:SetPoint("RIGHT", close, "LEFT", 0, 0)
	UI.Tooltip(hist, L["Level history"], L["A graph of how long each level took."], "ANCHOR_BOTTOMLEFT")
	pctText = text(frame, "WaypostFontGold", "RIGHT")
	pctText:SetPoint("RIGHT", hist, "LEFT", -4, 0)

	-- XP bar: fill, rested overlay, then the text over both
	bar = CreateFrame("StatusBar", nil, frame)
	bar:SetPoint("TOPLEFT", 10, -32)
	bar:SetHeight(12)
	bar:SetStatusBarTexture(UI.WHITE)
	bar:SetStatusBarColor(0.62, 0.32, 0.92)
	bar:SetMinMaxValues(0, 1)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(UI.WHITE)
	bg:SetAllPoints()
	bg:SetVertexColor(0, 0, 0, 0.6)
	UI.Trim(bar, Col.trim, 0.8, "OVERLAY")
	rested = bar:CreateTexture(nil, "ARTWORK", nil, -1)
	rested:SetTexture(UI.WHITE)
	rested:SetVertexColor(0.3, 0.55, 1, 0.45)
	rested:SetPoint("TOP")
	rested:SetPoint("BOTTOM")
	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function(self)
		local s = W.XP.Snapshot()
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText((L["Level %d"]):format(s.level), 1, 0.82, 0)
		GameTooltip:AddLine(("%s / %s XP (%.1f%%)"):format(comma(s.cur), comma(s.max), s.pct * 100), 1, 1, 1)
		if s.rested > 0 then GameTooltip:AddLine((L["Rested: %s XP"]):format(comma(s.rested)), 0.45, 0.65, 1) end
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

	barText = text(frame, "WaypostFontSmall")
	barText:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
	local leftText = text(frame, "WaypostFontMuted", "RIGHT")
	leftText:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -4)
	frame.leftText = leftText

	-- rate and countdown
	rateText = text(frame, "WaypostFontDing")
	rateText:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -22)
	rateLabel = text(frame, "WaypostFontMuted")
	rateLabel:SetPoint("TOPLEFT", rateText, "BOTTOMLEFT", 0, -1)
	rateLabel:SetText(L["XP per hour, last 10 minutes"])
	ttlText = text(frame, "WaypostFontBig", "RIGHT")
	ttlText:SetPoint("BOTTOMRIGHT", rateText, "BOTTOMRIGHT", 0, 0)
	ttlText:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
	ttlLabel = text(frame, "WaypostFontMuted", "RIGHT")
	ttlLabel:SetPoint("TOPRIGHT", rateLabel, "TOPRIGHT", 0, 0)
	ttlLabel:SetPoint("RIGHT", bar, "RIGHT", 0, 0)

	-- XP in each of the last ten minutes
	minutes = CreateFrame("Frame", nil, frame)
	minutes:SetPoint("TOPLEFT", rateLabel, "BOTTOMLEFT", 0, -8)
	minutes:SetHeight(26)
	minuteBars = {}
	for i = 1, BARS do
		local b = minutes:CreateTexture(nil, "ARTWORK")
		b:SetTexture(UI.WHITE)
		b:SetHeight(1)
		minuteBars[i] = b
	end
	local base = minutes:CreateTexture(nil, "BORDER")
	base:SetTexture(UI.WHITE)
	base:SetVertexColor(Col.muted[1], Col.muted[2], Col.muted[3], 0.6)
	base:SetHeight(1)
	base:SetPoint("BOTTOMLEFT", 0, -1)
	base:SetPoint("BOTTOMRIGHT", 0, -1)
	minutes:EnableMouse(true)
	UI.Tooltip(minutes, L["XP each minute"], L["The last ten minutes; the bar on the right is the minute in progress."])

	sessionText = text(frame, "WaypostFontSmall")
	sessionText:SetPoint("TOPLEFT", minutes, "BOTTOMLEFT", 0, -8)
	sourceText = text(frame, "WaypostFontSmall", "RIGHT")
	sourceText:SetPoint("TOPRIGHT", minutes, "BOTTOMRIGHT", 0, -8)
	estimateText = text(frame, "WaypostFontMuted")
	estimateText:SetPoint("TOPLEFT", sessionText, "BOTTOMLEFT", 0, -3)
	killsText = text(frame, "WaypostFontSmall", "RIGHT")
	killsText:SetPoint("TOPRIGHT", sourceText, "BOTTOMRIGHT", 0, -3)

	-- width grip
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(14, 14)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	grip.icon = UI.Icon(grip, "grip", 10, "OVERLAY", Col.muted)
	grip.icon:SetPoint("CENTER")
	grip:SetScript("OnEnter", function(self) self.icon:SetVertexColor(Col.gold[1], Col.gold[2], Col.gold[3]) end)
	grip:SetScript("OnLeave", function(self) self.icon:SetVertexColor(Col.muted[1], Col.muted[2], Col.muted[3]) end)
	grip:SetScript("OnMouseDown", function()
		if W.opt.tracker.locked then return end
		frame:StartSizing("RIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		savePosition()
		restore()
	end)
	frame.grip = grip
	frame:SetScript("OnSizeChanged", layout)

	frame:SetHeight(188)
	local acc = 0
	frame:SetScript("OnUpdate", function(_, dt)
		acc = acc + dt
		if acc >= 0.25 then
			acc = 0
			T.Update()
		end
	end)
	frame:Hide()
end

---------------------------------------------------------------------------
-- "+420" over the bar when XP comes in
---------------------------------------------------------------------------
local function floater()
	for _, f in ipairs(floaters) do
		if not f.anim:IsPlaying() then return f end
	end
	local f = frame:CreateFontString(nil, "OVERLAY", "WaypostFontGold")
	f:SetAlpha(0)
	f.anim = f:CreateAnimationGroup()
	local up = f.anim:CreateAnimation("Translation")
	up:SetOffset(0, 22)
	up:SetDuration(1.4)
	up:SetSmoothing("OUT")
	local fadeIn = f.anim:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.12)
	local fadeOut = f.anim:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetStartDelay(0.9)
	fadeOut:SetDuration(0.5)
	f.anim:SetScript("OnFinished", function() f:SetAlpha(0) end)
	floaters[#floaters + 1] = f
	return f
end

local function popGain(xp, src)
	if not frame or not frame:IsShown() then return end
	local f = floater()
	f:SetText("+" .. comma(xp))
	if src == "quest" then f:SetTextColor(Col.gold[1], Col.gold[2], Col.gold[3]) else f:SetTextColor(1, 1, 1) end
	f:ClearAllPoints()
	local x = bar:GetWidth() * min(1, W.XP.Snapshot().pct)
	f:SetPoint("BOTTOM", bar, "TOPLEFT", max(24, min(bar:GetWidth() - 24, x)), 0)
	f.anim:Stop()
	f.anim:Play()
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
function T.Update()
	if not frame or not frame:IsShown() then return end
	local s = W.XP.Snapshot()
	levelText:SetText((L["Level %d"]):format(s.level))
	pctText:SetText(("%.1f%%"):format(s.pct * 100))
	bar:SetValue(min(1, s.pct))
	local w = bar:GetWidth()
	if s.rested > 0 and s.max > 0 then
		local from = w * min(1, s.pct)
		local to = w * min(1, (s.cur + s.rested) / s.max)
		rested:ClearAllPoints()
		rested:SetPoint("TOPLEFT", bar, "TOPLEFT", from, 0)
		rested:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", from, 0)
		rested:SetWidth(max(1, to - from))
		rested:Show()
	else
		rested:Hide()
	end
	barText:SetText(("%s / %s"):format(comma(s.cur), comma(s.max)))
	frame.leftText:SetText((L["%s to go"]):format(comma(s.left)))

	if s.rate > 0 then
		rateText:SetText(W.FormatNumber(s.rate))
		ttlText:SetText(clock(s.ttl))
	else
		rateText:SetText("--")
		ttlText:SetText("--:--")
	end
	ttlLabel:SetText((L["to level %d"]):format(s.level + 1))

	-- bars: scaled to the busiest minute; the current minute is lighter
	W.XP.PerMinute(BARS, perMinute)
	local top = 1
	for i = 1, BARS do if perMinute[i] > top then top = perMinute[i] end end
	for i = 1, BARS do
		local b = minuteBars[i]
		local v = perMinute[i]
		b:SetHeight(max(1, 26 * v / top))
		local a = (v > 0) and (i == BARS and 0.5 or 0.95) or 0.2
		b:SetVertexColor(Col.gold[1], Col.gold[2], Col.gold[3], a)
	end

	sessionText:SetText((L["Session +%s in %s"]):format(W.FormatNumber(s.sessionXP), W.FormatTime(s.sessionTime)))
	sourceText:SetText((L["Quests %s (%d)"]):format(W.FormatNumber(s.questXP), s.quests))
	killsText:SetText((L["Kills %s (%d)"]):format(W.FormatNumber(s.killXP), s.kills))
	if s.killsToLevel and s.questsToLevel then
		estimateText:SetText((L["About %d kills or %d quests to level"]):format(s.killsToLevel, s.questsToLevel))
	elseif s.killsToLevel then
		estimateText:SetText((L["About %d kills to level"]):format(s.killsToLevel))
	elseif s.questsToLevel then
		estimateText:SetText((L["About %d quests to level"]):format(s.questsToLevel))
	else
		estimateText:SetText(L["Estimates appear after a few kills"])
	end
	estimateText:SetWidth(max(60, frame:GetWidth() - 20 - killsText:GetStringWidth() - 8))
end

function T.Toggle(show)
	if not frame then build() end
	if show == nil then show = not frame:IsShown() end
	W.opt.tracker.shown = show and true or false
	if show then
		restore()
		frame:Show()
		T.Update()
	else
		frame:Hide()
	end
end

function T.Frame() return frame end

W.On("WP_LOGIN", function()
	build()
	if W.opt.tracker.shown then T.Toggle(true) end
end)
W.On("WP_XP", T.Update)
W.On("WP_XP_GAIN", popGain)
W.On("WP_LEVEL", function() W.After(0.3, T.Update) end)
W.On("WP_SETTINGS", function(path)
	if not frame then return end
	if path == "*" or (type(path) == "string" and path:find("^tracker")) then
		if W.opt.tracker.shown then T.Toggle(true) else T.Toggle(false) end
		frame.grip:SetShown(not W.opt.tracker.locked)
	end
end)
