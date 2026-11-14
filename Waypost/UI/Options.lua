-- One searchable settings window. Everything is declared in SECTIONS below;
-- the search box filters by label, so a setting is never more than a few
-- keystrokes away.

local W = Waypost
local L = W.L
local UI = W.UI
local O = {}
W.Options = O

local win, scroll, content, searchBox
local built = {}

local function pct(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end

local function sections()
	return {
		{ title = L["Guide window"],
			{ type = "dropdown", path = "ui.layout", label = L["Layout"], options = function()
					local out = {}
					for _, l in ipairs(W.StepFrame.LAYOUTS) do out[#out + 1] = { l[1], L[l[2]] } end
					return out
				end, set = function(v) W.StepFrame.SetLayout(v) O.Refresh() end,
				tip = L["Simple: what to do and where. Standard: plus the step's other goals and what comes next. Detailed: everything. Change any box below to make your own."] },
			{ type = "elements" },
			{ type = "slider", path = "ui.width", label = L["Window width"], min = 230, max = 600, step = 10,
				tip = L["You can also drag the guide window's bottom-right corner."] },
			{ type = "slider", path = "ui.listRows", label = L["Steps shown in the step list"], min = 4, max = 40, step = 1 },
			{ type = "dropdown", path = "ui.skin", label = L["Window style"], options = UI.SKINS },
			{ type = "slider", path = "ui.scale", label = L["Window scale"], min = 0.6, max = 1.6, step = 0.05, fmt = pct },
			{ type = "slider", path = "ui.alpha", label = L["Window opacity"], min = 0.3, max = 1, step = 0.05, fmt = pct },
			{ type = "dropdown", path = "ui.font", label = L["Text font"], options = UI.FACE_NAMES },
			{ type = "dropdown", path = "ui.headFont", label = L["Heading font"], options = UI.HEAD_NAMES,
				tip = L["Step titles, window titles and the level-up banner."] },
			{ type = "slider", path = "ui.fontSize", label = L["Font size"], min = 9, max = 20, step = 1,
				tip = L["Scales every line of guide text. Larger sizes help on small or distant screens."] },
			{ type = "check", path = "ui.locked", label = L["Lock the window in place"] },
			{ type = "check", path = "ui.hideInCombat", label = L["Hide the window in combat"] },
			{ type = "check", path = "ui.gameMenu", label = L["Waypost button in the game menu (Esc)"] },
			{ type = "check", path = "ui.ding", label = L["Level-up animation in the guide window"],
				tip = L["Preview it with /waypost ding."] },
			{ type = "button", label = L["Reset window position"], func = function() W.StepFrame.ResetPosition() end },
			{ type = "button", label = L["Reset all window sizes"], func = function()
					UI.ResetWindowSizes()
					W.opt.ui.width = W.defaults.ui.width
					W.opt.ui.listRows = W.defaults.ui.listRows
					W.Fire("WP_SETTINGS", "ui.width")
				end },
		},
		{ title = L["XP tracker"],
			{ type = "check", path = "tracker.shown", label = L["Show the live XP tracker"],
				tip = L["XP per hour over the last ten minutes, time to level counting down, XP each minute, and kills or quests to level. Also /waypost tracker."] },
			{ type = "check", path = "tracker.locked", label = L["Lock the tracker in place"] },
			{ type = "slider", path = "tracker.scale", label = L["Tracker scale"], min = 0.6, max = 1.6, step = 0.05, fmt = pct },
			{ type = "slider", path = "tracker.alpha", label = L["Tracker opacity"], min = 0.3, max = 1, step = 0.05, fmt = pct },
		},
		{ title = L["Arrow"],
			{ type = "check", path = "arrow.enabled", label = L["Show the arrow"] },
			{ type = "dropdown", path = "arrow.color", label = L["Arrow colour"], options = {
				{ "gold", L["Gold"] }, { "distance", L["By distance (green near, red far)"] } } },
			{ type = "check", path = "arrow.colorblind", label = L["Colourblind-safe colours (blue near, orange far)"] },
			{ type = "slider", path = "arrow.scale", label = L["Arrow size"], min = 0.5, max = 2, step = 0.05, fmt = pct },
			{ type = "slider", path = "arrow.alpha", label = L["Arrow opacity"], min = 0.2, max = 1, step = 0.05, fmt = pct },
			{ type = "check", path = "arrow.showDistance", label = L["Show distance"] },
			{ type = "check", path = "arrow.showETA", label = L["Show time to arrive"] },
			{ type = "check", path = "arrow.arriveSound", label = L["Play a sound on arrival"] },
			{ type = "check", path = "arrow.locked", label = L["Lock the arrow in place"] },
			{ type = "check", path = "arrow.tomtom", label = L["Hand waypoints to TomTom instead"],
				tip = L["Uses TomTom's arrow when TomTom is installed. Waypost's own arrow hides."] },
		},
		{ title = L["Map"],
			{ type = "check", path = "map.world", label = L["Pins on the world map"] },
			{ type = "check", path = "map.minimap", label = L["Pins on the minimap"] },
			{ type = "check", path = "map.spots", label = L["Show where enemies and items are found"] },
			{ type = "check", path = "map.upcoming", label = L["Show the next step's first stop"] },
		},
		{ title = L["Automation"],
			{ type = "check", path = "auto.accept", label = L["Accept guide quests automatically"],
				tip = L["Only quests in your guide. Hold Shift while talking to an NPC to do it by hand."] },
			{ type = "check", path = "auto.turnin", label = L["Turn in guide quests automatically"],
				tip = L["Stops at reward choices so you always pick your own reward."] },
			{ type = "check", path = "auto.gossip", label = L["Pick the quest from NPC dialogue"] },
			{ type = "check", path = "auto.flight", label = L["Take the guide's flight at the flight master"] },
			{ type = "check", path = "buttons.item", label = L["Quest item button"] },
			{ type = "check", path = "buttons.target", label = L["Target button"] },
			{ type = "check", path = "buttons.mark", label = L["Mark the target with a skull"] },
		},
		{ title = L["Route"],
			{ type = "check", path = "route.autoAdvance", label = L["Advance to the next step automatically"] },
			{ type = "check", path = "route.xpSkips", label = L["Skip quests that are too low level to be worth it"],
				tip = L["Leaves out quests that have turned grey for your level."] },
			{ type = "check", path = "route.groupQuests", label = L["Include group (elite) quests when solo"],
				tip = L["They are always included while you are in a party."] },
			{ type = "check", path = "route.saferRoute", label = L["Safer route (skip elite and group steps)"],
				tip = L["For Hardcore: leaves out group quests even in a party."] },
			{ type = "check", path = "route.dungeons", label = L["Include dungeon steps"] },
			{ type = "check", path = "route.hideOptional", label = L["Hide optional goals"] },
		},
		{ title = L["Character"],
			{ type = "check", path = "talents.enabled", label = L["Suggest talents when you level up"] },
			{ type = "check", path = "upgrades.enabled", label = L["Mark gear upgrades on quest rewards and vendors"] },
			{ type = "check", path = "upgrades.pawn", label = L["Use Pawn's scores when Pawn is installed"] },
		},
		{ title = L["Party and guild"],
			{ type = "check", path = "group.sync", label = L["Share your step with your party"] },
			{ type = "check", path = "group.chat", label = L["Announce finished steps in party chat"] },
			{ type = "check", path = "guild.board", label = L["Share your progress on the guild leveling board"] },
			{ type = "check", path = "guild.banner", label = L["Show officer announcements"] },
		},
		{ title = L["Performance and sound"],
			{ type = "check", path = "combatUpdates", label = L["Keep updating during combat"],
				tip = L["On: objectives tick off the moment they happen. Off: Waypost does nothing during a fight and catches up when it ends."] },
			{ type = "check", path = "sound", label = L["Sounds"] },
			{ type = "check", path = "minimap.hide", label = L["Hide the minimap button"] },
		},
		{ title = L["Profiles"],
			{ type = "dropdown", label = L["Profile for this character"], options = function()
					local out = {}
					for _, n in ipairs(W.ProfileList()) do out[#out + 1] = { n, n } end
					return out
				end, get = function() return W.profileName end, set = function(v) W.SelectProfile(v) end,
				tip = L["Profiles are shared by all characters on the account."] },
			{ type = "button", label = L["New profile for this character"], func = function()
					W.SelectProfile(W.CharKey())
					O.Refresh()
				end },
			{ type = "button", label = L["Reset this profile to defaults"], func = function()
					W.ResetProfile()
					O.Refresh()
				end },
		},
	}
end

local function makeControl(def)
	if def.type == "elements" then return nil end
	local get = def.get or function() return W.Get(def.path) end
	local set = def.set or function(v) W.Set(def.path, v) end
	local c
	if def.type == "check" then
		c = UI.Check(content, def.label, get, set, def.tip)
		c.h = 25
	elseif def.type == "slider" then
		c = UI.Slider(content, def.label, def.min, def.max, def.step, get, set, def.fmt, def.tip)
		c:SetWidth(260)
		c.h = 44
	elseif def.type == "dropdown" then
		c = UI.Dropdown(content, def.label, 260, def.options, get, set, def.tip)
		c.h = 46
	elseif def.type == "button" then
		c = UI.Button(content, def.label, 240, 22, def.func)
		c.h = 28
	end
	c.def = def
	return c
end

local function layout()
	local filter = (searchBox:GetText() or ""):lower()
	local y = -4
	for _, sec in ipairs(built) do
		local shown = 0
		for _, c in ipairs(sec.controls) do
			local match = filter == "" or c.def.label:lower():find(filter, 1, true) or sec.title:lower():find(filter, 1, true)
			c:SetShown(match and true or false)
			if match then shown = shown + 1 end
		end
		sec.heading:SetShown(shown > 0)
		sec.y = -y
		if shown > 0 then
			sec.heading:ClearAllPoints()
			sec.heading:SetPoint("TOPLEFT", 4, y)
			sec.heading:SetPoint("TOPRIGHT", -8, y)
			y = y - 30
			for _, c in ipairs(sec.controls) do
				if c:IsShown() then
					c:ClearAllPoints()
					c:SetPoint("TOPLEFT", 10, y)
					y = y - c.h
				end
			end
			y = y - 10
		end
	end
	scroll.UpdateRange(-y + 10)
end

local function build()
	win = UI.Window("WaypostOptions", L["Waypost Settings"], 420, 540, { minW = 400, minH = 320 })
	searchBox = UI.EditBox(win, 240, 24, L["Search settings"])
	searchBox:SetPoint("TOPLEFT", 16, -38)
	searchBox:HookScript("OnTextChanged", function() layout() end)

	local help = UI.Button(win, L["Help"], 60, 22, function() W.Help.Open() end)
	help:SetPoint("TOPRIGHT", -14, -38)
	local guides = UI.Button(win, L["Guides"], 70, 22, function() W.StepFrame.Toggle(true) W.Picker.Toggle(true) end)
	guides:SetPoint("RIGHT", help, "LEFT", -6, 0)
	searchBox:SetPoint("RIGHT", guides, "LEFT", -10, 0)

	local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 14, -68)
	box:SetPoint("BOTTOMRIGHT", -14, 46)
	UI.Backdrop(box, "inset")
	scroll, content = UI.Scroll(box)
	scroll:SetPoint("TOPLEFT", 8, -8)
	scroll:SetPoint("BOTTOMRIGHT", -24, 8)

	for _, sec in ipairs(sections()) do
		local entry = { title = sec.title, heading = UI.Heading(content, sec.title), controls = {} }
		for _, def in ipairs(sec) do
			if def.type == "elements" then
				-- one box per part of the guide window; ticking any makes a Custom layout
				for _, el in ipairs(W.StepFrame.ELEMENTS) do
					local key = el[1]
					local c = makeControl({ type = "check", label = "   " .. L[el[2]],
						get = function() return W.StepFrame.Layout()[key] and true or false end,
						set = function(v) W.StepFrame.SetElement(key, v) O.Refresh() end })
					entry.controls[#entry.controls + 1] = c
				end
				local c = makeControl({ type = "slider", label = "   " .. L["Upcoming steps shown"], min = 0, max = 8, step = 1,
					get = function() return W.StepFrame.Layout().next or 0 end,
					set = function(v)
						if v ~= (W.StepFrame.Layout().next or 0) then W.StepFrame.SetElement("next", v) end
					end })
				entry.controls[#entry.controls + 1] = c
			else
				entry.controls[#entry.controls + 1] = makeControl(def)
			end
		end
		built[#built + 1] = entry
	end

	local about = UI.Button(win, L["About and credits"], 140, 22, function() W.About.Show() end)
	about:SetPoint("BOTTOMLEFT", 14, 14)
	local keys = UI.Button(win, L["Key bindings"], 110, 22, function()
		win:Hide()
		if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
			pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID)
		else
			W.Print(L["Open the game menu, then Options > Keybindings > Waypost."])
		end
	end)
	keys:SetPoint("LEFT", about, "RIGHT", 6, 0)
	local done = UI.Button(win, CLOSE or L["Close"], 90, 22, function() win:Hide() end)
	done:SetPoint("BOTTOMRIGHT", -14, 14)

	win:HookScript("OnShow", function() layout() end)
end

function O.Refresh()
	if not win then return end
	for _, sec in ipairs(built) do
		for _, c in ipairs(sec.controls) do
			if c.Refresh then c:Refresh() end
		end
	end
end

function O.Toggle(show, section)
	if W.InCombat() and not win then
		W.Print(L["Settings open after combat."])
		return
	end
	if not win then build() end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then
		O.Refresh()
		layout()
		if section then
			searchBox:SetText("")
			for _, sec in ipairs(built) do
				if sec.title == section and sec.y then scroll.bar:SetValue(math.max(0, sec.y - 4)) end
			end
		end
	end
end

W.On("WP_SETTINGS", function(path) if path == "*" then O.Refresh() end end)

-- An entry in the game's own AddOns options that opens this window.
W.On("WP_LOGIN", function()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	panel:Hide()
	local title = panel:CreateFontString(nil, "ARTWORK", "WaypostFontHead")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Waypost")
	local sub = panel:CreateFontString(nil, "ARTWORK", "WaypostFontText")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	sub:SetText(L["Free leveling guides for WoW Forever. Type /waypost for help."])
	local function leave()
		if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
	end
	local open = UI.Button(panel, L["Waypost settings"], 200, 26, function() leave() O.Toggle(true) end)
	open:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
	local guides = UI.Button(panel, L["Choose a guide"], 200, 26, function() leave() W.StepFrame.Toggle(true) W.Picker.Toggle(true) end)
	guides:SetPoint("LEFT", open, "RIGHT", 8, 0)
	local show = UI.Button(panel, L["Show the guide window"], 200, 26, function() leave() W.StepFrame.Toggle(true) end)
	show:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -8)
	local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Waypost")
	if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
end)

---------------------------------------------------------------------------
-- About / credits
---------------------------------------------------------------------------
local A = {}
W.About = A
function A.Show()
	local text = table.concat({
		"Waypost " .. W.version,
		"Free, open leveling guides for World of Warcraft: Forever.",
		"License: GPL-3.0-only. Source: https://github.com/gavenrobertson/waypost",
		"",
		"ROUTES",
		"The 1-60 leveling routes and the class, profession, reputation and exploration guides are",
		"converted from Polestar Guides (https://github.com/fitzforge/polestar), (c) The Polestar",
		"authors, GPL-3.0. Thank you to Fitz and the Polestar contributors.",
		"",
		"QUEST DATA",
		"Quest, NPC and item facts in those routes come from the pfQuest database by Shagu (MIT)",
		"as compiled by Polestar. Game data (c) Blizzard Entertainment, used as facts.",
		"",
		"TALENT PLANS",
		"Plans follow ForeverDB's leveling builds (https://foreverdb.net) as extended by Polestar.",
		"",
		"Nothing in Waypost is taken from RestedXP's guides.",
		"",
		"World of Warcraft is a trademark of Blizzard Entertainment. Waypost is not affiliated with Blizzard.",
	}, "\n")
	UI.CopyText(L["About Waypost"], text, L["Credits and licenses"])
end
