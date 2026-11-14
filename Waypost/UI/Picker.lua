-- Guide picker: choose a guide by category, with the right one for this
-- character suggested at the top. Leveling guides are grouped by level band.

local W = Waypost
local L = W.L
local UI, E, G = W.UI, W.Engine, W.Guides
local P = {}
W.Picker = P

local win, listView, detail, catButtons
local state = { category = "Leveling", search = "", all = false, selected = nil }

local BANDS = { { 1, 10 }, { 10, 20 }, { 20, 30 }, { 30, 40 }, { 40, 50 }, { 50, 60 } }

local function progressOf(m)
	local p = W.char.progress[m.id]
	if not p then return nil end
	if p.finished then return 1 end
	if p.step and m.steps and m.steps > 0 then return (p.step - 1) / m.steps end
	return 0
end

local function buildItems()
	local items = {}
	local search = state.search:lower()
	local pool = {}
	for _, m in ipairs(G.index) do
		if (m.category or "Other") == state.category and (state.all or G.Matches(m)) then
			if search == "" or (m.title or ""):lower():find(search, 1, true) or (m.zone or ""):lower():find(search, 1, true)
				or (m.folder or ""):lower():find(search, 1, true) then
				pool[#pool + 1] = m
			end
		end
	end
	if state.category == "Leveling" then
		table.sort(pool, function(a, b)
			if (a.minLevel or 0) ~= (b.minLevel or 0) then return (a.minLevel or 0) < (b.minLevel or 0) end
			if (a.maxLevel or 0) ~= (b.maxLevel or 0) then return (a.maxLevel or 0) < (b.maxLevel or 0) end
			return (a.title or "") < (b.title or "")
		end)
		for _, band in ipairs(BANDS) do
			local first = true
			for _, m in ipairs(pool) do
				local lv = m.minLevel or 1
				if lv >= band[1] and (lv < band[2] or (band[2] == 60 and lv <= 60)) then
					if first then
						items[#items + 1] = { header = (L["Levels %d-%d"]):format(band[1], band[2]) }
						first = false
					end
					items[#items + 1] = m
				end
			end
		end
	else
		table.sort(pool, function(a, b)
			if (a.folder or "") ~= (b.folder or "") then return (a.folder or "") < (b.folder or "") end
			if (a.minLevel or 0) ~= (b.minLevel or 0) then return (a.minLevel or 0) < (b.minLevel or 0) end
			return (a.title or "") < (b.title or "")
		end)
		local folder
		for _, m in ipairs(pool) do
			if m.folder and m.folder ~= folder then
				folder = m.folder
				items[#items + 1] = { header = folder }
			end
			items[#items + 1] = m
		end
	end
	return items
end

local function whoFor(m)
	local parts = {}
	if m.faction then parts[#parts + 1] = m.faction end
	if m.races then parts[#parts + 1] = table.concat(m.races, ", ") end
	if m.classes then
		local c = {}
		for _, cls in ipairs(m.classes) do
			c[#c + 1] = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls]) or (cls:sub(1, 1) .. cls:sub(2):lower())
		end
		parts[#parts + 1] = table.concat(c, ", ")
	end
	if #parts == 0 then return L["Everyone"] end
	return table.concat(parts, " - ")
end

local function showDetail(m)
	state.selected = m
	if not m then
		detail.title:SetText(L["Select a guide"])
		detail.info:SetText("")
		detail.start:Disable()
		detail.restart:Hide()
		detail.remove:Hide()
		return
	end
	detail.title:SetText(m.title or m.id)
	local lines = {}
	lines[#lines + 1] = ("|cffffd100%s|r %d-%d    |cffffd100%s|r %d    |cffffd100%s|r %s"):format(
		L["Levels"], m.minLevel or 1, m.maxLevel or 60, L["Steps"], m.steps or 0, L["For"], whoFor(m))
	if m.zone then lines[#lines + 1] = "|cffffd100" .. L["Zone"] .. "|r " .. m.zone end
	if m.why then lines[#lines + 1] = m.why end
	if m.next and G.Meta(m.next) then lines[#lines + 1] = "|cff9d9d9d" .. L["Leads into"] .. ": " .. (G.Meta(m.next).title or m.next) .. "|r" end
	if not G.Matches(m) then lines[#lines + 1] = "|cffff6050" .. L["This guide was written for a different race, class or faction."] .. "|r" end
	detail.info:SetText(table.concat(lines, "\n"))
	detail.start:Enable()
	local p = progressOf(m)
	local active = E.guide and E.guide.id == m.id
	detail.start:SetText(active and L["Current guide"] or (p and p > 0 and p < 1) and L["Continue"] or L["Start guide"])
	if active then detail.start:Disable() end
	detail.restart:SetShown(p ~= nil)
	detail.remove:SetShown(m.category == "Custom")
end

local function refresh(keep)
	if not win or not win:IsShown() then return end
	for _, b in ipairs(catButtons) do
		local on = b.category == state.category
		b.bg:SetShown(on)
		local c = on and UI.C.gold or UI.C.text
		b.text:SetTextColor(c[1], c[2], c[3])
	end
	listView.SetItems(buildItems(), keep)
	local m = G.Suggest()
	if m and state.category == "Leveling" then
		win.rec:Show()
		win.rec.text:SetText((L["Recommended for your %s: |cffffffff%s|r (%d-%d)"]):format(
			(W.player.level and (L["level"] .. " " .. W.player.level) or ""), m.title or m.id, m.minLevel or 1, m.maxLevel or 60))
		win.rec.meta = m
		win.rec.go:SetEnabled(not (E.guide and E.guide.id == m.id))
		win.rec.go:SetText((E.guide and E.guide.id == m.id) and L["Active"] or L["Start"])
	else
		win.rec:Hide()
	end
	listView:ClearAllPoints()
	listView:SetPoint("TOPLEFT", win.listBox, "TOPLEFT", 8, win.rec:IsShown() and -44 or -8)
	listView:SetPoint("BOTTOMRIGHT", win.listBox, "BOTTOMRIGHT", -6, 8)
	showDetail(state.selected)
end

local function build()
	win = UI.Window("WaypostPicker", L["Waypost Guides"], 700, 530)

	-- categories
	local side = CreateFrame("Frame", nil, win, "BackdropTemplate")
	side:SetPoint("TOPLEFT", 14, -40)
	side:SetPoint("BOTTOMLEFT", 14, 14)
	side:SetWidth(150)
	UI.Backdrop(side, "inset")
	catButtons = {}
	local function makeCat(cat, i)
		local b = CreateFrame("Button", nil, side)
		b:SetHeight(24)
		b:SetPoint("TOPLEFT", 5, -6 - (i - 1) * 25)
		b:SetPoint("TOPRIGHT", -5, -6 - (i - 1) * 25)
		b.bg = UI.RowSelection(b)
		local hover = b:CreateTexture(nil, "HIGHLIGHT")
		hover:SetTexture(UI.WHITE)
		hover:SetAllPoints()
		hover:SetVertexColor(UI.C.raise[1], UI.C.raise[2], UI.C.raise[3], 0.7)
		b.text = b:CreateFontString(nil, "ARTWORK", "WaypostFontText")
		b.text:SetPoint("LEFT", 8, 0)
		b.text:SetText(L[cat])
		b.category = cat
		b:SetScript("OnClick", function()
			state.category = cat
			state.selected = nil
			refresh()
		end)
		catButtons[i] = b
	end
	win.side = side

	-- top controls
	win.search = UI.EditBox(win, 200, 24, L["Search guides"])
	win.search:SetPoint("TOPLEFT", side, "TOPRIGHT", 10, 0)
	win.search:SetScript("OnTextChanged", function(self)
		if self.placeholder then self.placeholder:SetShown(self:GetText() == "") end
		state.search = self:GetText() or ""
		refresh()
	end)
	win.all = UI.Check(win, L["Show guides for every race and class"], function() return state.all end,
		function(v) state.all = v; refresh() end)
	win.all:SetPoint("LEFT", win.search, "RIGHT", 10, 0)

	-- list
	local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
	box:SetPoint("TOPLEFT", win.search, "BOTTOMLEFT", 0, -6)
	box:SetPoint("RIGHT", win, "RIGHT", -14, 0)
	box:SetPoint("BOTTOM", win, "BOTTOM", 0, 138)
	UI.Backdrop(box, "inset")
	win.listBox = box

	local rec = CreateFrame("Frame", nil, box)
	rec:SetPoint("TOPLEFT", 6, -6)
	rec:SetPoint("TOPRIGHT", -6, -6)
	rec:SetHeight(32)
	UI.Fill(rec, UI.C.gold, 0.12)
	rec.icon = UI.Icon(rec, "star", 16, "ARTWORK", UI.C.gold)
	rec.icon:SetPoint("LEFT", 8, 0)
	rec.text = rec:CreateFontString(nil, "ARTWORK", "WaypostFontGold")
	rec.text:SetPoint("LEFT", rec.icon, "RIGHT", 6, 0)
	rec.text:SetPoint("RIGHT", -100, 0)
	rec.text:SetJustifyH("LEFT")
	rec.text:SetWordWrap(false)
	rec.go = UI.Button(rec, L["Start"], 84, 22, function()
		if rec.meta then
			E.Load(rec.meta.id)
			W.StepFrame.Toggle(true)
			win:Hide()
		end
	end)
	rec.go:SetPoint("RIGHT", -5, 0)
	win.rec = rec

	listView = UI.VirtualList(box, 22, function(row)
		row.title = row:CreateFontString(nil, "ARTWORK", "WaypostFontText")
		row.title:SetPoint("LEFT", 8, 0)
		row.title:SetWidth(250)
		row.title:SetJustifyH("LEFT")
		row.title:SetWordWrap(false)
		row.levels = row:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
		row.levels:SetPoint("LEFT", 266, 0)
		row.levels:SetWidth(50)
		row.levels:SetJustifyH("LEFT")
		row.who = row:CreateFontString(nil, "ARTWORK", "WaypostFontMuted")
		row.who:SetPoint("LEFT", 318, 0)
		row.who:SetWidth(100)
		row.who:SetJustifyH("LEFT")
		row.who:SetWordWrap(false)
		row.status = row:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
		row.status:SetPoint("RIGHT", -6, 0)
		row.sel = UI.RowSelection(row)
		row.line = row:CreateTexture(nil, "ARTWORK")
		row.line:SetColorTexture(1, 0.82, 0, 0.3)
		row.line:SetHeight(1)
		row.line:SetPoint("BOTTOMLEFT", 6, 2)
		row.line:SetPoint("BOTTOMRIGHT", -6, 2)
		row:SetScript("OnClick", function(self)
			if self.item and not self.item.header then
				showDetail(self.item)
				listView.Refresh()
			end
		end)
		row:SetScript("OnDoubleClick", function(self)
			if self.item and not self.item.header then
				E.Load(self.item.id)
				W.StepFrame.Toggle(true)
				win:Hide()
			end
		end)
	end, function(row, m)
		if m.header then
			row.title:SetFontObject("WaypostFontGold")
			row.title:SetText(m.header)
			row.levels:SetText("")
			row.who:SetText("")
			row.status:SetText("")
			row.sel:Hide()
			row.line:Show()
			row:EnableMouse(false)
			return
		end
		row:EnableMouse(true)
		row.line:Hide()
		row.title:SetFontObject("WaypostFontText")
		local active = E.guide and E.guide.id == m.id
		row.title:SetText((active and "|cffffd100" or "") .. (m.title or m.id))
		row.levels:SetText(("%d-%d"):format(m.minLevel or 1, m.maxLevel or 60))
		row.who:SetText(m.races and table.concat(m.races, ", ") or (m.classes and whoFor(m)) or (m.zone ~= m.title and m.zone) or "")
		local p = progressOf(m)
		if active then
			row.status:SetText("|cffffd100" .. L["Active"] .. "|r")
		elseif p and p >= 1 then
			row.status:SetText("|cff40ff40" .. L["Done"] .. "|r")
		elseif p and p > 0 then
			row.status:SetText(("%d%%"):format(math.floor(p * 100 + 0.5)))
		else
			row.status:SetText("")
		end
		row.sel:SetShown(state.selected == m)
	end)

	-- detail
	detail = CreateFrame("Frame", nil, win, "BackdropTemplate")
	detail:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
	detail:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 14)
	UI.Backdrop(detail, "inset")
	detail.title = detail:CreateFontString(nil, "ARTWORK", "WaypostFontHead")
	detail.title:SetPoint("TOPLEFT", 12, -10)
	detail.info = detail:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
	detail.info:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -6)
	detail.info:SetPoint("RIGHT", -12, 0)
	detail.info:SetJustifyH("LEFT")
	detail.info:SetJustifyV("TOP")
	detail.info:SetSpacing(3)
	detail.info:SetWordWrap(true)
	detail.info:SetHeight(54)
	detail.start = UI.Button(detail, L["Start guide"], 130, 24, function()
		local m = state.selected
		if not m then return end
		E.Load(m.id)
		W.StepFrame.Toggle(true)
		win:Hide()
	end)
	detail.start:SetPoint("BOTTOMRIGHT", -10, 8)
	detail.restart = UI.Button(detail, L["Restart"], 90, 24, function()
		local m = state.selected
		if not m then return end
		E.Load(m.id, true)
		W.StepFrame.Toggle(true)
		win:Hide()
	end)
	detail.restart:SetPoint("RIGHT", detail.start, "LEFT", -6, 0)
	UI.Tooltip(detail.restart, L["Restart"], L["Forget this guide's progress and scan it again from the first step."])
	detail.remove = UI.Button(detail, L["Delete"], 80, 24, function()
		local m = state.selected
		if not m or m.category ~= "Custom" then return end
		W.db.custom[m.id] = nil
		if E.guide and E.guide.id == m.id then E.Unload() end
		G.Unregister(m.id)
		state.selected = nil
		refresh()
	end)
	detail.remove:SetPoint("RIGHT", detail.restart, "LEFT", -6, 0)
	detail.editor = UI.Button(detail, L["Write or import a guide"], 170, 24, function()
		win:Hide()
		W.Editor.Open(state.selected and state.selected.category == "Custom" and state.selected.id or nil)
	end)
	detail.editor:SetPoint("BOTTOMLEFT", 10, 8)
	local settings = UI.IconButton(win, 13, "gear", function() W.Options.Toggle(true) end)
	settings:SetPoint("RIGHT", win.close, "LEFT", -2, 0)
	UI.Tooltip(settings, L["Settings"], nil, "ANCHOR_BOTTOMLEFT")

	local cats = G.Categories()
	local hasCustom = false
	for _, c in ipairs(cats) do if c == "Custom" then hasCustom = true end end
	if not hasCustom then table.insert(cats, math.min(#cats + 1, 3), "Custom") end
	for i, c in ipairs(cats) do makeCat(c, i) end

	win:HookScript("OnShow", function() refresh() end)
end

function P.Toggle(show)
	if not win then build() end
	if show == nil then show = not win:IsShown() end
	if show then
		if E.guide then
			state.category = E.guide.category or "Leveling"
			state.selected = G.Meta(E.guide.id)
		end
		win:Show()
		refresh()
		if state.selected then
			for i, it in ipairs(listView.items) do
				if it == state.selected then listView.ScrollTo(i) break end
			end
		end
	else
		win:Hide()
	end
end

W.On("WP_GUIDE", function() refresh(true) end)
W.On("WP_GUIDES_CHANGED", function() refresh(true) end)
