-- Look and widgets. Everything is built from the game's own art (dialog
-- borders, red panel buttons, gold header text, tooltip frames) so Waypost
-- reads as part of the default interface rather than a web page on top of it.

local W = Waypost
local L = W.L
local UI = {}
W.UI = UI

local MEDIA = "Interface\\AddOns\\Waypost\\Media\\"
UI.MEDIA = MEDIA

UI.GOLD = { 1, 0.82, 0 }
UI.WHITE = { 1, 1, 1 }
UI.GREY = { 0.62, 0.62, 0.62 }
UI.GREEN = { 0.25, 1, 0.25 }
UI.RED = { 1, 0.25, 0.2 }

---------------------------------------------------------------------------
-- Templates can differ between client builds: fall back to a bare frame.
---------------------------------------------------------------------------
function UI.Create(kind, name, parent, template)
	if template then
		local ok, f = pcall(CreateFrame, kind, name, parent, template)
		if ok and f then return f, true end
	end
	return CreateFrame(kind, name, parent), false
end

---------------------------------------------------------------------------
-- Fonts: four font objects all text uses, re-pointed when settings change.
---------------------------------------------------------------------------
local FACES = {
	game = function() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end,
	friz = function() return "Fonts\\FRIZQT__.TTF" end,
	arial = function() return "Fonts\\ARIALN.TTF" end,
	morpheus = function() return "Fonts\\MORPHEUS.TTF" end,
	skurri = function() return "Fonts\\SKURRI.TTF" end,
}
UI.FACE_NAMES = {
	{ "game", "Game default" }, { "friz", "Friz Quadrata" }, { "arial", "Arial Narrow" },
	{ "morpheus", "Morpheus" }, { "skurri", "Skurri" },
}

local fonts = {}
local function makeFont(name, r, g, b)
	local f = CreateFont(name)
	f:SetTextColor(r, g, b)
	f:SetShadowColor(0, 0, 0, 1)
	f:SetShadowOffset(1, -1)
	fonts[#fonts + 1] = f
	return f
end
UI.FontTitle = makeFont("WaypostFontTitle", 1, 0.82, 0)
UI.FontGold = makeFont("WaypostFontGold", 1, 0.82, 0)
UI.FontText = makeFont("WaypostFontText", 1, 1, 1)
UI.FontSmall = makeFont("WaypostFontSmall", 0.82, 0.82, 0.82)

function UI.ApplyFonts()
	local o = W.opt and W.opt.ui or W.defaults.ui
	local face = (FACES[o.font] or FACES.game)()
	local size = o.fontSize or 12
	local function set(font, s)
		if not pcall(font.SetFont, font, face, s, "") or not font:GetFont() then
			font:SetFont(FACES.game(), s, "")
		end
	end
	set(UI.FontTitle, size + 2)
	set(UI.FontGold, size)
	set(UI.FontText, size)
	set(UI.FontSmall, math.max(8, size - 1.5))
end
UI.ApplyFonts()

---------------------------------------------------------------------------
-- Backdrops
---------------------------------------------------------------------------
local BACKDROPS = {
	-- The quest-tooltip look: thin beveled border, near-black fill.
	classic = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
		bg = { 0.05, 0.04, 0.03, 0.88 }, edge = { 0.85, 0.72, 0.42, 1 },
	},
	-- No border at all, for people who want only text over the world.
	slim = {
		bgFile = "Interface\\Buttons\\WHITE8X8",
		tile = false, edgeSize = 0,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
		bg = { 0, 0, 0, 0.45 },
	},
	-- The big gold dialog frame.
	stone = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 24,
		insets = { left = 7, right = 7, top = 7, bottom = 7 },
		bg = { 1, 1, 1, 0.95 }, edge = { 1, 1, 1, 1 },
	},
	dialog = {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
		bg = { 1, 1, 1, 1 }, edge = { 1, 1, 1, 1 },
	},
	inset = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
		bg = { 0, 0, 0, 0.55 }, edge = { 0.55, 0.5, 0.42, 1 },
	},
}
UI.SKINS = { { "classic", "Classic (tooltip frame)" }, { "stone", "Dialog (gold border)" }, { "slim", "Minimal (no border)" } }

function UI.Backdrop(frame, style, alpha)
	local b = BACKDROPS[style] or BACKDROPS.classic
	if not frame.SetBackdrop then return end
	frame:SetBackdrop(b)
	local bg = b.bg
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] * (alpha or 1))
	if b.edge and b.edgeFile then frame:SetBackdropBorderColor(b.edge[1], b.edge[2], b.edge[3], b.edge[4]) end
	frame.wpInset = b.insets.left
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
function UI.Tooltip(frame, title, text, anchor)
	frame:HookScript("OnEnter", function(self)
		local t = type(title) == "function" and title(self) or title
		if not t then return end
		GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
		GameTooltip:SetText(t, 1, 0.82, 0)
		local body = type(text) == "function" and text(self) or text
		if body then GameTooltip:AddLine(body, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
function UI.Button(parent, text, width, height, onClick)
	local b, templated = UI.Create("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 100, height or 22)
	if not templated then
		for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
			local tex = b:CreateTexture()
			tex:SetTexture("Interface\\Buttons\\UI-Panel-Button-" .. (state == "Normal" and "Up" or state == "Pushed" and "Down" or state))
			tex:SetTexCoord(0, 0.625, 0, 0.6875)
			tex:SetAllPoints()
			b["Set" .. state .. "Texture"](b, tex)
		end
		b:SetNormalFontObject("GameFontNormal")
		b:SetHighlightFontObject("GameFontHighlight")
		b:SetDisabledFontObject("GameFontDisable")
	end
	b:SetText(text or "")
	if onClick then
		b:SetScript("OnClick", function(self, ...)
			if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
			onClick(self, ...)
		end)
	end
	return b
end

-- Small square texture button (header and footer controls).
function UI.IconButton(parent, size, normal, pushed, highlight, onClick, coords)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b:SetNormalTexture(normal)
	if pushed then b:SetPushedTexture(pushed) end
	b:SetHighlightTexture(highlight or "Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	if coords then
		b:GetNormalTexture():SetTexCoord(unpack(coords))
		if pushed then b:GetPushedTexture():SetTexCoord(unpack(coords)) end
	end
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

function UI.CloseButton(parent, onClick)
	local b, templated = UI.Create("Button", nil, parent, "UIPanelCloseButton")
	if not templated then
		b:SetSize(28, 28)
		b:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
		b:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
		b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	end
	b:SetScript("OnClick", onClick or function(self) self:GetParent():Hide() end)
	return b
end

---------------------------------------------------------------------------
-- Check box
---------------------------------------------------------------------------
function UI.Check(parent, label, get, set, tip)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(24, 24)
	c:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	c:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	c:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	c:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	c:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	local t = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	t:SetPoint("LEFT", c, "RIGHT", 2, 1)
	t:SetText(label)
	c.label = t
	c:SetHitRectInsets(0, -math.min(260, t:GetStringWidth() + 6), 0, 0)
	c.Refresh = function(self) self:SetChecked(get() and true or false) end
	c:SetScript("OnClick", function(self)
		if PlaySound and SOUNDKIT then
			PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		end
		set(self:GetChecked() and true or false)
	end)
	c:SetScript("OnShow", c.Refresh)
	if tip then UI.Tooltip(c, label, tip) end
	return c
end

---------------------------------------------------------------------------
-- Slider
---------------------------------------------------------------------------
function UI.Slider(parent, label, minV, maxV, step, get, set, fmt, tip)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(220, 38)
	local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT", 2, 0)
	title:SetText(label)
	local value = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("TOPRIGHT", -2, 0)

	local s = CreateFrame("Slider", nil, holder, "BackdropTemplate")
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("BOTTOMLEFT", 0, 2)
	s:SetPoint("BOTTOMRIGHT", 0, 2)
	s:SetHeight(17)
	if s.SetBackdrop then
		s:SetBackdrop({
			bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
			edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
			tile = true, tileSize = 8, edgeSize = 8,
			insets = { left = 3, right = 3, top = 6, bottom = 6 },
		})
	end
	s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local function show(v) value:SetText(fmt and fmt(v) or tostring(v)) end
	local busy = false
	s:SetScript("OnValueChanged", function(_, v)
		if busy then return end
		v = math.floor(v / step + 0.5) * step
		show(v)
		set(v)
	end)
	holder.Refresh = function()
		busy = true
		local v = get() or minV
		s:SetValue(v)
		show(v)
		busy = false
	end
	holder:SetScript("OnShow", holder.Refresh)
	holder.label = title
	if tip then UI.Tooltip(s, label, tip) end
	return holder
end

---------------------------------------------------------------------------
-- Dropdown: a plain button that opens a small list (no UIDropDownMenu taint).
---------------------------------------------------------------------------
local menu
local function getMenu()
	if menu then return menu end
	menu = CreateFrame("Frame", "WaypostMenu", UIParent, "BackdropTemplate")
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetClampedToScreen(true)
	UI.Backdrop(menu, "classic")
	menu:SetBackdropColor(0.06, 0.05, 0.04, 0.97)
	menu.rows = {}
	menu:Hide()
	menu:SetScript("OnShow", function(self) self.timer = 0 end)
	menu:SetScript("OnUpdate", function(self, dt)
		if self:IsMouseOver() or (self.owner and self.owner:IsMouseOver()) then
			self.timer = 0
		else
			self.timer = self.timer + dt
			if self.timer > 1.2 then self:Hide() end
		end
	end)
	return menu
end

-- items: list of { text=, value=, checked=, func=, disabled=, title= }
function UI.ShowMenu(owner, items, width)
	local m = getMenu()
	if m:IsShown() and m.owner == owner then m:Hide() return end
	m.owner = owner
	width = width or 180
	local y = -8
	for i, item in ipairs(items) do
		local row = m.rows[i]
		if not row then
			row = CreateFrame("Button", nil, m)
			row:SetHeight(18)
			row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.text:SetPoint("LEFT", 18, 0)
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
			row.check = row:CreateTexture(nil, "ARTWORK")
			row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
			row.check:SetSize(16, 16)
			row.check:SetPoint("LEFT", 1, 0)
			row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			row:SetScript("OnClick", function(self)
				local it = self.item
				if it.disabled or it.title then return end
				m:Hide()
				if it.func then it.func(it.value) end
			end)
			m.rows[i] = row
		end
		row.item = item
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 6, y)
		row:SetPoint("TOPRIGHT", -6, y)
		row.text:SetText(item.text)
		row.check:SetShown(item.checked and true or false)
		if item.title then
			row.text:SetTextColor(1, 0.82, 0)
		elseif item.disabled then
			row.text:SetTextColor(0.5, 0.5, 0.5)
		else
			row.text:SetTextColor(1, 1, 1)
		end
		row:EnableMouse(not item.title)
		row:Show()
		y = y - 18
	end
	for i = #items + 1, #m.rows do m.rows[i]:Hide() end
	m:SetSize(width, -y + 8)
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 2)
	m:Show()
end

function UI.HideMenu() if menu then menu:Hide() end end

function UI.Dropdown(parent, label, width, options, get, set, tip)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width or 200, 40)
	local title = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOPLEFT", 2, 0)
	title:SetText(label)
	local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
	b:SetPoint("BOTTOMLEFT")
	b:SetPoint("BOTTOMRIGHT")
	b:SetHeight(22)
	UI.Backdrop(b, "inset")
	b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -22, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	arrow:SetSize(20, 20)
	arrow:SetPoint("RIGHT", -1, 0)
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	local function opts() return type(options) == "function" and options() or options end
	holder.Refresh = function()
		local cur = get()
		local shown = tostring(cur or "")
		for _, o in ipairs(opts()) do if o[1] == cur then shown = o[2] end end
		b.text:SetText(shown)
	end
	b:SetScript("OnClick", function(self)
		local items, cur = {}, get()
		for _, o in ipairs(opts()) do
			items[#items + 1] = { text = o[2], value = o[1], checked = (o[1] == cur), func = function(v) set(v); holder.Refresh() end }
		end
		UI.ShowMenu(self, items, self:GetWidth())
	end)
	holder:SetScript("OnShow", holder.Refresh)
	holder.label = title
	if tip then UI.Tooltip(b, label, tip) end
	return holder
end

---------------------------------------------------------------------------
-- Edit box
---------------------------------------------------------------------------
function UI.EditBox(parent, width, height, placeholder)
	local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	e:SetSize(width or 160, height or 22)
	UI.Backdrop(e, "inset")
	e:SetFontObject("GameFontHighlightSmall")
	e:SetTextInsets(7, 7, 0, 0)
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	if placeholder then
		local ph = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		ph:SetPoint("LEFT", 8, 0)
		ph:SetText(placeholder)
		e.placeholder = ph
		e:HookScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == "") end)
	end
	return e
end

---------------------------------------------------------------------------
-- Scroll area with a slim classic scroll bar
---------------------------------------------------------------------------
function UI.Scroll(parent)
	local sf = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(10, 10)
	sf:SetScrollChild(child)
	sf.child = child

	local bar = CreateFrame("Slider", nil, sf, "BackdropTemplate")
	bar:SetOrientation("VERTICAL")
	bar:SetWidth(14)
	bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 3, 0)
	bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 3, 0)
	if bar.SetBackdrop then
		bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
		bar:SetBackdropColor(0, 0, 0, 0.35)
	end
	bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	local thumb = bar:GetThumbTexture()
	if thumb then thumb:SetSize(18, 22) thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875) end
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	bar:SetValueStep(1)
	sf.bar = bar

	bar:SetScript("OnValueChanged", function(_, v)
		sf:SetVerticalScroll(v)
		if sf.OnScroll then sf.OnScroll(v) end
	end)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(_, delta)
		local lo, hi = bar:GetMinMaxValues()
		local v = math.max(lo, math.min(hi, bar:GetValue() - delta * (sf.wheelStep or 40)))
		bar:SetValue(v)
	end)
	function sf.UpdateRange(contentHeight)
		if contentHeight and sf.child == child then child:SetHeight(math.max(1, contentHeight)) end
		if contentHeight then sf.contentHeight = math.max(1, contentHeight) end
		local range = math.max(0, (sf.contentHeight or sf.child:GetHeight()) - sf:GetHeight())
		bar:SetMinMaxValues(0, range)
		if bar:GetValue() > range then bar:SetValue(range) end
		bar:SetShown(range > 0)
	end
	sf:SetScript("OnSizeChanged", function(self, w)
		sf.child:SetWidth(w)
		sf.UpdateRange()
	end)
	return sf, child
end

---------------------------------------------------------------------------
-- Dialog window: gold border, header plate, close button, Esc closes.
---------------------------------------------------------------------------
function UI.Window(name, title, width, height)
	local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	f:SetSize(width, height)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	UI.Backdrop(f, "dialog")

	local header = f:CreateTexture(nil, "ARTWORK")
	header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	header:SetSize(math.max(256, (title and #title or 10) * 9 + 150), 64)
	header:SetPoint("TOP", 0, 12)
	f.header = header
	local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("TOP", header, "TOP", 0, -14)
	text:SetText(title or "")
	f.title = text

	local close = UI.CloseButton(f)
	close:SetPoint("TOPRIGHT", -5, -5)
	f.close = close

	if name then tinsert(UISpecialFrames, name) end
	f:SetScript("OnShow", function() if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end end)
	f:SetScript("OnHide", function() UI.HideMenu() if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end end)
	f:Hide()
	return f
end

-- Section heading with a thin gold rule, as in the default options panels.
function UI.Heading(parent, text)
	local h = CreateFrame("Frame", nil, parent)
	h:SetHeight(22)
	local fs = h:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	fs:SetPoint("BOTTOMLEFT", 0, 4)
	fs:SetText(text)
	local line = h:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.35)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", 0, 0)
	line:SetPoint("BOTTOMRIGHT", 0, 0)
	h.text = fs
	return h
end

-- A window holding one copyable text block (reports, export strings).
local copyWindow
function UI.CopyText(title, text, hint)
	if not copyWindow then
		local f = UI.Window("WaypostCopyWindow", "", 520, 360)
		f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		f.hint:SetPoint("TOPLEFT", 20, -30)
		f.hint:SetPoint("TOPRIGHT", -20, -30)
		f.hint:SetJustifyH("LEFT")
		local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 18, -52)
		box:SetPoint("BOTTOMRIGHT", -18, 18)
		UI.Backdrop(box, "inset")
		local sf = UI.Scroll(box)
		sf:SetPoint("TOPLEFT", 6, -6)
		sf:SetPoint("BOTTOMRIGHT", -22, 6)
		local e = CreateFrame("EditBox", nil, sf)
		e:SetMultiLine(true)
		e:SetFontObject("ChatFontNormal")
		e:SetAutoFocus(false)
		e:SetWidth(440)
		e:SetScript("OnEscapePressed", function() f:Hide() end)
		e:SetScript("OnTextChanged", function(self) sf.UpdateRange(self:GetHeight()) end)
		sf:SetScrollChild(e)
		sf.child = e
		f.edit, f.scroll = e, sf
		copyWindow = f
	end
	local f = copyWindow
	f.title:SetText(title)
	f.hint:SetText(hint or L["Press Ctrl+C to copy."])
	f.edit:SetText(text or "")
	f:Show()
	f.edit:SetFocus()
	f.edit:HighlightText()
	return f
end

W.On("WP_SETTINGS", function(path)
	if path == "*" or path == "ui.font" or path == "ui.fontSize" then UI.ApplyFonts() end
end)
W.On("WP_LOGIN", UI.ApplyFonts)

---------------------------------------------------------------------------
-- Virtual list: a fixed set of row frames over any number of items, so a
-- 300-entry list costs a dozen frames.
--   init(row)                 build the row's regions once
--   update(row, item, index)  fill it
---------------------------------------------------------------------------
function UI.VirtualList(parent, rowHeight, init, update)
	local v = CreateFrame("Frame", nil, parent)
	v.rows, v.items, v.offset = {}, {}, 0

	local bar = CreateFrame("Slider", nil, v, "BackdropTemplate")
	bar:SetOrientation("VERTICAL")
	bar:SetWidth(14)
	bar:SetPoint("TOPRIGHT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", 0, 0)
	if bar.SetBackdrop then
		bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
		bar:SetBackdropColor(0, 0, 0, 0.35)
	end
	bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
	local thumb = bar:GetThumbTexture()
	if thumb then thumb:SetSize(18, 22) thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875) end
	bar:SetValueStep(1)
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	v.bar = bar

	function v.Refresh()
		local visible = math.max(1, math.floor(v:GetHeight() / rowHeight))
		for i = #v.rows + 1, visible do
			local row = CreateFrame("Button", nil, v)
			row:SetHeight(rowHeight)
			row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
			row:SetPoint("TOPRIGHT", -18, -(i - 1) * rowHeight)
			init(row)
			v.rows[i] = row
		end
		local maxOffset = math.max(0, #v.items - visible)
		bar:SetMinMaxValues(0, maxOffset)
		bar:SetShown(maxOffset > 0)
		if v.offset > maxOffset then v.offset = maxOffset end
		for i = 1, #v.rows do
			local row = v.rows[i]
			local item = i <= visible and v.items[i + v.offset] or nil
			if item then
				row.item, row.index = item, i + v.offset
				update(row, item, i + v.offset)
				row:Show()
			else
				row.item = nil
				row:Hide()
			end
		end
	end

	function v.SetItems(items, keepScroll)
		v.items = items
		if not keepScroll then
			v.offset = 0
			bar:SetValue(0)
		end
		v.Refresh()
	end

	function v.ScrollTo(index)
		local visible = math.max(1, math.floor(v:GetHeight() / rowHeight))
		local maxOffset = math.max(0, #v.items - visible)
		bar:SetMinMaxValues(0, maxOffset)
		bar:SetValue(math.max(0, math.min(maxOffset, index - 3)))
	end

	bar:SetScript("OnValueChanged", function(_, val)
		local o = math.floor(val + 0.5)
		if o ~= v.offset then
			v.offset = o
			v.Refresh()
		end
	end)
	v:EnableMouseWheel(true)
	v:SetScript("OnMouseWheel", function(_, delta)
		local lo, hi = bar:GetMinMaxValues()
		bar:SetValue(math.max(lo, math.min(hi, bar:GetValue() - delta * 3)))
	end)
	v:SetScript("OnSizeChanged", function() v.Refresh() end)
	return v
end

---------------------------------------------------------------------------
-- Toast: a short notice that slides in at the top and fades (level-up talent
-- picks, guild announcements, finished guides). One frame, reused.
---------------------------------------------------------------------------
local toast, toastQueue = nil, {}
local function nextToast()
	local t = table.remove(toastQueue, 1)
	if not t then return end
	if not toast then
		toast = CreateFrame("Button", "WaypostToast", UIParent, "BackdropTemplate")
		toast:SetSize(340, 58)
		toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
		toast:SetFrameStrata("HIGH")
		UI.Backdrop(toast, "classic")
		toast.icon = toast:CreateTexture(nil, "ARTWORK")
		toast.icon:SetSize(36, 36)
		toast.icon:SetPoint("LEFT", 12, 0)
		toast.title = toast:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, 0)
		toast.title:SetPoint("RIGHT", -12, 0)
		toast.title:SetJustifyH("LEFT")
		toast.title:SetWordWrap(false)
		toast.text = toast:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -3)
		toast.text:SetPoint("RIGHT", -12, 0)
		toast.text:SetJustifyH("LEFT")
		toast.text:SetJustifyV("TOP")
		toast.text:SetHeight(24)
		toast:SetScript("OnClick", function(self)
			self:Hide()
			if self.onClick then self.onClick() end
		end)
		toast:SetScript("OnUpdate", function(self, dt)
			self.age = self.age + dt
			local a = 1
			if self.age < 0.3 then a = self.age / 0.3
			elseif self.age > self.life then a = 1 - (self.age - self.life) / 0.8 end
			if a <= 0 then self:Hide() return end
			self:SetAlpha(a)
		end)
		toast:SetScript("OnHide", function() nextToast() end)
	end
	toast.icon:SetTexture(t.icon or (MEDIA .. "Logo"))
	toast.title:SetText(t.title or "Waypost")
	toast.text:SetText(t.text or "")
	toast.onClick = t.onClick
	toast.age, toast.life = 0, t.life or 7
	toast:SetAlpha(0)
	toast:Show()
	if W.opt and W.opt.sound and PlaySound and SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN then
		pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_OPEN)
	end
end

function UI.Toast(title, text, icon, onClick, life)
	toastQueue[#toastQueue + 1] = { title = title, text = text, icon = icon, onClick = onClick, life = life }
	if #toastQueue > 4 then table.remove(toastQueue, 1) end
	if not toast or not toast:IsShown() then nextToast() end
end
