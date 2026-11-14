-- Look and widgets.
--
-- Waypost draws its own interface rather than borrowing Blizzard's window
-- templates, but in the game's visual language: the game's typeface, quest
-- gold for headings, item-quality colours for items, warm dark leather for
-- panels and a thin bronze trim. Icons are Waypost's own glyph sheet
-- (Media/Icons.tga, tools/make_icons.py), tinted in those colours.

local W = Waypost
local L = W.L
local UI = {}
W.UI = UI

local MEDIA = "Interface\\AddOns\\Waypost\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
UI.MEDIA, UI.WHITE = MEDIA, WHITE

---------------------------------------------------------------------------
-- Palette
---------------------------------------------------------------------------
local C = {
	bg      = { 0.075, 0.062, 0.048 },   -- panel: dark leather
	band    = { 0.135, 0.105, 0.070 },   -- header band
	well    = { 0.035, 0.028, 0.022 },   -- inset areas, input fields
	raise   = { 0.190, 0.150, 0.100 },   -- hover, raised rows
	trim    = { 0.560, 0.440, 0.220 },   -- bronze hairline
	gold    = { 1.000, 0.820, 0.000 },   -- quest gold (headings, accent)
	text    = { 0.960, 0.930, 0.860 },   -- parchment white
	dim     = { 0.740, 0.690, 0.590 },
	muted   = { 0.520, 0.480, 0.400 },
	npc     = { 0.560, 0.900, 0.560 },   -- friendly-unit green
	enemy   = { 1.000, 0.520, 0.420 },   -- hostile red
	place   = { 1.000, 0.900, 0.620 },   -- zone-text cream
	good    = { 0.300, 0.950, 0.350 },
	warn    = { 1.000, 0.600, 0.200 },
	bad     = { 1.000, 0.330, 0.280 },
	info    = { 0.500, 0.800, 1.000 },
	red     = { 0.420, 0.080, 0.055 },   -- panel-button red
	redHi   = { 0.600, 0.130, 0.085 },
}
UI.C = C

function UI.Hex(c)
	return ("|cff%02x%02x%02x"):format(c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5)
end

---------------------------------------------------------------------------
-- Icons: one sheet, 8 columns x 5 rows of 64 px cells in 512x512
---------------------------------------------------------------------------
local ICON = {}
do
	local names = {
		"accept", "turnin", "kill", "collect", "talk", "goto", "use", "fly",
		"home", "train", "level", "vendor", "note", "check", "skip", "left",
		"right", "down", "gear", "list", "close", "minus", "plus", "book",
		"undo", "warn", "dots", "lock", "nav", "interact", "box", "explore",
		"up", "bug", "users", "clock", "boxcheck", "search", "pinoff", "star",
	}
	for i, n in ipairs(names) do ICON[n] = i - 1 end
end
UI.ICON = ICON

function UI.SetIcon(tex, name)
	local i = ICON[name] or ICON.note
	local col, row = i % 8, math.floor(i / 8)
	tex:SetTexture(MEDIA .. "Icons")
	tex:SetTexCoord(col / 8, (col + 1) / 8, row / 8, (row + 1) / 8)
end

function UI.Icon(parent, name, size, layer, color)
	local t = parent:CreateTexture(nil, layer or "ARTWORK")
	t:SetSize(size or 16, size or 16)
	UI.SetIcon(t, name)
	color = color or C.dim
	t:SetVertexColor(color[1], color[2], color[3])
	return t
end

---------------------------------------------------------------------------
-- Fonts. Two families share the chosen face: the guide window's (sized by
-- the font-size setting) and the dialogs' (fixed, so their layouts hold).
---------------------------------------------------------------------------
-- The game's own faces, read from its font objects so every client locale
-- gets the file that has its letters: body text is the standard interface
-- font (Friz Quadrata), headings are the quest-log title font (Morpheus).
local function fontOf(object, fallback)
	local f = _G[object]
	if f and f.GetFont then
		local ok, path = pcall(f.GetFont, f)
		if ok and type(path) == "string" and path ~= "" then return path end
	end
	return fallback
end

local FACES = {
	game = function() return fontOf("GameFontNormal", STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF") end,
	friz = function() return "Fonts\\FRIZQT__.TTF" end,
	arial = function() return "Fonts\\ARIALN.TTF" end,
	morpheus = function() return "Fonts\\MORPHEUS.TTF" end,
	skurri = function() return "Fonts\\SKURRI.TTF" end,
}
UI.FACE_NAMES = {
	{ "game", "Game default (Friz Quadrata)" }, { "friz", "Friz Quadrata" }, { "arial", "Arial Narrow" },
	{ "morpheus", "Morpheus" }, { "skurri", "Skurri" },
}
UI.HEAD_NAMES = { { "quest", "Quest log titles (Morpheus)" }, { "text", "Same as the text" } }

function UI.HeadFace()
	local o = W.opt and W.opt.ui or W.defaults.ui
	if o.headFont == "text" then return (FACES[o.font] or FACES.game)() end
	return fontOf("QuestTitleFont", "Fonts\\MORPHEUS.TTF")
end

local fonts = {}
-- head: a heading (uses the heading face); headSize: its size when the heading face is Morpheus,
-- which draws smaller than Friz Quadrata at the same point size
local function makeFont(name, color, delta, fixed, head, headBoost)
	local f = CreateFont(name)
	f:SetTextColor(color[1], color[2], color[3])
	f:SetShadowColor(0, 0, 0, 1)
	f:SetShadowOffset(1, -1)
	fonts[#fonts + 1] = { font = f, delta = delta, fixed = fixed, head = head, boost = headBoost or 0 }
	return f
end
-- guide window
UI.FontTitle = makeFont("WaypostGuideTitle", C.gold, 3, nil, true, 3)
UI.FontGold = makeFont("WaypostGuideGold", C.gold, 0)
UI.FontText = makeFont("WaypostGuideText", C.text, 0)
UI.FontNow = makeFont("WaypostGuideNow", C.text, 2)
UI.FontSmall = makeFont("WaypostGuideSmall", C.dim, -1.5)
-- dialogs
makeFont("WaypostFontHead", C.gold, nil, 15, true, 3)
makeFont("WaypostFontDing", C.gold, nil, 24, true, 8)
makeFont("WaypostFontBig", C.text, nil, 15)
makeFont("WaypostFontGold", C.gold, nil, 12)
makeFont("WaypostFontGoldSmall", C.gold, nil, 11)
makeFont("WaypostFontText", C.text, nil, 12)
makeFont("WaypostFontSmall", C.text, nil, 11)
makeFont("WaypostFontMuted", C.muted, nil, 11)
makeFont("WaypostFontGreen", C.good, nil, 11)

function UI.ApplyFonts()
	local o = W.opt and W.opt.ui or W.defaults.ui
	local face = (FACES[o.font] or FACES.game)()
	local headFace = UI.HeadFace()
	local questHead = o.headFont ~= "text"
	local size = o.fontSize or 12
	local flags = (o.skin == "bare") and "OUTLINE" or ""
	for _, e in ipairs(fonts) do
		local s = e.fixed or math.max(8, size + e.delta)
		local fl = e.fixed and "" or flags
		local f = face
		if e.head then
			f = headFace
			if questHead then s = s + e.boost end
		end
		if not pcall(e.font.SetFont, e.font, f, s, fl) or not e.font:GetFont() then
			e.font:SetFont(FACES.game(), s, fl)
		end
	end
end
UI.ApplyFonts()

---------------------------------------------------------------------------
-- Surfaces
---------------------------------------------------------------------------
-- A one-pixel trim around a frame (four textures; cheaper and crisper than a backdrop edge).
function UI.Trim(frame, color, alpha, layer)
	color = color or C.trim
	local t = frame.wpTrim
	if not t then
		t = {}
		for i = 1, 4 do
			t[i] = frame:CreateTexture(nil, layer or "BORDER")
			t[i]:SetTexture(WHITE)
		end
		t[1]:SetPoint("TOPLEFT") t[1]:SetPoint("TOPRIGHT") t[1]:SetHeight(1)
		t[2]:SetPoint("BOTTOMLEFT") t[2]:SetPoint("BOTTOMRIGHT") t[2]:SetHeight(1)
		t[3]:SetPoint("TOPLEFT") t[3]:SetPoint("BOTTOMLEFT") t[3]:SetWidth(1)
		t[4]:SetPoint("TOPRIGHT") t[4]:SetPoint("BOTTOMRIGHT") t[4]:SetWidth(1)
		frame.wpTrim = t
	end
	for i = 1, 4 do
		t[i]:SetVertexColor(color[1], color[2], color[3], alpha or 1)
		t[i]:SetShown((alpha or 1) > 0)
	end
	return t
end

function UI.Fill(frame, color, alpha, layer)
	local f = frame.wpFill
	if not f then
		f = frame:CreateTexture(nil, layer or "BACKGROUND")
		f:SetTexture(WHITE)
		f:SetAllPoints()
		frame.wpFill = f
	end
	f:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	return f
end

-- Window styles for the guide window.
UI.SKINS = { { "panel", "Panel" }, { "glass", "Glass (see-through)" }, { "bare", "Text only" } }
local SKIN = {
	panel = { fill = 0.94, trim = 0.9, band = 1 },
	glass = { fill = 0.55, trim = 0.45, band = 0.6 },
	bare = { fill = 0, trim = 0, band = 0 },
}
function UI.Skin(name) return SKIN[name] or SKIN.panel end

-- Styles: "panel" (window), "well" (inset list / field), "menu".
function UI.Backdrop(frame, style, alpha)
	alpha = alpha or 1
	if style == "well" or style == "inset" then
		UI.Fill(frame, C.well, 0.85 * alpha)
		UI.Trim(frame, C.trim, 0.35 * alpha)
	elseif style == "menu" then
		UI.Fill(frame, C.bg, 0.98)
		UI.Trim(frame, C.trim, 0.9)
	else
		UI.Fill(frame, C.bg, 0.96 * alpha)
		UI.Trim(frame, C.trim, 0.9 * alpha)
	end
end

-- A soft top-to-bottom sheen, where the client supports gradients.
local function sheen(tex, top, bottom)
	if tex.SetGradient and CreateColor then
		pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
	else
		tex:SetVertexColor(top[1], top[2], top[3])
	end
end

---------------------------------------------------------------------------
-- Tooltips (the game's own tooltip)
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

local function click()
	if W.opt and W.opt.sound and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
-- The red panel button, redrawn: red fill with a sheen, bronze trim, gold label.
function UI.Button(parent, text, width, height, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width or 100, height or 22)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(WHITE)
	bg:SetPoint("TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", -1, 1)
	b.bg = bg
	UI.Trim(b, C.trim, 0.95)
	local function paint(state)
		if state == "off" then
			sheen(bg, { 0.20, 0.17, 0.14 }, { 0.13, 0.11, 0.09 })
		elseif state == "over" then
			sheen(bg, { 0.72, 0.17, 0.11 }, C.redHi)
		else
			sheen(bg, C.redHi, C.red)
		end
	end
	b:SetNormalFontObject("WaypostFontGold")
	b:SetHighlightFontObject("WaypostFontText")
	b:SetDisabledFontObject("WaypostFontMuted")
	b:SetText(text or "")
	b:SetPushedTextOffset(1, -1)
	b:SetScript("OnEnter", function(self) if self:IsEnabled() then paint("over") end end)
	b:SetScript("OnLeave", function(self) paint(self:IsEnabled() and "up" or "off") end)
	b:SetScript("OnEnable", function() paint("up") end)
	b:SetScript("OnDisable", function() paint("off") end)
	paint("up")
	if onClick then
		b:SetScript("OnClick", function(self, ...)
			click()
			onClick(self, ...)
		end)
	end
	return b
end

-- A glyph button for header and footer controls.
function UI.IconButton(parent, size, icon, onClick, color)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size + 6, size + 6)
	color = color or C.dim
	b.icon = UI.Icon(b, icon, size, "ARTWORK", color)
	b.icon:SetPoint("CENTER")
	b.color = color
	b:SetScript("OnEnter", function(self) self.icon:SetVertexColor(C.gold[1], C.gold[2], C.gold[3]) end)
	b:SetScript("OnLeave", function(self) self.icon:SetVertexColor(self.color[1], self.color[2], self.color[3]) end)
	b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
	b:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

function UI.CloseButton(parent, onClick)
	local b = UI.IconButton(parent, 12, "close", onClick or function(self) self:GetParent():Hide() end)
	return b
end

-- A text link (footer actions).
function UI.Link(parent, label, font, onClick)
	local b = CreateFrame("Button", nil, parent)
	b.text = b:CreateFontString(nil, "ARTWORK")
	b.text:SetFontObject(font or "WaypostFontGoldSmall")
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetSize(b.text:GetStringWidth() + 12, 18)
	b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function(self) self.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3]) end)
	b.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

---------------------------------------------------------------------------
-- Check box
---------------------------------------------------------------------------
function UI.Check(parent, label, get, set, tip)
	local c = CreateFrame("CheckButton", nil, parent)
	c:SetSize(18, 18)
	local box = c:CreateTexture(nil, "BACKGROUND")
	box:SetTexture(WHITE)
	box:SetPoint("TOPLEFT", 1, -1)
	box:SetPoint("BOTTOMRIGHT", -1, 1)
	box:SetVertexColor(C.well[1], C.well[2], C.well[3], 0.9)
	UI.Trim(c, C.trim, 0.9)
	local mark = UI.Icon(c, "check", 14, "ARTWORK", C.gold)
	mark:SetPoint("CENTER")
	c:SetCheckedTexture(mark)
	local t = c:CreateFontString(nil, "ARTWORK", "WaypostFontText")
	t:SetPoint("LEFT", c, "RIGHT", 7, 0)
	t:SetText(label)
	c.label = t
	c:SetHitRectInsets(0, -math.min(300, t:GetStringWidth() + 10), 0, 0)
	c:SetScript("OnEnter", function() t:SetTextColor(1, 1, 1) end)
	c:SetScript("OnLeave", function() t:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
	c.Refresh = function(self) self:SetChecked(get() and true or false) end
	c:SetScript("OnClick", function(self)
		click()
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
	holder:SetSize(220, 36)
	local title = holder:CreateFontString(nil, "ARTWORK", "WaypostFontText")
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetText(label)
	local value = holder:CreateFontString(nil, "ARTWORK", "WaypostFontGold")
	value:SetPoint("TOPRIGHT", 0, 0)

	local s = CreateFrame("Slider", nil, holder)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("BOTTOMLEFT", 0, 0)
	s:SetPoint("BOTTOMRIGHT", 0, 0)
	s:SetHeight(16)
	local track = s:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(WHITE)
	track:SetPoint("LEFT", 0, 0)
	track:SetPoint("RIGHT", 0, 0)
	track:SetHeight(4)
	track:SetVertexColor(C.well[1], C.well[2], C.well[3], 1)
	local rim = s:CreateTexture(nil, "BORDER")
	rim:SetTexture(WHITE)
	rim:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, 0)
	rim:SetPoint("TOPRIGHT", track, "BOTTOMRIGHT", 0, 0)
	rim:SetHeight(1)
	rim:SetVertexColor(C.trim[1], C.trim[2], C.trim[3], 0.6)
	s:SetThumbTexture(WHITE)
	local thumb = s:GetThumbTexture()
	thumb:SetSize(8, 16)
	thumb:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
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
-- Menu and dropdown (our own: no shared dropdown frames, so no taint)
---------------------------------------------------------------------------
local menu
local function getMenu()
	if menu then return menu end
	menu = CreateFrame("Frame", "WaypostMenu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	UI.Backdrop(menu, "menu")
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

-- items: list of { text=, value=, checked=, func=, disabled=, title=, icon= }
function UI.ShowMenu(owner, items, width, anchor)
	local m = getMenu()
	if m:IsShown() and m.owner == owner then m:Hide() return end
	m.owner = owner
	width = width or 180
	local y = -5
	for i, item in ipairs(items) do
		local row = m.rows[i]
		if not row then
			row = CreateFrame("Button", nil, m)
			row:SetHeight(20)
			row.hl = row:CreateTexture(nil, "BACKGROUND")
			row.hl:SetTexture(WHITE)
			row.hl:SetAllPoints()
			row.hl:SetVertexColor(C.raise[1], C.raise[2], C.raise[3], 1)
			row.hl:Hide()
			row.text = row:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
			row.text:SetPoint("LEFT", 26, 0)
			row.text:SetPoint("RIGHT", -8, 0)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
			row.check = UI.Icon(row, "check", 12, "ARTWORK", C.gold)
			row.check:SetPoint("LEFT", 8, 0)
			row:SetScript("OnEnter", function(self) if not self.item.title and not self.item.disabled then self.hl:Show() end end)
			row:SetScript("OnLeave", function(self) self.hl:Hide() end)
			row:SetScript("OnClick", function(self)
				local it = self.item
				if it.disabled or it.title then return end
				m:Hide()
				click()
				if it.func then it.func(it.value) end
			end)
			m.rows[i] = row
		end
		row.item = item
		row.hl:Hide()
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 1, y)
		row:SetPoint("TOPRIGHT", -1, y)
		row.text:SetText(item.text)
		if item.icon then
			UI.SetIcon(row.check, item.icon)
			row.check:SetVertexColor(C.dim[1], C.dim[2], C.dim[3])
			row.check:Show()
		else
			UI.SetIcon(row.check, "check")
			row.check:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
			row.check:SetShown(item.checked and true or false)
		end
		local col = item.title and C.gold or item.disabled and C.muted or C.text
		row.text:SetTextColor(col[1], col[2], col[3])
		row:Show()
		y = y - 20
	end
	for i = #items + 1, #m.rows do m.rows[i]:Hide() end
	m:SetSize(width, -y + 5)
	m:ClearAllPoints()
	if anchor == "up" then
		m:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
	elseif anchor == "right" then
		m:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -2)
	else
		m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	end
	m:Show()
end

function UI.HideMenu() if menu then menu:Hide() end end

function UI.Dropdown(parent, label, width, options, get, set, tip)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width or 200, 42)
	local title = holder:CreateFontString(nil, "ARTWORK", "WaypostFontText")
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetText(label)
	local b = CreateFrame("Button", nil, holder)
	b:SetPoint("BOTTOMLEFT")
	b:SetPoint("BOTTOMRIGHT")
	b:SetHeight(22)
	UI.Backdrop(b, "well")
	b.text = b:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -22, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	local arrow = UI.Icon(b, "down", 10, "ARTWORK", C.gold)
	arrow:SetPoint("RIGHT", -7, 0)
	b:SetScript("OnEnter", function(self) UI.Trim(self, C.gold, 0.8) end)
	b:SetScript("OnLeave", function(self) UI.Trim(self, C.trim, 0.35) end)
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
	local e = CreateFrame("EditBox", nil, parent)
	e:SetSize(width or 160, height or 22)
	UI.Backdrop(e, "well")
	e:SetFontObject("WaypostFontSmall")
	e:SetTextInsets(8, 8, 0, 0)
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	e:SetScript("OnEditFocusGained", function(self) UI.Trim(self, C.gold, 0.8) end)
	e:SetScript("OnEditFocusLost", function(self) UI.Trim(self, C.trim, 0.35) end)
	if placeholder then
		local ph = e:CreateFontString(nil, "ARTWORK", "WaypostFontMuted")
		ph:SetPoint("LEFT", 9, 0)
		ph:SetText(placeholder)
		e.placeholder = ph
		e:HookScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == "") end)
	end
	return e
end

---------------------------------------------------------------------------
-- Scroll bar shared by the scroll area and the virtual list
---------------------------------------------------------------------------
local function scrollBar(parent)
	local bar = CreateFrame("Slider", nil, parent)
	bar:SetOrientation("VERTICAL")
	bar:SetWidth(8)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetTexture(WHITE)
	track:SetPoint("TOP") track:SetPoint("BOTTOM")
	track:SetWidth(2)
	track:SetVertexColor(1, 1, 1, 0.06)
	bar:SetThumbTexture(WHITE)
	local thumb = bar:GetThumbTexture()
	thumb:SetSize(4, 36)
	thumb:SetVertexColor(C.trim[1], C.trim[2], C.trim[3], 0.9)
	bar:SetMinMaxValues(0, 0)
	bar:SetValue(0)
	bar:SetValueStep(1)
	return bar
end

function UI.Scroll(parent)
	local sf = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(10, 10)
	sf:SetScrollChild(child)
	sf.child = child

	local bar = scrollBar(sf)
	bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 5, 0)
	bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 5, 0)
	sf.bar = bar

	bar:SetScript("OnValueChanged", function(_, v)
		sf:SetVerticalScroll(v)
		if sf.OnScroll then sf.OnScroll(v) end
	end)
	sf:EnableMouseWheel(true)
	sf:SetScript("OnMouseWheel", function(_, delta)
		local lo, hi = bar:GetMinMaxValues()
		bar:SetValue(math.max(lo, math.min(hi, bar:GetValue() - delta * (sf.wheelStep or 40))))
	end)
	function sf.UpdateRange(contentHeight)
		if contentHeight and sf.child == child then child:SetHeight(math.max(1, contentHeight)) end
		if contentHeight then sf.contentHeight = math.max(1, contentHeight) end
		local range = math.max(0, (sf.contentHeight or sf.child:GetHeight()) - sf:GetHeight())
		bar:SetMinMaxValues(0, range)
		if bar:GetValue() > range then bar:SetValue(range) end
		bar:SetShown(range > 0)
	end
	sf:SetScript("OnSizeChanged", function(_, w)
		sf.child:SetWidth(w)
		sf.UpdateRange()
	end)
	return sf, child
end

---------------------------------------------------------------------------
-- Dialog window: leather panel, header band with a gold title, Esc closes.
---------------------------------------------------------------------------
function UI.Window(name, title, width, height)
	local f = CreateFrame("Frame", name, UIParent)
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
	UI.Backdrop(f, "panel")

	local band = f:CreateTexture(nil, "BORDER")
	band:SetTexture(WHITE)
	band:SetPoint("TOPLEFT", 1, -1)
	band:SetPoint("TOPRIGHT", -1, -1)
	band:SetHeight(26)
	sheen(band, { 0.20, 0.155, 0.10 }, C.band)
	local rule = f:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(WHITE)
	rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
	rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
	rule:SetHeight(1)
	rule:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.55)
	f.header = band

	local logo = f:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(MEDIA .. "Logo")
	logo:SetSize(18, 18)
	logo:SetPoint("LEFT", band, "LEFT", 8, 0)
	local text = f:CreateFontString(nil, "OVERLAY", "WaypostFontHead")
	text:SetPoint("LEFT", logo, "RIGHT", 7, 0)
	text:SetText(title or "")
	f.title = text

	local close = UI.CloseButton(f)
	close:SetPoint("RIGHT", band, "RIGHT", -5, 0)
	f.close = close

	if name then tinsert(UISpecialFrames, name) end
	f:SetScript("OnShow", function() if W.opt and W.opt.sound and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end end)
	f:SetScript("OnHide", function() UI.HideMenu() if W.opt and W.opt.sound and PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end end)
	f:Hide()
	return f
end

-- Section heading with a gold rule.
function UI.Heading(parent, text)
	local h = CreateFrame("Frame", nil, parent)
	h:SetHeight(22)
	local fs = h:CreateFontString(nil, "ARTWORK", "WaypostFontHead")
	fs:SetPoint("BOTTOMLEFT", 0, 5)
	fs:SetText(text)
	local line = h:CreateTexture(nil, "ARTWORK")
	line:SetTexture(WHITE)
	line:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.3)
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
		f.hint = f:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
		f.hint:SetPoint("TOPLEFT", 16, -36)
		f.hint:SetPoint("TOPRIGHT", -16, -36)
		f.hint:SetJustifyH("LEFT")
		local box = CreateFrame("Frame", nil, f)
		box:SetPoint("TOPLEFT", 14, -60)
		box:SetPoint("BOTTOMRIGHT", -14, 14)
		UI.Backdrop(box, "well")
		local sf = UI.Scroll(box)
		sf:SetPoint("TOPLEFT", 8, -8)
		sf:SetPoint("BOTTOMRIGHT", -18, 8)
		local e = CreateFrame("EditBox", nil, sf)
		e:SetMultiLine(true)
		e:SetFontObject("ChatFontNormal")
		e:SetAutoFocus(false)
		e:SetWidth(450)
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

---------------------------------------------------------------------------
-- Virtual list: a fixed set of row frames over any number of items, so a
-- 300-entry list costs a dozen frames.
--   init(row)                 build the row's regions once
--   update(row, item, index)  fill it
---------------------------------------------------------------------------
function UI.VirtualList(parent, rowHeight, init, update)
	local v = CreateFrame("Frame", nil, parent)
	v.rows, v.items, v.offset = {}, {}, 0

	local bar = scrollBar(v)
	bar:SetPoint("TOPRIGHT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", 0, 0)
	v.bar = bar

	function v.Refresh()
		local visible = math.max(1, math.floor(v:GetHeight() / rowHeight))
		for i = #v.rows + 1, visible do
			local row = CreateFrame("Button", nil, v)
			row:SetHeight(rowHeight)
			row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
			row:SetPoint("TOPRIGHT", -12, -(i - 1) * rowHeight)
			local hl = row:CreateTexture(nil, "HIGHLIGHT")
			hl:SetTexture(WHITE)
			hl:SetAllPoints()
			hl:SetVertexColor(C.raise[1], C.raise[2], C.raise[3], 0.7)
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

-- Selected-row tint for list rows.
function UI.RowSelection(row)
	local sel = row:CreateTexture(nil, "BACKGROUND")
	sel:SetTexture(WHITE)
	sel:SetAllPoints()
	sel:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.16)
	local edge = row:CreateTexture(nil, "ARTWORK")
	edge:SetTexture(WHITE)
	edge:SetPoint("TOPLEFT") edge:SetPoint("BOTTOMLEFT")
	edge:SetWidth(2)
	edge:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	-- one handle that shows or hides both pieces
	local handle = {}
	function handle:SetShown(v)
		sel:SetShown(v and true or false)
		edge:SetShown(v and true or false)
	end
	function handle:Show() self:SetShown(true) end
	function handle:Hide() self:SetShown(false) end
	handle:Hide()
	return handle
end

---------------------------------------------------------------------------
-- Toast: a short notice at the top of the screen (talent picks, guild
-- announcements, finished guides). One frame, reused.
---------------------------------------------------------------------------
local toast, toastQueue = nil, {}
local function nextToast()
	local t = table.remove(toastQueue, 1)
	if not t then return end
	if not toast then
		toast = CreateFrame("Button", "WaypostToast", UIParent)
		toast:SetSize(360, 60)
		toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
		toast:SetFrameStrata("HIGH")
		UI.Backdrop(toast, "panel")
		local bar = toast:CreateTexture(nil, "ARTWORK")
		bar:SetTexture(WHITE)
		bar:SetPoint("TOPLEFT", 1, -1)
		bar:SetPoint("BOTTOMLEFT", 1, 1)
		bar:SetWidth(3)
		bar:SetVertexColor(C.gold[1], C.gold[2], C.gold[3])
		toast.icon = toast:CreateTexture(nil, "ARTWORK")
		toast.icon:SetSize(36, 36)
		toast.icon:SetPoint("LEFT", 14, 0)
		toast.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		toast.title = toast:CreateFontString(nil, "ARTWORK", "WaypostFontGold")
		toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, 1)
		toast.title:SetPoint("RIGHT", -12, 0)
		toast.title:SetJustifyH("LEFT")
		toast.title:SetWordWrap(false)
		toast.text = toast:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
		toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -3)
		toast.text:SetPoint("RIGHT", -12, 0)
		toast.text:SetJustifyH("LEFT")
		toast.text:SetJustifyV("TOP")
		toast.text:SetHeight(26)
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
	if t.icon then
		toast.icon:SetTexture(t.icon)
		toast.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	else
		toast.icon:SetTexture(MEDIA .. "Logo")
		toast.icon:SetTexCoord(0, 1, 0, 1)
	end
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

W.On("WP_SETTINGS", function(path)
	if path == "*" or path == "ui.font" or path == "ui.headFont" or path == "ui.fontSize" or path == "ui.skin" then UI.ApplyFonts() end
end)
W.On("WP_LOGIN", UI.ApplyFonts)
