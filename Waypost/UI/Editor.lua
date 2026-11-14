-- Custom guides: write one in the plain-text format, check it with
-- line-numbered errors, save it, and share it as an import string.

local W = Waypost
local L = W.L
local UI, E, G, Parser = W.UI, W.Engine, W.Guides, W.Parser
local Ed = {}
W.Editor = Ed

local win, edit, gutter, status, scroll
local currentId

local TEMPLATE = [[title My route
faction Alliance
levels 1-10
map 1429

step Northshire Abbey
  tip Lines starting with "tip" explain the step.
  accept 783 A Threat Within @48.2,42.9
  turnin 783 @48.9,41.6 -- Marshal McBride, inside

step Wolves
  kill 8 Young Wolf quest 33 obj 1 @50.9,44.4
  goto 48.9,40.2 Back to Eagan
]]

local function setStatus(text, r, g, b)
	status:SetText(text or "")
	status:SetTextColor(r or 1, g or 1, b or 1)
end

local function updateGutter()
	local text = edit:GetText() or ""
	local n = 1
	for _ in text:gmatch("\n") do n = n + 1 end
	if gutter.lines ~= n then
		gutter.lines = n
		local t = {}
		for i = 1, n do t[i] = i end
		gutter.text:SetText(table.concat(t, "\n"))
	end
end

local function check()
	local guide, errors = Parser.Parse(edit:GetText() or "")
	if guide then
		local goals = 0
		for _, s in ipairs(guide.steps) do goals = goals + #s.goals end
		setStatus((L["Looks good: %d steps, %d goals."]):format(#guide.steps, goals), 0.3, 1, 0.3)
		return guide
	end
	local lines = {}
	for i = 1, math.min(#errors, 6) do
		lines[#lines + 1] = (L["Line %d: %s"]):format(errors[i].line, errors[i].msg)
	end
	if #errors > 6 then lines[#lines + 1] = (L["...and %d more."]):format(#errors - 6) end
	setStatus(table.concat(lines, "\n"), 1, 0.4, 0.3)
	return nil
end

-- Register every saved custom guide (called at login and after saving).
function Ed.RegisterSaved()
	for id, text in pairs(W.db.custom) do
		local guide = Parser.Parse(text)
		if guide then
			guide.id = id
			W.RegisterGuide(guide)
		end
	end
end

local function save(andLoad)
	local guide = check()
	if not guide then return end
	if currentId and currentId ~= guide.id then W.db.custom[currentId] = nil; G.Unregister(currentId) end
	currentId = guide.id
	W.db.custom[guide.id] = edit:GetText()
	W.RegisterGuide(guide)
	setStatus((L["Saved \"%s\"."]):format(guide.title), 0.3, 1, 0.3)
	if andLoad then
		E.Load(guide.id, true)
		W.StepFrame.Toggle(true)
		win:Hide()
	end
end

local function build()
	win = UI.Window("WaypostEditor", L["Waypost Guide Editor"], 680, 540)

	local hint = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 20, -32)
	hint:SetPoint("TOPRIGHT", -20, -32)
	hint:SetJustifyH("LEFT")
	hint:SetText(L["Write steps in plain text. /waypost where prints your coordinates. The web editor at tools/editor.html makes the same format."])

	local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 18, -52)
	box:SetPoint("BOTTOMRIGHT", -18, 120)
	UI.Backdrop(box, "inset")

	scroll = UI.Scroll(box)
	scroll:SetPoint("TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", -22, 6)
	local holder = scroll.child
	holder:SetSize(600, 400)

	gutter = CreateFrame("Frame", nil, holder)
	gutter:SetPoint("TOPLEFT")
	gutter:SetWidth(34)
	gutter.text = gutter:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
	gutter.text:SetPoint("TOPRIGHT", -6, 0)
	gutter.text:SetJustifyH("RIGHT")
	gutter.text:SetTextColor(0.5, 0.45, 0.3)
	gutter.bg = gutter:CreateTexture(nil, "BACKGROUND")
	gutter.bg:SetAllPoints()
	gutter.bg:SetColorTexture(1, 0.82, 0, 0.05)

	edit = CreateFrame("EditBox", nil, holder)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject("ChatFontNormal")
	edit:SetPoint("TOPLEFT", 40, 0)
	edit:SetWidth(560)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnTextChanged", function(self)
		updateGutter()
		local h = math.max(400, self:GetHeight() + 20)
		holder:SetHeight(h)
		gutter:SetHeight(h)
		scroll.UpdateRange(h)
	end)
	edit:SetScript("OnCursorChanged", function(_, _, y, _, cursorH)
		local top, view = scroll:GetVerticalScroll(), scroll:GetHeight()
		y = -y
		if y < top then scroll.bar:SetValue(y)
		elseif y + cursorH > top + view then scroll.bar:SetValue(y + cursorH - view) end
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() edit:SetFocus() end)
	scroll:HookScript("OnSizeChanged", function(_, w) edit:SetWidth(math.max(100, w - 44)) end)

	status = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 4, -6)
	status:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -4, -6)
	status:SetJustifyH("LEFT")
	status:SetJustifyV("TOP")
	status:SetHeight(62)

	local b1 = UI.Button(win, L["Check"], 80, 22, function() check() end)
	b1:SetPoint("BOTTOMLEFT", 18, 18)
	UI.Tooltip(b1, L["Check"], L["Looks for mistakes and lists them by line number."])
	local b2 = UI.Button(win, L["Save"], 80, 22, function() save(false) end)
	b2:SetPoint("LEFT", b1, "RIGHT", 4, 0)
	local b3 = UI.Button(win, L["Save and start"], 120, 22, function() save(true) end)
	b3:SetPoint("LEFT", b2, "RIGHT", 4, 0)
	local b6 = UI.Button(win, L["New"], 60, 22, function()
		currentId = nil
		edit:SetText(TEMPLATE)
		setStatus("")
	end)
	b6:SetPoint("LEFT", b3, "RIGHT", 4, 0)

	local b5 = UI.Button(win, L["Export string"], 110, 22, function()
		if not check() then return end
		UI.CopyText(L["Share this guide"], Parser.Export(edit:GetText()), L["Copy this string and send it to a friend. They paste it with Import."])
	end)
	b5:SetPoint("BOTTOMRIGHT", -18, 18)
	local b4 = UI.Button(win, L["Import string"], 110, 22, function()
		local text, err = Parser.Import(edit:GetText() or "")
		if not text then
			setStatus(err .. " " .. L["Paste the string into the box first, then press Import."], 1, 0.4, 0.3)
			return
		end
		currentId = nil
		edit:SetText(text)
		check()
	end)
	b4:SetPoint("RIGHT", b5, "LEFT", -4, 0)
	UI.Tooltip(b4, L["Import string"], L["Paste a WP1:/WP2: string into the box, then click here to turn it back into a guide."])
	local b7 = UI.Button(win, L["Current guide"], 110, 22, function()
		if not E.guide then return setStatus(L["No guide loaded."], 1, 0.4, 0.3) end
		currentId = nil
		edit:SetText(Parser.Serialize(E.guide))
		setStatus(L["This is your current guide as text. Saving it makes your own copy."], 1, 0.82, 0)
	end)
	b7:SetPoint("RIGHT", b4, "LEFT", -4, 0)
	UI.Tooltip(b7, L["Current guide"], L["Loads the guide you are on as editable text."])
end

function Ed.Open(id, text)
	if not win then build() end
	currentId = id
	if text then
		edit:SetText(text)
	elseif id and W.db.custom[id] then
		edit:SetText(W.db.custom[id])
	elseif (edit:GetText() or "") == "" then
		edit:SetText(TEMPLATE)
	end
	setStatus("")
	win:Show()
	edit:SetFocus()
end

W.On("WP_LOGIN", Ed.RegisterSaved)
