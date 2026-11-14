-- The guide window: current step, its goals, what comes next.
-- Renders only when the engine says something changed (never per frame).

local W = Waypost
local L = W.L
local UI, E, G, C = W.UI, W.Engine, W.Guides, W.Coords

local SF = {}
W.StepFrame = SF

local PAD = 10
local ICONS = {
	accept = "Interface\\GossipFrame\\AvailableQuestIcon",
	turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
	complete = "Interface\\GossipFrame\\ActiveQuestIcon",
	kill = "Interface\\Icons\\Ability_DualWield",
	collect = "Interface\\Icons\\INV_Misc_Bag_08",
	buy = "Interface\\GossipFrame\\VendorGossipIcon",
	vendor = "Interface\\GossipFrame\\VendorGossipIcon",
	use = "Interface\\Icons\\INV_Misc_Gear_01",
	interact = "Interface\\Icons\\INV_Misc_Gear_01",
	talk = "Interface\\GossipFrame\\GossipGossipIcon",
	["goto"] = "Interface\\Icons\\Ability_Tracking",
	enter = "Interface\\Icons\\Ability_Tracking",
	explore = "Interface\\Icons\\INV_Misc_Map_01",
	level = "Interface\\Icons\\Spell_Holy_PowerInfusion",
	train = "Interface\\GossipFrame\\TrainerGossipIcon",
	learn = "Interface\\GossipFrame\\TrainerGossipIcon",
	skill = "Interface\\GossipFrame\\TrainerGossipIcon",
	craft = "Interface\\Icons\\Trade_BlackSmithing",
	fly = "Interface\\GossipFrame\\TaxiGossipIcon",
	getfp = "Interface\\GossipFrame\\TaxiGossipIcon",
	sethome = "Interface\\GossipFrame\\BinderGossipIcon",
	hearth = "Interface\\Icons\\INV_Misc_Rune_01",
	money = "Interface\\Icons\\INV_Misc_Coin_01",
	rep = "Interface\\Icons\\Achievement_Reputation_01",
	die = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull",
	note = "Interface\\GossipFrame\\GossipGossipIcon",
}
local ICON_FILE = { kill = 1, collect = 1, use = 1, interact = 1, ["goto"] = 1, enter = 1, explore = 1, level = 1, craft = 1, hearth = 1, money = 1, rep = 1 }
SF.ICONS = ICONS
SF.ICON_FILE = ICON_FILE
local CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"

local frame, header, body, footer, bar, list
local rows, nextRows = {}, {}

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
local function savePosition()
	local left, top = frame:GetLeft(), frame:GetTop()
	if not left then return end
	W.opt.ui.pos = { x = left, y = top }
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
-- Rows
---------------------------------------------------------------------------
local function rowTooltip(self)
	local g = self.goal
	if not g then return end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText((E.GoalText(g)), 1, 0.82, 0, 1, true)
	if g.npc then GameTooltip:AddLine(g.npc, 1, 1, 1) end
	if g.map and g.x then
		GameTooltip:AddLine(("%s  %s"):format(C.MapName(g.map), C.Format(g.x, g.y)), 0.7, 0.7, 0.7)
	end
	if g.note then GameTooltip:AddLine(g.note, 0.9, 0.9, 0.8, true) end
	if g.quest then GameTooltip:AddLine(L["Quest"] .. " #" .. g.quest, 0.5, 0.5, 0.5) end
	if not E.view then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Click to tick this off by hand."], 0.4, 0.8, 1)
	end
	GameTooltip:Show()
end

local function newRow(parent)
	local r = CreateFrame("Button", nil, parent)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(15, 15)
	r.icon:SetPoint("TOPLEFT", 0, -1)
	r.text = r:CreateFontString(nil, "ARTWORK")
	r.text:SetFontObject(UI.FontText)
	r.text:SetPoint("TOPLEFT", 20, 0)
	r.text:SetJustifyH("LEFT")
	r.text:SetJustifyV("TOP")
	r.text:SetWordWrap(true)
	r.sub = r:CreateFontString(nil, "ARTWORK")
	r.sub:SetFontObject(UI.FontSmall)
	r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -1)
	r.sub:SetJustifyH("LEFT")
	r.sub:SetWordWrap(true)
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r:GetHighlightTexture():SetAlpha(0.35)
	r:SetScript("OnEnter", rowTooltip)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r:RegisterForClicks("LeftButtonUp")
	r:SetScript("OnClick", function(self)
		if self.goal and not E.view then E.ToggleGoal(self.goal) end
	end)
	return r
end

local function setIcon(tex, t, done)
	if done then
		tex:SetTexture(CHECK)
		tex:SetTexCoord(0, 1, 0, 1)
		tex:SetVertexColor(1, 1, 1)
		return
	end
	tex:SetTexture(ICONS[t] or ICONS.note)
	if ICON_FILE[t] then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) else tex:SetTexCoord(0, 1, 0, 1) end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function headerButton(tex, coords, tip, body2, onClick)
	local b = UI.IconButton(header, 16, tex, nil, nil, onClick, coords)
	UI.Tooltip(b, tip, body2, "ANCHOR_BOTTOMLEFT")
	return b
end

local function build()
	frame = CreateFrame("Frame", "WaypostFrame", UIParent, "BackdropTemplate")
	SF.frame = frame
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		if not W.opt.ui.locked then self:StartMoving() end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
		restorePosition()
	end)

	-- Header ------------------------------------------------------------
	header = CreateFrame("Frame", nil, frame)
	header:SetHeight(20)
	header.logo = header:CreateTexture(nil, "ARTWORK")
	header.logo:SetTexture(UI.MEDIA .. "Logo")
	header.logo:SetSize(18, 18)
	header.logo:SetPoint("LEFT", 0, 0)

	header.close = UI.IconButton(header, 20, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
		"Interface\\Buttons\\UI-Panel-MinimizeButton-Down", "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
		function() SF.Toggle(false) end)
	header.close:SetPoint("RIGHT", 5, 0)
	UI.Tooltip(header.close, L["Hide Waypost"], L["Type /waypost or click the minimap button to bring it back."], "ANCHOR_BOTTOMLEFT")

	header.compact = headerButton("Interface\\Buttons\\UI-MinusButton-Up", nil, L["Compact mode"],
		L["Show only the current step."], function()
			W.Set("ui.compact", not W.opt.ui.compact)
		end)
	header.compact:SetPoint("RIGHT", header.close, "LEFT", 1, 0)

	header.options = headerButton("Interface\\Icons\\Trade_Engineering", { 0.08, 0.92, 0.08, 0.92 }, L["Settings"], nil,
		function() W.Options.Toggle() end)
	header.options:SetPoint("RIGHT", header.compact, "LEFT", -4, 0)

	header.guides = headerButton("Interface\\Icons\\INV_Misc_Book_09", { 0.08, 0.92, 0.08, 0.92 }, L["Guides"],
		L["Choose or change your guide."], function() W.Picker.Toggle() end)
	header.guides:SetPoint("RIGHT", header.options, "LEFT", -4, 0)

	header.count = header:CreateFontString(nil, "ARTWORK")
	header.count:SetFontObject(UI.FontSmall)
	header.count:SetPoint("RIGHT", header.guides, "LEFT", -6, 0)

	header.title = header:CreateFontString(nil, "ARTWORK")
	header.title:SetFontObject(UI.FontGold)
	header.title:SetPoint("LEFT", header.logo, "RIGHT", 5, 0)
	header.title:SetPoint("RIGHT", header.count, "LEFT", -6, 0)
	header.title:SetJustifyH("LEFT")
	header.title:SetWordWrap(false)

	-- Guide progress bar ------------------------------------------------
	bar = CreateFrame("StatusBar", nil, frame)
	bar:SetHeight(5)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.95, 0.72, 0.1)
	bar:SetMinMaxValues(0, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0, 0, 0, 0.6)
	bar:EnableMouse(true)
	UI.Tooltip(bar, function()
		if not E.guide then return nil end
		return ("%s: %d%%"):format(E.guide.title or "", math.floor(E.Progress() * 100 + 0.5))
	end, function()
		if not E.guide then return nil end
		return (L["Step %d of %d"]):format(E.index or 0, #E.guide.steps)
	end, "ANCHOR_BOTTOMLEFT")

	-- Body --------------------------------------------------------------
	body = CreateFrame("Frame", nil, frame)

	body.preview = CreateFrame("Button", nil, body)
	body.preview:SetHeight(18)
	body.preview.bg = body.preview:CreateTexture(nil, "BACKGROUND")
	body.preview.bg:SetAllPoints()
	body.preview.bg:SetColorTexture(1, 0.82, 0, 0.14)
	body.preview.text = body.preview:CreateFontString(nil, "ARTWORK")
	body.preview.text:SetFontObject(UI.FontSmall)
	body.preview.text:SetPoint("CENTER")
	body.preview.text:SetTextColor(1, 0.82, 0)
	UI.Tooltip(body.preview, L["Looking ahead"], L["Click to return to your current step. Shift-click to make this step the current one."])
	body.preview:SetScript("OnClick", function()
		if IsShiftKeyDown() and E.view then E.JumpTo(E.view) else E.Look(0) end
	end)

	body.title = body:CreateFontString(nil, "ARTWORK")
	body.title:SetFontObject(UI.FontTitle)
	body.title:SetJustifyH("LEFT")
	body.title:SetWordWrap(true)

	body.note = body:CreateFontString(nil, "ARTWORK")
	body.note:SetFontObject(UI.FontSmall)
	body.note:SetJustifyH("LEFT")
	body.note:SetWordWrap(true)
	body.note:SetTextColor(0.93, 0.89, 0.78)

	body.danger = CreateFrame("Frame", nil, body)
	body.danger.icon = body.danger:CreateTexture(nil, "ARTWORK")
	body.danger.icon:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
	body.danger.icon:SetSize(14, 14)
	body.danger.icon:SetPoint("TOPLEFT", 0, 0)
	body.danger.text = body.danger:CreateFontString(nil, "ARTWORK")
	body.danger.text:SetFontObject(UI.FontSmall)
	body.danger.text:SetPoint("TOPLEFT", 20, 0)
	body.danger.text:SetJustifyH("LEFT")
	body.danger.text:SetWordWrap(true)
	body.danger.text:SetTextColor(1, 0.35, 0.3)

	body.why = body:CreateFontString(nil, "ARTWORK")
	body.why:SetFontObject(UI.FontSmall)
	body.why:SetJustifyH("LEFT")
	body.why:SetWordWrap(true)
	body.why:SetTextColor(0.55, 0.8, 1)

	body.nextLabel = body:CreateFontString(nil, "ARTWORK")
	body.nextLabel:SetFontObject(UI.FontSmall)
	body.nextLabel:SetTextColor(0.6, 0.55, 0.4)
	body.nextLine = body:CreateTexture(nil, "ARTWORK")
	body.nextLine:SetColorTexture(1, 0.82, 0, 0.18)
	body.nextLine:SetHeight(1)

	-- Empty state
	body.empty = CreateFrame("Frame", nil, body)
	body.empty.text = body.empty:CreateFontString(nil, "ARTWORK")
	body.empty.text:SetFontObject(UI.FontText)
	body.empty.text:SetPoint("TOPLEFT")
	body.empty.text:SetPoint("TOPRIGHT")
	body.empty.text:SetJustifyH("LEFT")
	body.empty.text:SetWordWrap(true)
	body.empty.start = UI.Button(body.empty, L["Start"], 110, 22, function()
		local m = G.Suggest()
		if m then E.Load(m.id) end
	end)
	body.empty.pick = UI.Button(body.empty, L["All guides"], 110, 22, function() W.Picker.Toggle(true) end)

	-- Footer ------------------------------------------------------------
	footer = CreateFrame("Frame", nil, frame)
	footer:SetHeight(22)
	footer.prev = UI.IconButton(footer, 24, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up",
		"Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down", nil, function() E.Back() end)
	footer.prev:SetPoint("LEFT", -4, 0)
	UI.Tooltip(footer.prev, L["Previous step"], L["Look back, or return to a step you skipped."])
	footer.next = UI.IconButton(footer, 24, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
		"Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down", nil, function()
			if IsShiftKeyDown() then E.Look(1) else E.Next() end
		end)
	footer.next:SetPoint("LEFT", footer.prev, "RIGHT", -2, 0)
	UI.Tooltip(footer.next, L["Next step"], L["Finish or skip this step. Shift-click to look ahead without moving on."])

	local function textButton(label, tip, tipBody, onClick)
		local b = CreateFrame("Button", nil, footer)
		b.text = b:CreateFontString(nil, "ARTWORK")
		b.text:SetFontObject(UI.FontSmall)
		b.text:SetPoint("CENTER")
		b.text:SetText(label)
		b.text:SetTextColor(1, 0.82, 0)
		b:SetSize(b.text:GetStringWidth() + 10, 18)
		b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
		b:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 0.82, 0) end)
		b:SetScript("OnClick", onClick)
		UI.Tooltip(b, tip, tipBody)
		return b
	end
	footer.skip = textButton(L["Skip"], L["Skip this step"], L["Its quests are left out of later steps too. Undo with /waypost undo."], function() E.Skip() end)
	footer.skip:SetPoint("LEFT", footer.next, "RIGHT", 2, 0)
	footer.why = textButton(L["Why?"], L["Why this step"], L["Explains what this step is for."], function()
		SF.showWhy = not SF.showWhy
		SF.Render()
	end)
	footer.why:SetPoint("LEFT", footer.skip, "RIGHT", 0, 0)
	footer.list = textButton(L["Steps"], L["All steps"], L["Open the full list of steps in this guide."], function()
		W.Set("ui.listOpen", not W.opt.ui.listOpen)
	end)
	footer.list:SetPoint("LEFT", footer.why, "RIGHT", 0, 0)

	footer.xp = footer:CreateFontString(nil, "ARTWORK")
	footer.xp:SetFontObject(UI.FontSmall)
	footer.xp:SetPoint("RIGHT", 0, 0)
	footer.xp:SetJustifyH("RIGHT")
	footer.xpHit = CreateFrame("Button", nil, footer)
	footer.xpHit:SetPoint("TOPLEFT", footer.xp, -2, 4)
	footer.xpHit:SetPoint("BOTTOMRIGHT", footer.xp, 2, -4)
	footer.xpHit:SetScript("OnClick", function() if W.XP then W.XP.ToggleWindow() end end)
	UI.Tooltip(footer.xpHit, L["Leveling speed"], function() return W.XP and W.XP.TooltipText() or nil end, "ANCHOR_BOTTOMLEFT")

	restorePosition()
end

---------------------------------------------------------------------------
-- Step list (collapsible)
---------------------------------------------------------------------------
local LIST_ROWS, LIST_H = 12, 17
local function buildList()
	list = CreateFrame("Frame", "WaypostStepList", frame, "BackdropTemplate")
	list:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 2)
	list:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 2)
	list:SetHeight(LIST_ROWS * LIST_H + 16)
	list:EnableMouse(true)
	list.rows = {}
	list.offset = 0
	for i = 1, LIST_ROWS do
		local r = CreateFrame("Button", nil, list)
		r:SetHeight(LIST_H)
		r:SetPoint("TOPLEFT", 8, -8 - (i - 1) * LIST_H)
		r:SetPoint("TOPRIGHT", -22, -8 - (i - 1) * LIST_H)
		r.num = r:CreateFontString(nil, "ARTWORK")
		r.num:SetFontObject(UI.FontSmall)
		r.num:SetPoint("LEFT", 0, 0)
		r.num:SetWidth(28)
		r.num:SetJustifyH("RIGHT")
		r.text = r:CreateFontString(nil, "ARTWORK")
		r.text:SetFontObject(UI.FontSmall)
		r.text:SetPoint("LEFT", 34, 0)
		r.text:SetPoint("RIGHT", 0, 0)
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		r:SetScript("OnClick", function(self)
			if not self.si then return end
			if IsShiftKeyDown() then E.JumpTo(self.si) else E.Look(self.si - (E.view or E.index)) end
		end)
		UI.Tooltip(r, function(self) return self.si and E.guide and E.guide.steps[self.si].title end,
			L["Click to look at this step. Shift-click to jump to it."], "ANCHOR_LEFT")
		list.rows[i] = r
	end
	local bar2 = CreateFrame("Slider", nil, list, "BackdropTemplate")
	bar2:SetOrientation("VERTICAL")
	bar2:SetWidth(12)
	bar2:SetPoint("TOPRIGHT", -7, -9)
	bar2:SetPoint("BOTTOMRIGHT", -7, 9)
	bar2:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
	bar2:SetBackdropColor(0, 0, 0, 0.4)
	bar2:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	bar2:GetThumbTexture():SetSize(16, 20)
	bar2:GetThumbTexture():SetTexCoord(0.2, 0.8, 0.125, 0.875)
	bar2:SetValueStep(1)
	bar2:SetMinMaxValues(0, 0)
	bar2:SetValue(0)
	bar2:SetScript("OnValueChanged", function(_, v)
		list.offset = math.floor(v + 0.5)
		SF.RenderList()
	end)
	list.bar = bar2
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta)
		local lo, hi = bar2:GetMinMaxValues()
		bar2:SetValue(math.max(lo, math.min(hi, bar2:GetValue() - delta * 3)))
	end)
end

function SF.RenderList(center)
	if not list or not list:IsShown() or not E.guide then return end
	local steps = E.guide.steps
	-- Only the steps that apply to this character are listed.
	local shown = list.shown or {}
	list.shown = shown
	if list.shownFor ~= E.guide then
		for k in pairs(shown) do shown[k] = nil end
		for si = 1, #steps do
			if G.OnlyOk(steps[si].only) then shown[#shown + 1] = si end
		end
		list.shownFor = E.guide
	end
	local maxOffset = math.max(0, #shown - LIST_ROWS)
	list.bar:SetMinMaxValues(0, maxOffset)
	if center then
		local cur = E.view or E.index or 1
		local pos = 1
		for i = 1, #shown do if shown[i] >= cur then pos = i break end end
		local want = math.max(0, math.min(maxOffset, pos - 3))
		if want ~= list.offset then
			list.offset = want
			list.bar:SetValue(want)
			return
		end
	end
	for i = 1, LIST_ROWS do
		local r = list.rows[i]
		local si = shown[i + list.offset]
		r.si = si
		if si then
			local s = steps[si]
			r.num:SetText(si)
			r.text:SetText(s.title or "")
			if si == E.index then
				r.text:SetTextColor(1, 0.82, 0)
				r.num:SetTextColor(1, 0.82, 0)
			elseif E.IsSkipped(si) then
				r.text:SetTextColor(0.75, 0.35, 0.3)
				r.num:SetTextColor(0.75, 0.35, 0.3)
			elseif si < (E.index or 1) then
				r.text:SetTextColor(0.45, 0.45, 0.45)
				r.num:SetTextColor(0.45, 0.45, 0.45)
			else
				r.text:SetTextColor(0.9, 0.9, 0.9)
				r.num:SetTextColor(0.6, 0.6, 0.6)
			end
			r:Show()
		else
			r:Hide()
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
		e.text:SetText((L["Welcome to Waypost.\nRecommended for you: |cffffd100%s|r |cff9d9d9d(levels %d-%d)|r"]):format(
			m.title or m.id, m.minLevel or 1, m.maxLevel or 60))
		e.start:Show()
	else
		e.text:SetText(L["No guide loaded. Choose one to begin."])
		e.start:Hide()
	end
	local h = e.text:GetStringHeight()
	e.start:ClearAllPoints()
	e.start:SetPoint("TOPLEFT", 0, -h - 8)
	e.pick:ClearAllPoints()
	if m then e.pick:SetPoint("LEFT", e.start, "RIGHT", 6, 0) else e.pick:SetPoint("TOPLEFT", 0, -h - 8) end
	e:SetHeight(h + 34)
	return h + 34
end

function SF.Render()
	if not frame or not frame:IsShown() then return end
	local o = W.opt.ui
	local inset = frame.wpInset or 4
	local width = o.width or 300
	local inner = width - 2 * (PAD + inset - 4)
	local x0 = PAD + inset - 4
	frame:SetWidth(width)

	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", x0, -(inset + 4))
	header:SetPoint("TOPRIGHT", -x0, -(inset + 4))
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
	bar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -3)
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -7)
	body:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -7)

	header.compact:SetNormalTexture(o.compact and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")

	local guide = E.guide
	local y = 0
	for i = 1, #rows do rows[i]:Hide() end
	for i = 1, #nextRows do nextRows[i]:Hide() end
	body.preview:Hide()
	body.danger:Hide()
	body.why:Hide()
	body.nextLabel:Hide()
	body.nextLine:Hide()
	body.empty:Hide()

	if not guide or not E.index then
		header.title:SetText("Waypost")
		header.count:SetText("")
		bar:SetValue(0)
		body.title:SetText("")
		body.note:SetText("")
		-- Until the engine has restored the saved guide, show nothing rather than a flash of "pick a guide".
		if E.ready then y = renderEmpty(inner) end
		footer:Hide()
		if list then list:Hide() end
	else
		local si = E.view or E.index
		local step = guide.steps[si]
		header.title:SetText(guide.title or guide.id)
		header.count:SetText(("%d/%d"):format(si, #guide.steps))
		bar:SetValue(E.Progress())

		if E.view then
			body.preview:Show()
			body.preview:SetWidth(inner)
			place(body.preview, y)
			body.preview.text:SetText((si > E.index and L["Looking ahead"] or L["Looking back"]) .. "  -  " .. L["click to return"])
			y = y + 22
		end

		body.title:SetWidth(inner)
		body.title:SetText(step.title or "")
		place(body.title, y)
		y = y + body.title:GetStringHeight() + 3

		if step.note and not o.compact then
			body.note:Show()
			body.note:SetWidth(inner)
			body.note:SetText(step.note)
			place(body.note, y)
			y = y + body.note:GetStringHeight() + 6
		else
			body.note:Hide()
			y = y + 2
		end

		local vis = E.Visible(step)
		local n = 0
		local past = (not E.view) and false or (si < E.index and not E.IsSkipped(si))
		for i = 1, #vis do
			local g = vis[i]
			local done = past or E.GoalState(g, si)
			if not (o.compact and done) and not (W.opt.route.hideOptional and g.optional) then
				n = n + 1
				local r = rows[n]
				if not r then
					r = newRow(body)
					rows[n] = r
				end
				r.goal = g
				local main, sub = E.GoalText(g, si)
				setIcon(r.icon, g.t, done)
				r.text:SetWidth(inner - 20)
				r.text:SetText(main)
				r.text:SetAlpha(done and 0.45 or 1)
				local h = r.text:GetStringHeight()
				if sub and not done and not o.compact then
					r.sub:Show()
					r.sub:SetWidth(inner - 20)
					r.sub:SetText(sub)
					h = h + r.sub:GetStringHeight() + 1
				else
					r.sub:Hide()
				end
				r:SetSize(inner, h + 1)
				place(r, y)
				r:Show()
				y = y + h + 4
			end
		end

		local danger = E.Danger(step)
		if danger then
			body.danger:Show()
			body.danger:SetWidth(inner)
			body.danger.text:SetWidth(inner - 20)
			body.danger.text:SetText(danger)
			local h = body.danger.text:GetStringHeight()
			body.danger:SetHeight(h)
			place(body.danger, y + 2)
			y = y + h + 6
		end

		if SF.showWhy and not o.compact then
			body.why:Show()
			body.why:SetWidth(inner)
			body.why:SetText(E.Why(si) or "")
			place(body.why, y + 2)
			y = y + body.why:GetStringHeight() + 6
		end

		-- Upcoming steps
		local showNext = o.compact and 0 or (o.showNext or 3)
		if showNext > 0 then
			local sj, k = si + 1, 0
			while k < showNext and guide.steps[sj] do
				local s = guide.steps[sj]
				if G.OnlyOk(s.only) and not E.IsSkipped(sj) then
					if k == 0 then
						body.nextLine:Show()
						body.nextLine:ClearAllPoints()
						body.nextLine:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 3))
						body.nextLine:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(y + 3))
						y = y + 9
					end
					k = k + 1
					local r = nextRows[k]
					if not r then
						r = CreateFrame("Button", nil, body)
						r.text = r:CreateFontString(nil, "ARTWORK")
						r.text:SetFontObject(UI.FontSmall)
						r.text:SetPoint("LEFT")
						r.text:SetPoint("RIGHT")
						r.text:SetJustifyH("LEFT")
						r.text:SetWordWrap(false)
						r.text:SetTextColor(0.62, 0.6, 0.55)
						r:SetScript("OnClick", function(self) E.Look(self.si - (E.view or E.index)) end)
						r:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
						r:SetScript("OnLeave", function(self) self.text:SetTextColor(0.62, 0.6, 0.55) end)
						nextRows[k] = r
					end
					r.si = sj
					r.text:SetText(("%d.  %s"):format(sj, s.title or ""))
					r:SetSize(inner, 14)
					place(r, y)
					r:Show()
					y = y + 15
				end
				sj = sj + 1
			end
		end

		footer:SetShown(not o.compact)
		if not o.compact then
			footer:ClearAllPoints()
			footer:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(y + 4))
			footer:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(y + 4))
			footer.xp:SetText(W.XP and W.XP.ShortText() or "")
			footer.why.text:SetAlpha(SF.showWhy and 1 or 0.85)
			y = y + 26
		end

		if o.listOpen and not o.compact then
			if not list then buildList() end
			UI.Backdrop(list, o.skin, 1)
			list:Show()
			SF.RenderList(true)
		elseif list then
			list:Hide()
		end
	end

	body:SetHeight(math.max(1, y))
	frame:SetHeight(inset + 4 + 20 + 3 + 5 + 7 + y + inset + 4)
end

local renderSoon = W.Throttle(0.05, function() SF.Render() end)
SF.RenderSoon = renderSoon

function SF.ApplyStyle()
	if not frame then return end
	local o = W.opt.ui
	UI.Backdrop(frame, o.skin, 1)
	frame:SetScale(o.scale or 1)
	frame:SetAlpha(o.alpha or 1)
	frame:EnableMouse(true)
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
	UI.ApplyFonts()
	frame:SetShown(not W.opt.ui.hidden)
	SF.ApplyStyle()
end)

for _, ev in ipairs({ "WP_STEP", "WP_PROGRESS", "WP_GUIDE", "WP_GUIDES_CHANGED", "WP_XP", "WP_ENGINE_READY", "WP_LEVEL" }) do
	W.On(ev, renderSoon)
end
W.On("WP_SETTINGS", function(path)
	if not frame then return end
	if path == "*" or (type(path) == "string" and (path:find("^ui") or path:find("^route"))) then
		if path == "*" then restorePosition() end
		SF.ApplyStyle()
	end
end)
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
