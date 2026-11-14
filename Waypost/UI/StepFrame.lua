-- The guide window.
--
-- Top to bottom: a header (guide, step count, menu), the guide's progress
-- line, the step's title and tip, then the "Now" card: the one thing to do
-- right now, who or what it involves, and where it is, with live distance
-- and direction. Under it the step's other goals, what has been done, any
-- warning, what comes next, and the footer with XP per hour.
--
-- It redraws when the engine reports a change. Only the distance text is
-- refreshed on a timer, twice a second, and only while the window is shown.

local W = Waypost
local L = W.L
local UI, E, G, C = W.UI, W.Engine, W.Guides, W.Coords
local Col = UI.C

local SF = {}
W.StepFrame = SF

local PAD, HEADER = 10, 24
local floor, max, min = math.floor, math.max, math.min

-- glyph and tint per goal type
local GLYPH = {
	accept = "accept", turnin = "turnin", complete = "turnin", kill = "kill", collect = "collect", buy = "vendor",
	vendor = "vendor", use = "use", interact = "interact", talk = "talk", ["goto"] = "goto", enter = "goto",
	explore = "explore", level = "level", train = "train", learn = "train", skill = "train", craft = "use",
	fly = "fly", getfp = "fly", sethome = "home", hearth = "home", money = "vendor", rep = "star", die = "warn",
	note = "note", task = "note",
}
local TINT = { accept = Col.gold, turnin = Col.gold, complete = Col.gold, kill = Col.enemy, die = Col.bad }
SF.GLYPH, SF.TINT = GLYPH, TINT

---------------------------------------------------------------------------
-- Layouts: how much the window shows. Simple is what to do and where;
-- Standard adds the step's tip, its other goals and what comes next;
-- Detailed shows everything (every goal's details, finished goals, why the
-- step is there, five steps ahead, a live XP bar). Changing any single
-- element in Settings makes a Custom layout from the current one.
---------------------------------------------------------------------------
local PRESETS = {
	simple = { tip = false, info = false, where = true, goals = false, goalInfo = false, done = false,
		danger = true, why = false, next = 0, footer = false, xpbar = false },
	standard = { tip = true, info = true, where = true, goals = true, goalInfo = false, done = false,
		danger = true, why = false, next = 3, footer = true, xpbar = false },
	detailed = { tip = true, info = true, where = true, goals = true, goalInfo = true, done = true,
		danger = true, why = true, next = 5, footer = true, xpbar = true },
}
SF.PRESETS = PRESETS
SF.LAYOUTS = { { "simple", "Simple" }, { "standard", "Standard" }, { "detailed", "Detailed" }, { "custom", "Custom" } }
SF.ELEMENTS = {
	{ "tip", "The step's tip" }, { "info", "Details on the current goal" }, { "where", "Distance and direction" },
	{ "goals", "The step's other goals" }, { "goalInfo", "Details on every goal" }, { "done", "Finished goals" },
	{ "danger", "Warnings" }, { "why", "Why this step" }, { "footer", "Buttons and XP per hour" }, { "xpbar", "XP bar" },
}

function SF.Layout()
	local o = W.opt.ui
	if o.layout == "custom" and type(o.custom) == "table" then return o.custom end
	return PRESETS[o.layout] or PRESETS.standard
end

function SF.SetLayout(name)
	local o = W.opt.ui
	if name == "custom" and type(o.custom) ~= "table" then o.custom = W.CopyTable(SF.Layout()) end
	if name ~= "simple" then o.lastLayout = name end
	W.Set("ui.layout", name)
end

-- Change one element; the layout becomes Custom, starting from the one in use.
function SF.SetElement(key, value)
	local o = W.opt.ui
	if o.layout ~= "custom" or type(o.custom) ~= "table" then o.custom = W.CopyTable(SF.Layout()) end
	o.custom[key] = value
	o.lastLayout = "custom"
	W.Set("ui.layout", "custom")
end

local frame, header, bar, body, footer, list
local now, rows, nextRows = nil, {}, {}
local seenDone, seenStep = {}, nil
local whereGoal

---------------------------------------------------------------------------
-- Where: "142 yd north-east  ·  Elwynn Forest 48.2, 42.9"
---------------------------------------------------------------------------
local COMPASS = { "north", "north-west", "west", "south-west", "south", "south-east", "east", "north-east" }

local function distanceText(d)
	if d >= 1000 then return ("%.1fk %s"):format(d / 1000, L["yd"]) end
	return ("%d %s"):format(floor(d + 0.5), L["yd"])
end

local function whereText(g)
	if not (g and g.map and g.x) then return nil end
	local place = ("%s %s"):format(C.MapName(g.map), C.Format(g.x, g.y))
	local d, bearing = C.GoalDistance(g)
	if not d then return place, nil end
	if d < 12 then return UI.Hex(Col.good) .. L["You are here"] .. "|r  ·  " .. place, d end
	local idx = floor((bearing % (2 * math.pi)) / (math.pi / 4) + 0.5) % 8 + 1
	return ("%s%s %s|r  ·  %s"):format(UI.Hex(Col.text), distanceText(d), L[COMPASS[idx]], place), d
end
SF.WhereText = whereText

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
local function savePosition()
	local left, top = frame:GetLeft(), frame:GetTop()
	if left then W.opt.ui.pos = { x = left, y = top } end
end

local function restorePosition()
	frame:ClearAllPoints()
	local pos = W.opt.ui.pos
	if type(pos) == "table" and pos.x and pos.y then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	else
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -250)
	end
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function goalTooltip(self)
	local g = self.goal
	if not g then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText((E.GoalText(g, self.si)), 1, 0.82, 0, 1, true)
	for _, line in ipairs(E.GoalInfo(g, self.si)) do GameTooltip:AddLine(line, 0.96, 0.93, 0.86, true) end
	local where = whereText(g)
	if where then GameTooltip:AddLine(where, 1, 0.9, 0.62) end
	-- the quest's own objectives, as the quest log words them
	if g.quest and W.Quest.IsOn(g.quest) then
		local objs = W.Quest.Objectives(g.quest)
		if objs then
			GameTooltip:AddLine(" ")
			for _, o in ipairs(objs) do
				if o.text and o.text ~= "" then
					GameTooltip:AddLine((o.finished and "|cff4df259" or "|cffbfbfbf") .. o.text .. "|r")
				end
			end
		end
	end
	if not E.view then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Click the box to tick this off by hand."], 0.5, 0.8, 1)
	end
	GameTooltip:Show()
end

local function tickBox(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(18, 18)
	b.icon = UI.Icon(b, "box", 14, "ARTWORK", Col.muted)
	b.icon:SetPoint("CENTER")
	b:SetScript("OnEnter", function(self)
		if not self.done then self.icon:SetVertexColor(Col.gold[1], Col.gold[2], Col.gold[3]) end
		goalTooltip(self:GetParent())
	end)
	b:SetScript("OnLeave", function(self)
		if not self.done then self.icon:SetVertexColor(Col.muted[1], Col.muted[2], Col.muted[3]) end
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function(self)
		local g = self:GetParent().goal
		if g and not E.view then E.ToggleGoal(g) end
	end)
	function b.Set(self, done)
		self.done = done
		UI.SetIcon(self.icon, done and "boxcheck" or "box")
		local c = done and Col.good or Col.muted
		self.icon:SetVertexColor(c[1], c[2], c[3])
	end
	return b
end

local function countBar(parent)
	local b = CreateFrame("StatusBar", nil, parent)
	b:SetHeight(3)
	b:SetStatusBarTexture(UI.WHITE)
	b:SetStatusBarColor(Col.gold[1], Col.gold[2], Col.gold[3])
	b:SetMinMaxValues(0, 1)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(UI.WHITE)
	bg:SetAllPoints()
	bg:SetVertexColor(0, 0, 0, 0.55)
	return b
end

local function newRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r:EnableMouse(true)
	r.icon = UI.Icon(r, "note", 14)
	r.icon:SetPoint("TOPLEFT", 1, -1)
	r.box = tickBox(r)
	r.box:SetPoint("TOPRIGHT", 2, 2)
	r.text = r:CreateFontString(nil, "ARTWORK")
	r.text:SetFontObject(UI.FontText)
	r.text:SetPoint("TOPLEFT", 22, 0)
	r.text:SetJustifyH("LEFT")
	r.text:SetJustifyV("TOP")
	r.text:SetWordWrap(true)
	r.sub = r:CreateFontString(nil, "ARTWORK")
	r.sub:SetFontObject(UI.FontSmall)
	r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -1)
	r.sub:SetJustifyH("LEFT")
	r.sub:SetWordWrap(true)
	r.bar = countBar(r)
	r:SetScript("OnEnter", goalTooltip)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return r
end

local function setGlyph(tex, g, done, current)
	if done then
		UI.SetIcon(tex, "check")
		tex:SetVertexColor(Col.good[1], Col.good[2], Col.good[3])
		return
	end
	UI.SetIcon(tex, GLYPH[g.t] or "note")
	local c = TINT[g.t] or (current and Col.text or Col.dim)
	tex:SetVertexColor(c[1], c[2], c[3])
end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------
local function openMenu(owner)
	local o = W.opt.ui
	UI.ShowMenu(owner, {
		{ text = L["Guides"], icon = "book", func = function() W.Picker.Toggle(true) end },
		{ text = L["Settings"], icon = "gear", func = function() W.Options.Toggle(true) end },
		{ text = L["All steps"], icon = "list", func = function() W.Set("ui.listOpen", not o.listOpen) end },
		{ text = L["Undo last skip"], icon = "undo", disabled = #W.char.undo == 0, func = function() E.UndoSkip() end },
		{ text = L["Re-read my quest log"], icon = "search", func = function() E.Rescan() end },
		{ text = L["More"], title = true },
		{ text = L["Party progress"], icon = "users", func = function() W.Group.Toggle(true) end },
		{ text = L["Guild leveling board"], icon = "users", func = function() W.Guild.Toggle(true) end },
		{ text = L["Talents"], icon = "star", func = function() W.Talents.Toggle(true) end },
		{ text = L["Leveling speed"], icon = "clock", func = function() W.XP.ToggleWindow(true) end },
		{ text = L["Quests set aside"], icon = "clock", func = function() W.SetAside.Toggle(true) end },
		{ text = L["Quests outside your route"], icon = "pinoff", func = function() W.Orphans.Toggle(true) end },
		{ text = L["Guide editor"], icon = "book", func = function() W.Editor.Open() end },
		{ text = L["Report a problem"], icon = "bug", func = function() W.Report.Open() end },
		{ text = L["Help"], icon = "note", func = function() W.Help.Open() end },
		{ text = L["Layout"], title = true },
		{ text = L["Simple"], checked = o.layout == "simple", func = function() SF.SetLayout("simple") end },
		{ text = L["Standard"], checked = o.layout == "standard", func = function() SF.SetLayout("standard") end },
		{ text = L["Detailed"], checked = o.layout == "detailed", func = function() SF.SetLayout("detailed") end },
		{ text = L["Custom..."], checked = o.layout == "custom", func = function() W.Options.Toggle(true, L["Guide window"]) end },
		{ text = L["Window"], title = true },
		{ text = L["Live XP tracker"], checked = W.opt.tracker.shown, func = function() W.Tracker.Toggle() end },
		{ text = L["Lock in place"], checked = o.locked, func = function() W.Set("ui.locked", not o.locked) end },
	}, 210, "right")
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function build()
	frame = CreateFrame("Frame", "WaypostFrame", UIParent)
	SF.frame = frame
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) if not W.opt.ui.locked then self:StartMoving() end end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
		restorePosition()
	end)
	frame.fill = UI.Fill(frame, Col.bg, 0.94)

	-- Header ------------------------------------------------------------
	header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(HEADER)
	header.band = header:CreateTexture(nil, "BACKGROUND")
	header.band:SetTexture(UI.WHITE)
	header.band:SetAllPoints()
	header.band:SetVertexColor(Col.band[1], Col.band[2], Col.band[3], 1)

	header.logo = header:CreateTexture(nil, "ARTWORK")
	header.logo:SetTexture(UI.MEDIA .. "Logo")
	header.logo:SetSize(16, 16)
	header.logo:SetPoint("LEFT", 7, 0)

	header.close = UI.IconButton(header, 10, "close", function() SF.Toggle(false) end)
	header.close:SetPoint("RIGHT", -4, 0)
	UI.Tooltip(header.close, L["Hide Waypost"], L["Type /waypost, press the minimap button or use the game menu to bring it back."], "ANCHOR_BOTTOMLEFT")
	header.compact = UI.IconButton(header, 10, "minus", function()
		local o = W.opt.ui
		if o.layout == "simple" then SF.SetLayout(o.lastLayout ~= "simple" and o.lastLayout or "standard") else SF.SetLayout("simple") end
	end)
	header.compact:SetPoint("RIGHT", header.close, "LEFT", -1, 0)
	UI.Tooltip(header.compact, function() return W.opt.ui.layout == "simple" and L["Show more"] or L["Simple layout"] end,
		function() return W.opt.ui.layout == "simple" and L["Back to your usual layout."] or L["Show only what to do now and where."] end, "ANCHOR_BOTTOMLEFT")
	header.menu = UI.IconButton(header, 12, "dots", function(self) openMenu(self) end)
	header.menu:SetPoint("RIGHT", header.compact, "LEFT", -1, 0)
	UI.Tooltip(header.menu, L["Menu"], L["Guides, settings and everything else."], "ANCHOR_BOTTOMLEFT")

	header.count = header:CreateFontString(nil, "ARTWORK")
	header.count:SetFontObject(UI.FontSmall)
	header.count:SetPoint("RIGHT", header.menu, "LEFT", -6, 0)

	header.title = CreateFrame("Button", nil, header)
	header.title:SetPoint("LEFT", header.logo, "RIGHT", 6, 0)
	header.title:SetPoint("RIGHT", header.count, "LEFT", -6, 0)
	header.title:SetHeight(HEADER)
	header.title.text = header.title:CreateFontString(nil, "ARTWORK")
	header.title.text:SetFontObject(UI.FontGold)
	header.title.text:SetAllPoints()
	header.title.text:SetJustifyH("LEFT")
	header.title.text:SetWordWrap(false)
	header.title:RegisterForDrag("LeftButton")
	header.title:SetScript("OnDragStart", function() if not W.opt.ui.locked then frame:StartMoving() end end)
	header.title:SetScript("OnDragStop", function() frame:StopMovingOrSizing() savePosition() restorePosition() end)
	header.title:SetScript("OnClick", function() W.Picker.Toggle() end)
	UI.Tooltip(header.title, function()
		if not E.guide then return L["Guides"] end
		return E.guide.title or E.guide.id
	end, function()
		if not E.guide then return L["Click to choose a guide."] end
		return (L["Levels %d-%d. Step %d of %d (%d%%).\nClick to change guide."]):format(E.guide.minLevel or 1, E.guide.maxLevel or 60,
			E.index or 0, #E.guide.steps, floor(E.Progress() * 100 + 0.5))
	end, "ANCHOR_BOTTOMLEFT")

	-- Guide progress: a gold line under the header
	bar = CreateFrame("StatusBar", nil, frame)
	bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
	bar:SetHeight(2)
	bar:SetStatusBarTexture(UI.WHITE)
	bar:SetStatusBarColor(Col.gold[1], Col.gold[2], Col.gold[3])
	bar:SetMinMaxValues(0, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetTexture(UI.WHITE)
	bar.bg:SetAllPoints()
	bar.bg:SetVertexColor(Col.trim[1], Col.trim[2], Col.trim[3], 0.35)

	-- Body --------------------------------------------------------------
	body = CreateFrame("Frame", nil, frame)
	body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", PAD, -8)
	body:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -PAD, -8)

	body.banner = CreateFrame("Button", nil, body)
	body.banner:SetHeight(20)
	UI.Fill(body.banner, Col.gold, 0.14)
	body.banner.icon = UI.Icon(body.banner, "undo", 11, "ARTWORK", Col.gold)
	body.banner.icon:SetPoint("LEFT", 6, 0)
	body.banner.text = body.banner:CreateFontString(nil, "ARTWORK")
	body.banner.text:SetFontObject(UI.FontSmall)
	body.banner.text:SetPoint("LEFT", 22, 0)
	body.banner.text:SetTextColor(Col.gold[1], Col.gold[2], Col.gold[3])
	body.banner:SetScript("OnClick", function()
		if IsShiftKeyDown() and E.view then E.JumpTo(E.view) else E.Look(0) end
	end)
	UI.Tooltip(body.banner, L["You are looking at another step"], L["Click to go back to your current step. Shift-click to make this step the current one."])

	body.title = body:CreateFontString(nil, "ARTWORK")
	body.title:SetFontObject(UI.FontTitle)
	body.title:SetJustifyH("LEFT")
	body.title:SetWordWrap(true)

	body.tip = body:CreateFontString(nil, "ARTWORK")
	body.tip:SetFontObject(UI.FontSmall)
	body.tip:SetJustifyH("LEFT")
	body.tip:SetWordWrap(true)
	body.tip:SetSpacing(2)

	-- The Now card
	now = CreateFrame("Frame", nil, body)
	now:EnableMouse(true)
	UI.Fill(now, Col.band, 0.9)
	now.edge = now:CreateTexture(nil, "ARTWORK")
	now.edge:SetTexture(UI.WHITE)
	now.edge:SetPoint("TOPLEFT")
	now.edge:SetPoint("BOTTOMLEFT")
	now.edge:SetWidth(2)
	now.edge:SetVertexColor(Col.gold[1], Col.gold[2], Col.gold[3])
	now.icon = UI.Icon(now, "note", 18, "ARTWORK", Col.gold)
	now.icon:SetPoint("TOPLEFT", 10, -9)
	now.box = tickBox(now)
	now.box:SetPoint("TOPRIGHT", -5, -7)
	now.text = now:CreateFontString(nil, "ARTWORK")
	now.text:SetFontObject(UI.FontNow)
	now.text:SetPoint("TOPLEFT", 36, -8)
	now.text:SetJustifyH("LEFT")
	now.text:SetWordWrap(true)
	now.info = now:CreateFontString(nil, "ARTWORK")
	now.info:SetFontObject(UI.FontSmall)
	now.info:SetJustifyH("LEFT")
	now.info:SetWordWrap(true)
	now.info:SetSpacing(2)
	now.bar = countBar(now)
	now.navIcon = UI.Icon(now, "nav", 11, "ARTWORK", Col.place)
	now.where = now:CreateFontString(nil, "ARTWORK")
	now.where:SetFontObject(UI.FontSmall)
	now.where:SetJustifyH("LEFT")
	now.where:SetWordWrap(true)
	now.where:SetTextColor(Col.place[1], Col.place[2], Col.place[3])
	now:SetScript("OnEnter", goalTooltip)
	now:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Catch-up: shown under the card when the route needs a level you have not reached
	body.catch = CreateFrame("Frame", nil, body)
	body.catch:SetHeight(18)
	body.catch.aside = UI.Link(body.catch, "", UI.FontSmall, function() W.SetAside.Toggle(true) end)
	body.catch.aside:SetPoint("LEFT", 34, 0)
	UI.Tooltip(body.catch.aside, L["Quests you set aside"], L["Go back to a quest you saved for later and earn its experience."])
	body.catch.grind = UI.Link(body.catch, L["Nearest enemies your level"], UI.FontSmall, function()
		local spot = E.GrindSpot()
		if not spot then
			W.Print(L["No enemies of your level are known near here on this route."])
			return
		end
		E.SetOverride(spot)
		W.Print((L["The arrow points at %s%s. Type /waypost resume to return to your step."]):format(spot.text or "?",
			spot.mobLevel and (" (" .. (L["level %d"]):format(spot.mobLevel) .. ")") or ""))
	end)
	UI.Tooltip(body.catch.grind, L["Nearest enemies your level"], L["Points the arrow at the closest enemies on this route that are about your level."])

	body.done = CreateFrame("Button", nil, body)
	body.done:SetHeight(16)
	body.done.icon = UI.Icon(body.done, "check", 12, "ARTWORK", Col.good)
	body.done.icon:SetPoint("LEFT", 2, 0)
	body.done.text = body.done:CreateFontString(nil, "ARTWORK")
	body.done.text:SetFontObject(UI.FontSmall)
	body.done.text:SetPoint("LEFT", 22, 0)
	body.done:SetScript("OnClick", function()
		W.opt.ui.showDone = not W.opt.ui.showDone
		SF.Render()
	end)
	UI.Tooltip(body.done, L["Finished in this step"], L["Click to show or hide what you have already done here."])

	body.danger = CreateFrame("Frame", nil, body)
	UI.Fill(body.danger, Col.bad, 0.13)
	body.danger.icon = UI.Icon(body.danger, "warn", 13, "ARTWORK", Col.bad)
	body.danger.icon:SetPoint("TOPLEFT", 6, -5)
	body.danger.text = body.danger:CreateFontString(nil, "ARTWORK")
	body.danger.text:SetFontObject(UI.FontSmall)
	body.danger.text:SetPoint("TOPLEFT", 26, -5)
	body.danger.text:SetJustifyH("LEFT")
	body.danger.text:SetWordWrap(true)
	body.danger.text:SetTextColor(1, 0.72, 0.66)

	body.why = body:CreateFontString(nil, "ARTWORK")
	body.why:SetFontObject(UI.FontSmall)
	body.why:SetJustifyH("LEFT")
	body.why:SetWordWrap(true)
	body.why:SetTextColor(Col.info[1], Col.info[2], Col.info[3])

	body.nextLine = body:CreateTexture(nil, "ARTWORK")
	body.nextLine:SetTexture(UI.WHITE)
	body.nextLine:SetVertexColor(Col.trim[1], Col.trim[2], Col.trim[3], 0.4)
	body.nextLine:SetHeight(1)
	body.nextLabel = body:CreateFontString(nil, "ARTWORK")
	body.nextLabel:SetFontObject(UI.FontSmall)
	body.nextLabel:SetTextColor(Col.muted[1], Col.muted[2], Col.muted[3])
	body.nextLabel:SetText(L["Next"])

	-- Empty state
	body.empty = CreateFrame("Frame", nil, body)
	body.empty.text = body.empty:CreateFontString(nil, "ARTWORK")
	body.empty.text:SetFontObject(UI.FontText)
	body.empty.text:SetPoint("TOPLEFT")
	body.empty.text:SetPoint("TOPRIGHT")
	body.empty.text:SetJustifyH("LEFT")
	body.empty.text:SetWordWrap(true)
	body.empty.text:SetSpacing(3)
	body.empty.start = UI.Button(body.empty, L["Start"], 110, 24, function()
		local m = G.Suggest()
		if m then E.Load(m.id) end
	end)
	body.empty.pick = UI.Button(body.empty, L["All guides"], 110, 24, function() W.Picker.Toggle(true) end)

	-- Footer ------------------------------------------------------------
	footer = CreateFrame("Frame", nil, frame)
	footer:SetHeight(24)
	footer.line = footer:CreateTexture(nil, "ARTWORK")
	footer.line:SetTexture(UI.WHITE)
	footer.line:SetPoint("TOPLEFT")
	footer.line:SetPoint("TOPRIGHT")
	footer.line:SetHeight(1)
	footer.line:SetVertexColor(Col.trim[1], Col.trim[2], Col.trim[3], 0.4)
	footer.prev = UI.IconButton(footer, 11, "left", function() E.Back() end, Col.gold)
	footer.prev:SetPoint("LEFT", PAD - 5, -1)
	UI.Tooltip(footer.prev, L["Previous step"], L["Look back, or return to a step you skipped."])
	footer.next = UI.IconButton(footer, 11, "right", function()
		if IsShiftKeyDown() then E.Look(1) else E.Next() end
	end, Col.gold)
	footer.next:SetPoint("LEFT", footer.prev, "RIGHT", 0, 0)
	UI.Tooltip(footer.next, L["Next step"], L["Finish or skip this step. Shift-click to look ahead without moving on."])
	footer.skip = UI.Link(footer, L["Skip"], UI.FontSmall, function() E.Skip() end)
	footer.skip:SetPoint("LEFT", footer.next, "RIGHT", 4, 0)
	UI.Tooltip(footer.skip, L["Skip this step"], L["Drops it for good: its quests are left out of later steps too. Undo in the menu brings it back. Use Later if you want to return to it."])
	footer.later = UI.Link(footer, L["Later"], UI.FontSmall, function() E.Later() end)
	footer.later:SetPoint("LEFT", footer.skip, "RIGHT", 0, 0)
	UI.Tooltip(footer.later, L["Come back to this later"], L["Sets this step's quests aside. Waypost offers them back when you join a party or gain two levels."])
	footer.why = UI.Link(footer, L["Why?"], UI.FontSmall, function()
		SF.showWhy = not SF.showWhy
		SF.Render()
	end)
	footer.why:SetPoint("LEFT", footer.later, "RIGHT", 0, 0)
	UI.Tooltip(footer.why, L["Why this step"], L["Explains what this step is for."])
	footer.steps = UI.Link(footer, L["Steps"], UI.FontSmall, function() W.Set("ui.listOpen", not W.opt.ui.listOpen) end)
	footer.steps:SetPoint("LEFT", footer.why, "RIGHT", 0, 0)
	UI.Tooltip(footer.steps, L["All steps"], L["Open the full list of steps in this guide."])

	footer.xp = CreateFrame("Button", nil, footer)
	footer.xp:SetHeight(20)
	footer.xp:SetPoint("RIGHT", -PAD - 6, -1)
	footer.xp.text = footer.xp:CreateFontString(nil, "ARTWORK")
	footer.xp.text:SetFontObject(UI.FontSmall)
	footer.xp.text:SetPoint("RIGHT")
	footer.xp:SetScript("OnClick", function()
		if IsShiftKeyDown() then W.XP.ToggleWindow() else W.Tracker.Toggle() end
	end)
	UI.Tooltip(footer.xp, L["Leveling speed"], function() return W.XP.TooltipText() end, "ANCHOR_BOTTOMLEFT")

	-- live XP bar along the bottom edge
	footer.xpbar = CreateFrame("StatusBar", nil, frame)
	footer.xpbar:SetHeight(4)
	footer.xpbar:SetStatusBarTexture(UI.WHITE)
	footer.xpbar:SetStatusBarColor(0.62, 0.32, 0.92)
	footer.xpbar:SetMinMaxValues(0, 1)
	footer.xpbar.bg = footer.xpbar:CreateTexture(nil, "BACKGROUND")
	footer.xpbar.bg:SetTexture(UI.WHITE)
	footer.xpbar.bg:SetAllPoints()
	footer.xpbar.bg:SetVertexColor(0, 0, 0, 0.6)
	footer.xpbar.rested = footer.xpbar:CreateTexture(nil, "ARTWORK", nil, -1)
	footer.xpbar.rested:SetTexture(UI.WHITE)
	footer.xpbar.rested:SetVertexColor(0.3, 0.55, 1, 0.45)
	footer.xpbar:EnableMouse(true)
	footer.xpbar:SetScript("OnMouseUp", function() W.Tracker.Toggle() end)
	UI.Tooltip(footer.xpbar, L["Experience"], function()
		local x = W.XP.Snapshot()
		return ("%d / %d XP (%.1f%%)\n%s"):format(x.cur, x.max, x.pct * 100, L["Click for the live XP tracker."])
	end, "ANCHOR_BOTTOMLEFT")

	-- Resize: drag the corner to change the width
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(14, 14)
	grip:SetPoint("BOTTOMRIGHT", -1, 1)
	grip:SetFrameLevel(frame:GetFrameLevel() + 10)
	grip.icon = UI.Icon(grip, "grip", 10, "OVERLAY", Col.muted)
	grip.icon:SetPoint("CENTER")
	grip:SetScript("OnEnter", function(self)
		self.icon:SetVertexColor(Col.gold[1], Col.gold[2], Col.gold[3])
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Drag to resize"], 1, 0.82, 0)
		GameTooltip:AddLine(L["Double-click to reset the width."], 1, 1, 1)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(Col.muted[1], Col.muted[2], Col.muted[3])
		GameTooltip:Hide()
	end)
	grip:SetScript("OnMouseDown", function(self)
		if W.opt.ui.locked then return end
		local scale = frame:GetEffectiveScale()
		self.startX = GetCursorPosition() / scale
		self.startW = W.opt.ui.width or 320
		self:SetScript("OnUpdate", function()
			local w = floor(self.startW + GetCursorPosition() / scale - self.startX + 0.5)
			w = min(SF.MAX_WIDTH, max(SF.MIN_WIDTH, w))
			if w ~= W.opt.ui.width then
				W.opt.ui.width = w
				SF.Render()
			end
		end)
	end)
	grip:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	grip:SetScript("OnDoubleClick", function()
		W.opt.ui.width = W.defaults.ui.width
		SF.Render()
	end)
	frame.grip = grip

	restorePosition()
end

SF.MIN_WIDTH, SF.MAX_WIDTH = 230, 600

---------------------------------------------------------------------------
-- Step list (below the window)
---------------------------------------------------------------------------
local function buildList()
	list = CreateFrame("Frame", "WaypostStepList", frame)
	list:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
	list:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
	list:SetHeight((W.opt.ui.listRows or 12) * 18 + 12)
	list:EnableMouse(true)
	-- drag the bottom edge to show more or fewer steps
	local lgrip = CreateFrame("Button", nil, list)
	lgrip:SetHeight(8)
	lgrip:SetPoint("BOTTOMLEFT", 20, 0)
	lgrip:SetPoint("BOTTOMRIGHT", -20, 0)
	lgrip.line = lgrip:CreateTexture(nil, "OVERLAY")
	lgrip.line:SetTexture(UI.WHITE)
	lgrip.line:SetSize(30, 2)
	lgrip.line:SetPoint("CENTER")
	lgrip.line:SetVertexColor(Col.muted[1], Col.muted[2], Col.muted[3], 0.8)
	lgrip:SetScript("OnEnter", function(self) self.line:SetVertexColor(Col.gold[1], Col.gold[2], Col.gold[3], 1) end)
	lgrip:SetScript("OnLeave", function(self) self.line:SetVertexColor(Col.muted[1], Col.muted[2], Col.muted[3], 0.8) end)
	lgrip:SetScript("OnMouseDown", function(self)
		if W.opt.ui.locked then return end
		local scale = list:GetEffectiveScale()
		local _, y0 = GetCursorPosition()
		self.startY, self.startRows = y0 / scale, W.opt.ui.listRows or 12
		self:SetScript("OnUpdate", function()
			local _, y = GetCursorPosition()
			local n = floor(self.startRows + (self.startY - y / scale) / 18 + 0.5)
			n = min(40, max(4, n))
			if n ~= W.opt.ui.listRows then
				W.opt.ui.listRows = n
				list:SetHeight(n * 18 + 12)
				list.view.Refresh()
			end
		end)
	end)
	lgrip:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	list.view = UI.VirtualList(list, 18, function(r)
		r.num = r:CreateFontString(nil, "ARTWORK")
		r.num:SetFontObject(UI.FontSmall)
		r.num:SetPoint("LEFT", 2, 0)
		r.num:SetWidth(26)
		r.num:SetJustifyH("RIGHT")
		r.mark = UI.Icon(r, "check", 10, "ARTWORK", Col.good)
		r.mark:SetPoint("LEFT", 32, 0)
		r.text = r:CreateFontString(nil, "ARTWORK")
		r.text:SetFontObject(UI.FontSmall)
		r.text:SetPoint("LEFT", 48, 0)
		r.text:SetPoint("RIGHT", -2, 0)
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r:SetScript("OnClick", function(self)
			local si = self.item
			if not si then return end
			if IsShiftKeyDown() then E.JumpTo(si) else E.Look(si - (E.view or E.index)) end
		end)
		UI.Tooltip(r, function(self) return self.item and E.guide and E.guide.steps[self.item].title end,
			L["Click to look at this step. Shift-click to jump to it."], "ANCHOR_LEFT")
	end, function(r, si)
		local s = E.guide.steps[si]
		r.num:SetText(si)
		r.text:SetText(s.title or "")
		local c, glyph = Col.text, nil
		if si == E.index then c, glyph = Col.gold, "right"
		elseif E.IsSkipped(si) then c, glyph = Col.bad, "skip"
		elseif si < (E.index or 1) then c, glyph = Col.muted, "check" end
		r.text:SetTextColor(c[1], c[2], c[3])
		r.num:SetTextColor(Col.muted[1], Col.muted[2], Col.muted[3])
		r.mark:SetShown(glyph ~= nil)
		if glyph then
			UI.SetIcon(r.mark, glyph)
			local mc = glyph == "check" and Col.good or c
			r.mark:SetVertexColor(mc[1], mc[2], mc[3])
		end
	end)
	list.view:SetPoint("TOPLEFT", 6, -6)
	list.view:SetPoint("BOTTOMRIGHT", -4, 6)
end

function SF.RenderList(center)
	if not list or not list:IsShown() or not E.guide then return end
	if list.shownFor ~= E.guide then
		local shown = {}
		for si = 1, #E.guide.steps do
			if G.OnlyOk(E.guide.steps[si].only) then shown[#shown + 1] = si end
		end
		list.shown, list.shownFor = shown, E.guide
		list.view.SetItems(shown)
	else
		list.view.Refresh()
	end
	if center then
		local cur = E.view or E.index or 1
		for i = 1, #list.shown do
			if list.shown[i] >= cur then list.view.ScrollTo(i) break end
		end
	end
end

---------------------------------------------------------------------------
-- Render
---------------------------------------------------------------------------
local function place(region, y, x)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", body, "TOPLEFT", x or 0, -y)
end

local function renderEmpty(width)
	local m = G.Suggest()
	local e = body.empty
	e:Show()
	e:SetWidth(width)
	place(e, 0)
	if m then
		e.text:SetText((L["Welcome to Waypost.\nThe guide for your character is %s%s|r, levels %d to %d."]):format(
			UI.Hex(Col.gold), m.title or m.id, m.minLevel or 1, m.maxLevel or 60))
		e.start:Show()
	else
		e.text:SetText(L["No guide loaded. Choose one to begin."])
		e.start:Hide()
	end
	local h = e.text:GetStringHeight()
	e.start:ClearAllPoints()
	e.start:SetPoint("TOPLEFT", 0, -h - 10)
	e.pick:ClearAllPoints()
	if m then e.pick:SetPoint("LEFT", e.start, "RIGHT", 6, 0) else e.pick:SetPoint("TOPLEFT", 0, -h - 10) end
	e:SetHeight(h + 38)
	return h + 38
end

-- Fill a goal row; returns its height.
local rowInfo = {}
local function fillRow(r, g, si, done, inner, detail)
	r.goal, r.si = g, si
	local main, sub = E.GoalText(g, si)
	setGlyph(r.icon, g, done, false)
	local manual = g.t ~= "note"
	r.box:SetShown(manual)
	r.box:Set(done)
	r.text:SetWidth(inner - 22 - (manual and 20 or 0))
	r.text:SetText(main)
	r.text:SetAlpha(done and 0.5 or 1)
	local h = r.text:GetStringHeight()
	if detail and not done then
		E.GoalInfo(g, si, rowInfo)
		if #rowInfo > 0 then sub = table.concat(rowInfo, "\n") end
	end
	if sub and not done then
		r.sub:Show()
		r.sub:SetWidth(inner - 22 - 20)
		r.sub:SetText(sub)
		h = h + r.sub:GetStringHeight() + 1
	else
		r.sub:Hide()
	end
	local _, cur, need = E.GoalState(g, si)
	if need and need > 1 and not done then
		r.bar:Show()
		r.bar:ClearAllPoints()
		r.bar:SetPoint("TOPLEFT", 22, -(h + 3))
		r.bar:SetWidth(inner - 22 - 22)
		r.bar:SetValue(min(1, (cur or 0) / need))
		h = h + 6
	else
		r.bar:Hide()
	end
	r:SetSize(inner, h + 1)
	return h
end

-- Fill the Now card; returns its height.
local infoLines = {}
local function fillNow(g, si, inner, lay)
	now.goal, now.si = g, si
	local main = E.GoalText(g, si)
	UI.SetIcon(now.icon, GLYPH[g.t] or "note")
	local c = TINT[g.t] or Col.gold
	now.icon:SetVertexColor(c[1], c[2], c[3])
	now.box:Set(false)
	now.text:SetWidth(inner - 36 - 26)
	now.text:SetText(main)
	local y = 8 + now.text:GetStringHeight()

	E.GoalInfo(g, si, infoLines)
	if lay.info and #infoLines > 0 then
		now.info:Show()
		now.info:ClearAllPoints()
		now.info:SetPoint("TOPLEFT", 36, -(y + 3))
		now.info:SetWidth(inner - 36 - 10)
		now.info:SetText(table.concat(infoLines, "\n"))
		y = y + 3 + now.info:GetStringHeight()
	else
		now.info:Hide()
	end

	local _, cur, need = E.GoalState(g, si)
	if need and need > 1 then
		now.bar:Show()
		now.bar:ClearAllPoints()
		now.bar:SetPoint("TOPLEFT", 36, -(y + 6))
		now.bar:SetWidth(inner - 36 - 12)
		now.bar:SetHeight(4)
		now.bar:SetValue(min(1, (cur or 0) / need))
		y = y + 10
	else
		now.bar:Hide()
	end

	local where = lay.where and whereText(g) or nil
	whereGoal = where and g or nil
	if where then
		now.where:Show()
		now.navIcon:Show()
		now.navIcon:ClearAllPoints()
		now.navIcon:SetPoint("TOPLEFT", 14, -(y + 8))
		now.where:ClearAllPoints()
		now.where:SetPoint("TOPLEFT", 36, -(y + 6))
		now.where:SetWidth(inner - 36 - 10)
		now.where:SetText(where)
		y = y + 6 + now.where:GetStringHeight()
	else
		now.where:Hide()
		now.navIcon:Hide()
	end
	now:SetSize(inner, y + 9)
	return y + 9
end

function SF.Render()
	if not frame or not frame:IsShown() then return end
	local o = W.opt.ui
	local lay = SF.Layout()
	local width = min(SF.MAX_WIDTH, max(SF.MIN_WIDTH, o.width or 320))
	local inner = width - 2 * PAD - 2
	frame:SetWidth(width)
	frame.grip:SetShown(not o.locked)
	footer.xpbar:Hide()

	UI.SetIcon(header.compact.icon, o.layout == "simple" and "plus" or "minus")

	local guide = E.guide
	local y = 0
	for i = 1, #rows do rows[i]:Hide() end
	for i = 1, #nextRows do nextRows[i]:Hide() end
	body.banner:Hide()
	body.tip:Hide()
	now:Hide()
	body.done:Hide()
	body.catch:Hide()
	body.danger:Hide()
	body.why:Hide()
	body.nextLine:Hide()
	body.nextLabel:Hide()
	body.empty:Hide()
	whereGoal = nil

	if not guide or not E.index then
		header.title.text:SetText("Waypost")
		header.count:SetText("")
		bar:SetValue(0)
		body.title:SetText("")
		-- Until the engine has restored the saved guide, show nothing rather than a flash of "pick a guide".
		if E.ready then y = renderEmpty(inner) end
		footer:Hide()
		if list then list:Hide() end
	else
		local si = E.view or E.index
		local step = guide.steps[si]
		header.title.text:SetText(guide.title or guide.id)
		header.count:SetText(("%d / %d"):format(si, #guide.steps))
		bar:SetValue(E.Progress())

		if E.view then
			body.banner:Show()
			body.banner:SetWidth(inner)
			place(body.banner, y)
			body.banner.text:SetText((si > E.index and L["Looking ahead"] or L["Looking back"]) .. ": " .. (L["back to step %d"]):format(E.index))
			y = y + 25
		end

		body.title:SetWidth(inner)
		body.title:SetText(step.title or "")
		place(body.title, y)
		y = y + body.title:GetStringHeight() + 4

		if step.note and lay.tip then
			body.tip:Show()
			body.tip:SetWidth(inner)
			body.tip:SetText(step.note)
			place(body.tip, y)
			y = y + body.tip:GetStringHeight() + 8
		else
			y = y + 3
		end

		-- Goals. A goal that has just been done stays for a moment with its tick, then folds into "done".
		if seenStep ~= step then
			seenStep = step
			for k in pairs(seenDone) do seenDone[k] = nil end
			for _, g in ipairs(E.Visible(step)) do
				if E.GoalState(g, si) then seenDone[g] = 0 end
			end
		end
		local vis = E.Visible(step)
		local past = E.view and si < E.index and not E.IsSkipped(si)
		local current = (not past) and E.Current(si) or nil
		local tnow = GetTime()
		local doneCount, flashing = 0, false

		if current then
			now:Show()
			place(now, y)
			y = y + fillNow(current, si, inner, lay) + 7
			if current.t == "level" and (W.player.level or 1) < (current.level or 1) and not E.view then
				local c = body.catch
				local n = W.SetAside.Count()
				c:Show()
				c:SetWidth(inner)
				place(c, y - 3)
				c.aside:SetShown(n > 0)
				c.aside.text:SetText((L["Quests you set aside (%d)"]):format(n))
				c.aside:SetWidth(c.aside.text:GetStringWidth() + 12)
				c.grind:ClearAllPoints()
				if n > 0 then c.grind:SetPoint("LEFT", c.aside, "RIGHT", 4, 0) else c.grind:SetPoint("LEFT", 34, 0) end
				y = y + 20
			end
		end

		local n = 0
		local function addRow(g, done)
			n = n + 1
			local r = rows[n]
			if not r then
				r = newRow(body)
				rows[n] = r
			end
			local h = fillRow(r, g, si, done, inner, lay.goalInfo)
			place(r, y)
			r:Show()
			y = y + h + 5
		end

		local showDone = lay.done or o.showDone
		for i = 1, #vis do
			local g = vis[i]
			if lay.goals and g ~= current and not (W.opt.route.hideOptional and g.optional) then
				local done = past or E.GoalState(g, si)
				if done then
					if not seenDone[g] then seenDone[g] = tnow end
					local fresh = seenDone[g] > 0 and tnow - seenDone[g] < 1.6
					if fresh then
						flashing = true
						addRow(g, true)
					elseif g.t ~= "note" then
						doneCount = doneCount + 1
						if showDone then addRow(g, true) end
					end
				else
					addRow(g, false)
				end
			end
		end
		if flashing then W.After(1.7, SF.RenderSoon) end

		if doneCount > 0 then
			body.done:Show()
			body.done:SetWidth(inner)
			place(body.done, y)
			body.done.text:SetText((doneCount == 1 and L["1 done"] or (L["%d done"]):format(doneCount))
				.. (showDone and "" or ("  " .. UI.Hex(Col.muted) .. L["show"] .. "|r")))
			y = y + 20
		end

		local danger = lay.danger and E.Danger(step)
		if danger then
			body.danger:Show()
			body.danger:SetWidth(inner)
			body.danger.text:SetWidth(inner - 34)
			body.danger.text:SetText(danger)
			local h = body.danger.text:GetStringHeight() + 10
			body.danger:SetHeight(h)
			place(body.danger, y + 2)
			y = y + h + 7
		end

		if lay.why or SF.showWhy then
			body.why:Show()
			body.why:SetWidth(inner)
			body.why:SetText(E.Why(si) or "")
			place(body.why, y + 2)
			y = y + body.why:GetStringHeight() + 8
		end

		-- What comes next, with how far away its first stop is
		local showNext = lay.next or 0
		if showNext > 0 then
			local sj, k = si + 1, 0
			while k < showNext and guide.steps[sj] do
				local s = guide.steps[sj]
				if G.OnlyOk(s.only) and not E.IsSkipped(sj) then
					if k == 0 then
						body.nextLine:Show()
						body.nextLine:ClearAllPoints()
						body.nextLine:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 2))
						body.nextLine:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(y + 2))
						y = y + 8
					end
					k = k + 1
					local r = nextRows[k]
					if not r then
						r = CreateFrame("Button", nil, body)
						r.label = r:CreateFontString(nil, "ARTWORK")
						r.label:SetFontObject(UI.FontSmall)
						r.label:SetPoint("LEFT", 0, 0)
						r.label:SetWidth(34)
						r.label:SetJustifyH("LEFT")
						r.label:SetTextColor(Col.muted[1], Col.muted[2], Col.muted[3])
						r.dist = r:CreateFontString(nil, "ARTWORK")
						r.dist:SetFontObject(UI.FontSmall)
						r.dist:SetPoint("RIGHT", 0, 0)
						r.dist:SetTextColor(Col.muted[1], Col.muted[2], Col.muted[3])
						r.text = r:CreateFontString(nil, "ARTWORK")
						r.text:SetFontObject(UI.FontSmall)
						r.text:SetPoint("LEFT", 36, 0)
						r.text:SetPoint("RIGHT", r.dist, "LEFT", -6, 0)
						r.text:SetJustifyH("LEFT")
						r.text:SetWordWrap(false)
						r:SetScript("OnClick", function(self) E.Look(self.si - (E.view or E.index)) end)
						r:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
						r:SetScript("OnLeave", function(self) self.text:SetTextColor(Col.dim[1], Col.dim[2], Col.dim[3]) end)
						nextRows[k] = r
					end
					r.si = sj
					r.label:SetText(k == 1 and L["Next"] or "")
					r.text:SetTextColor(Col.dim[1], Col.dim[2], Col.dim[3])
					r.text:SetText(s.title or "")
					r.first = nil
					for _, g in ipairs(E.Visible(s)) do
						if g.x and g.map then r.first = g break end
					end
					local d = r.first and C.GoalDistance(r.first)
					r.dist:SetText(d and distanceText(d) or "")
					r:SetSize(inner, 15)
					place(r, y)
					r:Show()
					y = y + 16
				end
				sj = sj + 1
			end
		end

		footer:SetShown(lay.footer and true or false)
		if lay.footer then
			footer:ClearAllPoints()
			footer:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(1 + HEADER + 2 + 8 + y + 4))
			footer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(1 + HEADER + 2 + 8 + y + 4))
			local xp = W.XP.ShortText()
			footer.xp.text:SetText(xp)
			footer.xp:SetWidth(max(10, footer.xp.text:GetStringWidth() + 4))
			local links = 44 + footer.skip:GetWidth() + footer.later:GetWidth() + footer.why:GetWidth() + footer.steps:GetWidth()
			footer.steps:SetShown(links + footer.xp:GetWidth() + 2 * PAD < width)
			footer.why.text:SetTextColor(SF.showWhy and 1 or Col.gold[1], SF.showWhy and 1 or Col.gold[2], SF.showWhy and 1 or Col.gold[3])
			y = y + 4 + 24 - 6
		end

		if lay.xpbar then
			footer.xpbar:Show()
			footer.xpbar:ClearAllPoints()
			footer.xpbar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(1 + HEADER + 2 + 8 + y + 6))
			footer.xpbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -(1 + HEADER + 2 + 8 + y + 6))
			SF.UpdateXPBar()
			y = y + 8
		end

		if o.listOpen and o.layout ~= "simple" then
			if not list then buildList() end
			local sk = UI.Skin(o.skin)
			UI.Fill(list, Col.bg, max(0.6, sk.fill))
			UI.Trim(list, Col.trim, max(0.4, sk.trim))
			list:SetHeight((o.listRows or 12) * 18 + 12)
			list:Show()
			SF.RenderList(true)
		elseif list then
			list:Hide()
		end
	end

	body:SetHeight(max(1, y))
	frame:SetHeight(1 + HEADER + 2 + 8 + y + 8)
end

local renderSoon = W.Throttle(0.05, function() SF.Render() end)
SF.RenderSoon = renderSoon

function SF.UpdateXPBar()
	if not frame or not footer.xpbar:IsShown() then return end
	local x = W.XP.Snapshot()
	footer.xpbar:SetValue(min(1, x.pct))
	local w = footer.xpbar:GetWidth()
	local rb = footer.xpbar.rested
	if x.rested > 0 and x.max > 0 then
		local from, to = w * min(1, x.pct), w * min(1, (x.cur + x.rested) / x.max)
		rb:ClearAllPoints()
		rb:SetPoint("TOPLEFT", footer.xpbar, "TOPLEFT", from, 0)
		rb:SetPoint("BOTTOMLEFT", footer.xpbar, "BOTTOMLEFT", from, 0)
		rb:SetWidth(max(1, to - from))
		rb:Show()
	else
		rb:Hide()
	end
end

-- Twice a second: refresh the distance and direction texts and the live XP figures.
local function tickWhere()
	if not frame or not frame:IsShown() then return end
	if footer:IsShown() then
		footer.xp.text:SetText(W.XP.ShortText())
		footer.xp:SetWidth(max(10, footer.xp.text:GetStringWidth() + 4))
	end
	if W.InCombat() and not W.opt.combatUpdates then return end
	if whereGoal and now:IsShown() then
		local t = whereText(whereGoal)
		if t then now.where:SetText(t) end
	end
	for i = 1, #nextRows do
		local r = nextRows[i]
		if r:IsShown() and r.first then
			local d = C.GoalDistance(r.first)
			r.dist:SetText(d and distanceText(d) or "")
		end
	end
end

function SF.ApplyStyle()
	if not frame then return end
	local o = W.opt.ui
	local sk = UI.Skin(o.skin)
	frame.fill:SetVertexColor(Col.bg[1], Col.bg[2], Col.bg[3], sk.fill)
	UI.Trim(frame, Col.trim, sk.trim)
	header.band:SetVertexColor(Col.band[1], Col.band[2], Col.band[3], sk.band)
	frame:SetScale(o.scale or 1)
	frame:SetAlpha(o.alpha or 1)
	UI.ApplyFonts()
	SF.Render()
end

function SF.Toggle(show)
	if not frame then return end
	if show == nil then show = not frame:IsShown() end
	W.opt.ui.hidden = not show
	frame:SetShown(show)
	if show then SF.Render() end
	W.Fire("WP_VISIBILITY", show)
end

function SF.ResetPosition()
	W.opt.ui.pos = nil
	restorePosition()
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------
W.On("WP_LOGIN", function()
	build()
	frame:SetShown(not W.opt.ui.hidden)
	SF.ApplyStyle()
	if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.5, tickWhere) end
end)

for _, ev in ipairs({ "WP_STEP", "WP_PROGRESS", "WP_GUIDE", "WP_GUIDES_CHANGED", "WP_XP", "WP_ENGINE_READY", "WP_LEVEL", "WP_SET_ASIDE" }) do
	W.On(ev, renderSoon)
end
W.On("WP_SETTINGS", function(path)
	if not frame then return end
	if path == "*" or (type(path) == "string" and (path:find("^ui") or path:find("^route"))) then
		if path == "*" then restorePosition() end
		SF.ApplyStyle()
	end
end)
W.On("WP_XP", function() if frame then SF.UpdateXPBar() end end)
W.On("WP_COMBAT_STARTED", function()
	if frame and W.opt.ui.hideInCombat and frame:IsShown() then
		frame.combatHidden = true
		frame:Hide()
	end
end)
W.On("WP_COMBAT_ENDED", function()
	if frame and frame.combatHidden then
		frame.combatHidden = nil
		frame:SetShown(not W.opt.ui.hidden)
		SF.Render()
	end
end)
