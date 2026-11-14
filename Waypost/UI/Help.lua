-- Welcome and help.
--
-- The first time a character logs in, a welcome window explains how Waypost
-- works in four lines and offers the right guide. The same window is the
-- help: topics on the left, text on the right (/waypost help).

local W = Waypost
local L = W.L
local UI, E, G = W.UI, W.Engine, W.Guides
local Col = UI.C
local H = {}
W.Help = H

local win, topicButtons, bodyText, bodyScroll, welcomePane, textPane, current

local function gold(s) return UI.Hex(Col.gold) .. s .. "|r" end

local function commandsText()
	local lines = {}
	for _, h in ipairs(W.Commands and W.Commands.HELP or {}) do
		lines[#lines + 1] = gold("/waypost " .. h[1]) .. "\n" .. L[h[2]] .. "\n"
	end
	return table.concat(lines, "\n")
end

local TOPICS = {
	{ key = "welcome", title = "Welcome" },
	{ key = "window", title = "The guide window", text = function() return table.concat({
		gold(L["What to do now"]),
		L["The highlighted card is the one thing to do right now. It names the quest, enemy or item, who gives or takes the quest, what drops the item, and how far away it is and in which direction."],
		"",
		gold(L["The rest of the step"]),
		L["Under the card are the step's other goals. Each ticks itself off when the game confirms it. The box at the end of a line ticks it by hand, for the few things the game cannot confirm."],
		"",
		gold(L["Moving around"]),
		L["The arrows at the bottom move back and forward. Shift-click the forward arrow to look ahead without losing your place. Steps opens the whole list. Click the guide's name at the top to change guide."],
		"",
		gold(L["Layouts"]),
		L["Simple shows only what to do now and where. Standard adds the step's tip, its other goals and what comes next. Detailed shows everything, with a live XP bar. Switch in the ... menu, or with the minus button at the top. In Settings, tick the parts you want to make your own layout."],
		"",
		gold(L["Size and place"]),
		L["Drag the window by its title. Drag the bottom-right corner to make it wider or narrower, and the bottom edge of the step list to show more steps. Every other Waypost window resizes from its corner too; double-click a corner to reset it."],
	}, "\n") end },
	{ key = "arrow", title = "Arrow and map", text = function() return table.concat({
		L["The gold arrow points at your next objective and turns as you turn. Under it are the distance and roughly how long it takes to get there. It points down and turns green when you arrive."],
		"",
		L["Drag the arrow to move it; right-click it for options. Pins for the step are on the world map and the minimap, with faint dots where a step's enemies or items are found."],
		"",
		L["If you use TomTom, Settings can hand the waypoint to TomTom's arrow instead."],
	}, "\n") end },
	{ key = "xp", title = "XP tracker", text = function() return table.concat({
		L["The live XP tracker shows your XP bar with rested experience, XP per hour over the last ten minutes, and the time to your next level counting down. The number goes up as you earn experience and drops while you stand still, so it always says how fast you are going right now."],
		"",
		L["Under that: a bar for each of the last ten minutes, what you have earned this session from quests and from kills, and about how many kills or quests are left to level. Each gain pops up over the bar."],
		"",
		gold(L["Open it"]),
		L["Click the XP per hour at the bottom of the guide window, choose Live XP tracker in the ... menu, or type /waypost tracker. Drag its corner to make it wider. The chart button opens a graph of how long each level took."],
	}, "\n") end },
	{ key = "auto", title = "What it does for you", text = function() return table.concat({
		L["Quests from your guide are accepted and handed in for you. It stops when there is a reward to choose, and it never touches quests that are not in the guide."],
		"",
		gold(L["Hold Shift while you open an NPC to do it all by hand."]),
		"",
		L["A button appears when a step needs a quest item used, and another to target the step's enemy or NPC. Both can be bound to keys in the game's key bindings, under Waypost."],
		"",
		L["At a flight master it learns your flight points and takes the flight the guide wants."],
	}, "\n") end },
	{ key = "stuck", title = "When you are stuck", text = function() return table.concat({
		gold(L["Skip"]),
		L["Drops the step for good. Any quest it needed is left out of later steps too, so nothing further on waits for it. Undo in the menu brings it back."],
		"",
		gold(L["Later"]),
		L["Sets the step's quests aside instead. Waypost offers them back when you join a party, or once you are two levels higher. The list is in the menu under Quests set aside."],
		"",
		gold(L["Group quests"]),
		L["Quests that need a group are left out while you are alone and set aside automatically. Join a party and Waypost tells you they can be done."],
		"",
		gold(L["Behind on level"]),
		L["When the route needs a level you have not reached, the card shows how much experience you are short and offers the quests you set aside and the nearest enemies of your level."],
		"",
		gold(L["Did quests without Waypost?"]),
		L["Choose Re-read my quest log in the menu and the guide catches up."],
	}, "\n") end },
	{ key = "group", title = "Party and guild", text = function() return table.concat({
		L["In a party, Party progress shows which guide and step everyone is on. Sync party to my guide asks them to join yours, and Share quest sends a quest a friend is missing."],
		"",
		L["The guild leveling board lists guild members using Waypost with their level and guide. Officers can pick a guide for the whole guild and send notices."],
		"",
		L["Both need everyone to have Waypost. Members without it show as no data."],
	}, "\n") end },
	{ key = "own", title = "Your own guides", text = function() return table.concat({
		L["Guide editor in the menu lets you write a route in plain text, check it, and share it as a string a friend can paste in."],
		"",
		L["/waypost record start records what you do as a draft guide; /waypost record stop opens it in the editor."],
		"",
		L["/waypost where prints your coordinates in the form the editor uses."],
	}, "\n") end },
	{ key = "commands", title = "Commands", text = commandsText },
}

---------------------------------------------------------------------------
local function showTopic(key)
	current = key
	for _, b in ipairs(topicButtons) do
		local on = b.key == key
		b.sel:SetShown(on)
		local c = on and Col.gold or Col.text
		b.text:SetTextColor(c[1], c[2], c[3])
	end
	if key == "welcome" then
		textPane:Hide()
		welcomePane:Show()
		local m = G.Suggest()
		if E.guide then
			welcomePane.guide:SetText((L["You are on %s."]):format(gold(E.guide.title or E.guide.id)))
			welcomePane.start:SetText(L["Show my guide"])
		elseif m then
			welcomePane.guide:SetText((L["The guide for your character is %s, levels %d to %d."]):format(gold(m.title or m.id), m.minLevel or 1, m.maxLevel or 60))
			welcomePane.start:SetText(L["Start this guide"])
		else
			welcomePane.guide:SetText(L["Pick a guide to begin."])
			welcomePane.start:SetText(L["Choose a guide"])
		end
		return
	end
	welcomePane:Hide()
	textPane:Show()
	for _, t in ipairs(TOPICS) do
		if t.key == key then
			bodyText:SetText(t.text())
			bodyScroll.UpdateRange(bodyText:GetStringHeight() + 16)
			bodyScroll.bar:SetValue(0)
		end
	end
end

local function point(parent, y, icon, color, title, text)
	local i = UI.Icon(parent, icon, 22, "ARTWORK", color)
	i:SetPoint("TOPLEFT", 4, -y - 2)
	local t = parent:CreateFontString(nil, "ARTWORK", "WaypostFontGold")
	t:SetPoint("TOPLEFT", 40, -y)
	t:SetText(title)
	local d = parent:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
	d:SetPoint("TOPLEFT", 40, -y - 17)
	d:SetPoint("RIGHT", -6, 0)
	d:SetJustifyH("LEFT")
	d:SetWordWrap(true)
	d:SetSpacing(2)
	d:SetText(text)
	d:SetTextColor(Col.dim[1], Col.dim[2], Col.dim[3])
end

local function build()
	win = UI.Window("WaypostHelp", L["Waypost"], 640, 440)

	local side = CreateFrame("Frame", nil, win)
	side:SetPoint("TOPLEFT", 14, -40)
	side:SetPoint("BOTTOMLEFT", 14, 14)
	side:SetWidth(160)
	UI.Backdrop(side, "well")
	topicButtons = {}
	for i, t in ipairs(TOPICS) do
		local b = CreateFrame("Button", nil, side)
		b:SetHeight(24)
		b:SetPoint("TOPLEFT", 4, -5 - (i - 1) * 25)
		b:SetPoint("TOPRIGHT", -4, -5 - (i - 1) * 25)
		b.sel = UI.RowSelection(b)
		local hover = b:CreateTexture(nil, "HIGHLIGHT")
		hover:SetTexture(UI.WHITE)
		hover:SetAllPoints()
		hover:SetVertexColor(Col.raise[1], Col.raise[2], Col.raise[3], 0.7)
		b.text = b:CreateFontString(nil, "ARTWORK", "WaypostFontText")
		b.text:SetPoint("LEFT", 9, 0)
		b.text:SetText(L[t.title])
		b.key = t.key
		b:SetScript("OnClick", function() showTopic(t.key) end)
		topicButtons[i] = b
	end

	-- Welcome page
	welcomePane = CreateFrame("Frame", nil, win)
	welcomePane:SetPoint("TOPLEFT", side, "TOPRIGHT", 14, 0)
	welcomePane:SetPoint("BOTTOMRIGHT", -14, 14)
	local logo = welcomePane:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(UI.MEDIA .. "Logo")
	logo:SetSize(56, 56)
	logo:SetPoint("TOPLEFT", 0, -2)
	local title = welcomePane:CreateFontString(nil, "ARTWORK", "WaypostFontHead")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -6)
	title:SetText(L["Welcome to Waypost"])
	local sub = welcomePane:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
	sub:SetPoint("RIGHT", 0, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText(L["A leveling guide that walks you from 1 to 60. Here is how it works."])
	sub:SetTextColor(Col.dim[1], Col.dim[2], Col.dim[3])

	point(welcomePane, 74, "nav", Col.gold, L["Follow the arrow"],
		L["The gold arrow points at your next objective. The guide window says what to do there and how far it is."])
	point(welcomePane, 128, "check", Col.good, L["It keeps track for you"],
		L["Guide quests are picked up and handed in for you, and goals tick off as you do them. Hold Shift at an NPC to do it yourself."])
	point(welcomePane, 182, "skip", Col.warn, L["Stuck? Skip it, or save it for later"],
		L["Skip drops a step. Later sets its quests aside and offers them back when you group up or gain levels."])
	point(welcomePane, 236, "dots", Col.text, L["Everything else is in the menu"],
		L["Guides, settings, layouts, party and guild are behind the ... button on the guide window. The game menu (Esc) has a Waypost button for settings, and /waypost works anywhere."])

	local line = welcomePane:CreateTexture(nil, "ARTWORK")
	line:SetTexture(UI.WHITE)
	line:SetVertexColor(Col.trim[1], Col.trim[2], Col.trim[3], 0.4)
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", 0, 62)
	line:SetPoint("BOTTOMRIGHT", 0, 62)
	welcomePane.guide = welcomePane:CreateFontString(nil, "ARTWORK", "WaypostFontText")
	welcomePane.guide:SetPoint("BOTTOMLEFT", 0, 38)
	welcomePane.guide:SetPoint("RIGHT", 0, 0)
	welcomePane.guide:SetJustifyH("LEFT")
	welcomePane.guide:SetWordWrap(false)
	welcomePane.start = UI.Button(welcomePane, L["Start this guide"], 170, 26, function()
		if not E.guide then
			local m = G.Suggest()
			if m then E.Load(m.id) else W.Picker.Toggle(true) end
		end
		W.StepFrame.Toggle(true)
		win:Hide()
	end)
	welcomePane.start:SetPoint("BOTTOMLEFT", 0, 0)
	local other = UI.Button(welcomePane, L["Choose another"], 140, 26, function()
		win:Hide()
		W.StepFrame.Toggle(true)
		W.Picker.Toggle(true)
	end)
	other:SetPoint("LEFT", welcomePane.start, "RIGHT", 8, 0)

	-- Text page
	textPane = CreateFrame("Frame", nil, win)
	textPane:SetPoint("TOPLEFT", side, "TOPRIGHT", 10, 0)
	textPane:SetPoint("BOTTOMRIGHT", -14, 14)
	UI.Backdrop(textPane, "well")
	bodyScroll = UI.Scroll(textPane)
	bodyScroll:SetPoint("TOPLEFT", 12, -10)
	bodyScroll:SetPoint("BOTTOMRIGHT", -18, 10)
	bodyText = bodyScroll.child:CreateFontString(nil, "ARTWORK", "WaypostFontText")
	bodyText:SetPoint("TOPLEFT", 0, 0)
	bodyText:SetWidth(400)
	bodyText:SetJustifyH("LEFT")
	bodyText:SetJustifyV("TOP")
	bodyText:SetWordWrap(true)
	bodyText:SetSpacing(4)
	bodyScroll:HookScript("OnSizeChanged", function(_, w) bodyText:SetWidth(math.max(100, w - 4)) end)
	textPane:Hide()
end

function H.Open(topic)
	if not win then build() end
	win:Show()
	showTopic(topic or current or "welcome")
end

function H.Toggle()
	if win and win:IsShown() then win:Hide() else H.Open() end
end

-- First login on a character: say hello. First guide started: one pointer.
W.On("WP_ENGINE_READY", function()
	-- once per account: the second character already knows
	if W.db.seenWelcome then return end
	W.db.seenWelcome = true
	W.After(2.5, function()
		if not W.InCombat() then H.Open("welcome") end
	end)
end)

W.On("WP_GUIDE", function(guide)
	if not guide or W.db.coached or not W.db.seenWelcome then return end
	W.db.coached = true
	W.After(1, function()
		UI.Toast(L["Follow the gold arrow"], L["The guide window says what to do now and where. The ... button has everything else."], nil,
			function() H.Open("window") end, 12)
	end)
end)
