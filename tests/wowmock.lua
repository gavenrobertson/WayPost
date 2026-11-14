-- A small stand-in for the WoW client API, enough to load every Waypost file
-- and drive the engine and UI code paths from plain Lua 5.1.
-- Usage: local M = dofile("tests/wowmock.lua"); M.load(); M.login() ...

local M = { clock = 0, wall = 1700000000, timers = {}, frames = {}, chat = {}, sent = {} }

---------------------------------------------------------------------------
-- Game state the tests poke at
---------------------------------------------------------------------------
M.player = { name = "Tester", realm = "Mockrealm", class = "WARRIOR", race = "Human", faction = "Alliance", level = 1,
	xp = 0, xpMax = 400, money = 0, map = 1429, x = 0.482, y = 0.429, facing = 0, guild = nil, guildRank = 0,
	inGroup = false, combat = false, bind = "Northshire Valley", zone = "Elwynn Forest", subzone = "Northshire Abbey" }
M.quests = {}        -- [id] = { title=, complete=, objectives = { {text=, finished=, numFulfilled=, numRequired=, type=} } }
M.completed = {}     -- [id] = true
M.items = {}         -- [id] = count
M.spells = {}
M.shift = false
M.addons = {}        -- loaded LoD addons
M.gossip = { available = {}, active = {}, options = {} }
M.selected = {}

---------------------------------------------------------------------------
-- Widgets: every method exists; a few keep real state.
---------------------------------------------------------------------------
local Widget = {}
local function noop() end

local function newWidget(kind, name, parent)
	local w = { _kind = kind, _name = name, _parent = parent, _shown = true, _scripts = {}, _text = "", _w = 100, _h = 20,
		_attrs = {}, _min = 0, _max = 0, _value = 0, _checked = false, _alpha = 1, _scale = 1 }
	setmetatable(w, Widget)
	M.frames[#M.frames + 1] = w
	if name then _G[name] = w end
	return w
end
M.newWidget = newWidget

local real = {}
function real:Show() local was = self._shown; self._shown = true; if not was and self._scripts.OnShow then self._scripts.OnShow(self) end end
function real:Hide() local was = self._shown; self._shown = false; if was and self._scripts.OnHide then self._scripts.OnHide(self) end end
function real:SetShown(v) if v then self:Show() else self:Hide() end end
function real:IsShown() return self._shown end
function real:IsVisible() return self._shown end
function real:SetText(t) self._text = tostring(t or ""); if self._scripts.OnTextChanged then self._scripts.OnTextChanged(self, false) end end
function real:GetText() return self._text end
function real:SetScript(k, fn) self._scripts[k] = fn end
function real:GetScript(k) return self._scripts[k] end
function real:HookScript(k, fn)
	local old = self._scripts[k]
	self._scripts[k] = old and function(...) old(...) return fn(...) end or fn
end
function real:SetSize(w, h) self._w, self._h = w, h end
function real:SetWidth(w) self._w = w end
function real:SetHeight(h) self._h = h end
function real:GetWidth() return self._w end
function real:GetHeight() return self._h end
function real:GetSize() return self._w, self._h end
function real:GetStringHeight() return 12 * math.max(1, math.ceil(#self._text / 40)) end
function real:GetStringWidth() return #self._text * 6 end
function real:GetLeft() return 100 end
function real:GetTop() return 500 end
function real:GetCenter() return 400, 300 end
function real:GetEffectiveScale() return 1 end
function real:GetScale() return self._scale end
function real:SetScale(s) self._scale = s end
function real:SetAlpha(a) self._alpha = a end
function real:GetAlpha() return self._alpha end
function real:GetParent() return self._parent end
function real:GetName() return self._name end
function real:GetFrameLevel() return 1 end
function real:SetAttribute(k, v) self._attrs[k] = v end
function real:GetAttribute(k) return self._attrs[k] end
function real:SetMinMaxValues(a, b) self._min, self._max = a, b end
function real:GetMinMaxValues() return self._min, self._max end
function real:SetValue(v)
	v = math.max(self._min, math.min(self._max, v))
	local changed = v ~= self._value
	self._value = v
	if changed and self._scripts.OnValueChanged then self._scripts.OnValueChanged(self, v) end
end
function real:GetValue() return self._value end
function real:SetChecked(v) self._checked = v and true or false end
function real:GetChecked() return self._checked end
function real:IsMouseOver() return false end
function real:IsEnabled() return self._disabled ~= true end
function real:Enable() self._disabled = false; if self._scripts.OnEnable then self._scripts.OnEnable(self) end end
function real:Disable() self._disabled = true; if self._scripts.OnDisable then self._scripts.OnDisable(self) end end
function real:SetEnabled(v) if v then self:Enable() else self:Disable() end end
function real:GetFrameStrata() return "DIALOG" end
function real:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function real:SetFont() return true end
function real:GetVerticalScroll() return 0 end
function real:GetZoom() return 0 end
function real:GetMapID() return M.player.map end
function real:GetCanvas() self._canvas = self._canvas or newWidget("Frame", nil, self); self._canvas._w, self._canvas._h = 1000, 667; return self._canvas end
function real:GetCanvasScale() return 1 end
function real:Click(button)
	if self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton") end
end
function real:Cancel() self._cancelled = true end
for _, maker in ipairs({ "CreateTexture", "CreateFontString", "GetThumbTexture", "GetNormalTexture", "GetPushedTexture",
	"GetHighlightTexture", "GetCheckedTexture", "CreateAnimationGroup", "CreateAnimation" }) do
	real[maker] = function(self)
		local key = "_" .. maker
		if maker:find("^Get") then
			self[key] = self[key] or newWidget("Texture", nil, self)
			return self[key]
		end
		return newWidget(maker == "CreateFontString" and "FontString" or "Texture", nil, self)
	end
end

Widget.__index = function(_, k)
	if real[k] then return real[k] end
	if type(k) == "string" and (k:find("^Set") or k:find("^Register") or k:find("^Enable") or k:find("^Clear") or k:find("^Start")
		or k:find("^Stop") or k:find("^Unregister") or k:find("^Add") or k:find("^Highlight") or k:find("^Disable")
		or k:find("^Raise") or k:find("^Lower") or k:find("^Insert") or k == "Play" or k == "Enable" or k == "Disable") then
		return noop
	end
	if type(k) == "string" and k:find("^Is") then return function() return false end end
	if type(k) == "string" and k:find("^Get") then return function() return 0 end end
	return nil
end

---------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------
local TEMPLATES = { BackdropTemplate = 1, UIPanelButtonTemplate = 1, UIPanelCloseButton = 1, SecureActionButtonTemplate = 1, CooldownFrameTemplate = 1 }

function M.install()
	local G = _G
	G.CreateFrame = function(kind, name, parent, template)
		if template and not TEMPLATES[template] then error("unknown template " .. tostring(template)) end
		local w = newWidget(kind, name, parent)
		if template == "BackdropTemplate" then w.SetBackdrop = noop; w.SetBackdropColor = noop; w.SetBackdropBorderColor = noop end
		return w
	end
	G.CreateFont = function(name) return newWidget("Font", name) end
	G.UIParent = newWidget("Frame", "UIParent")
	G.Minimap = newWidget("Frame", "Minimap")
	G.WorldMapFrame = newWidget("Frame", "WorldMapFrame")
	G.WorldMapFrame._shown = false
	G.GameTooltip = newWidget("GameTooltip", "GameTooltip")
	G.GameMenuFrame = newWidget("Frame", "GameMenuFrame")
	G.GameMenuFrame._shown = false
	G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
	G.HideUIPanel = function(f) f:Hide() end
	G.ITEM_QUALITY_COLORS = { [1] = { hex = "|cffffffff" }, [2] = { hex = "|cff1eff00" } }
	G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) M.chat[#M.chat + 1] = msg end }
	G.UISpecialFrames = {}
	G.StaticPopupDialogs = { ABANDON_QUEST = {} }
	G.StaticPopup_Show = function(which, ...) M.popup = { which = which, args = { ... } } end
	G.SlashCmdList = {}
	G.SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857, IG_CHARACTER_INFO_OPEN = 839,
		IG_CHARACTER_INFO_CLOSE = 840, MAP_PING = 3175, IG_QUEST_LIST_OPEN = 875 }
	G.PlaySound = noop
	G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
	G.tinsert = table.insert
	G.strsplit = function(sep, s)
		local out = {}
		for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
		return unpack(out)
	end
	G.unpack = unpack
	G.GetTime = function() return M.clock end
	G.time = function() return M.wall + math.floor(M.clock) end
	G.GetLocale = function() return M.locale or "enUS" end
	G.GetBuildInfo = function() return "1.60.1", "70532", "Oct 23 2026", 16001 end
	G.geterrorhandler = function() return function(e) error(e, 0) end end
	G.hooksecurefunc = function(a, b, c)
		if type(a) == "string" then local old = G[a]; G[a] = function(...) local r = { old(...) } b(...) return unpack(r) end end
	end
	G.InCombatLockdown = function() return M.player.combat end
	G.IsShiftKeyDown = function() return M.shift end
	G.UnitClass = function() return "Warrior", M.player.class end
	G.UnitRace = function() return M.player.race, M.player.race end
	G.UnitFactionGroup = function() return M.player.faction end
	G.UnitLevel = function() return M.player.level end
	G.UnitName = function(u) if u == "player" then return M.player.name end return M.npc and M.npc[u] end
	G.UnitGUID = function() return nil end
	G.GetRealmName = function() return M.player.realm end
	G.UnitXP = function() return M.player.xp end
	G.UnitXPMax = function() return M.player.xpMax end
	G.GetXPExhaustion = function() return M.player.rested end
	G.UnitPosition = function() return nil end
	G.UnitOnTaxi = function() return M.player.taxi end
	G.GetUnitSpeed = function() return 7 end
	G.GetPlayerFacing = function() return M.player.facing end
	G.GetMoney = function() return M.player.money end
	G.GetBindLocation = function() return M.player.bind end
	G.GetRealZoneText = function() return M.player.zone end
	G.GetZoneText = function() return M.player.zone end
	G.GetSubZoneText = function() return M.player.subzone end
	G.IsInGroup = function() return M.player.inGroup end
	G.IsInGuild = function() return M.player.guild ~= nil end
	G.GetGuildInfo = function() return M.player.guild, "Officer", M.player.guildRank end
	G.GetNumGuildMembers = function() return 0 end
	G.GetNumSubgroupMembers = function() return 0 end
	G.GetCVar = function() return "0" end
	G.IsIndoors = function() return false end
	G.GetCursorPosition = function() return 0, 0 end
	G.GetBindingKey = function() return nil end
	G.GetQuestID = function() return M.questFrameID or 0 end
	G.AcceptQuest = function() M.selected[#M.selected + 1] = "accept:" .. tostring(M.questFrameID) end
	G.CompleteQuest = function() M.selected[#M.selected + 1] = "complete:" .. tostring(M.questFrameID) end
	G.GetQuestReward = function(i) M.selected[#M.selected + 1] = "reward:" .. tostring(i) end
	G.GetNumQuestChoices = function() return M.questChoices or 0 end
	G.IsQuestCompletable = function() return true end
	G.GetQuestItemLink = function() return nil end
	G.NumTaxiNodes = function() return M.taxi and #M.taxi or 0 end
	G.TaxiNodeName = function(i) return M.taxi[i].name end
	G.TaxiNodeGetType = function(i) return M.taxi[i].kind end
	G.TakeTaxiNode = function(i) M.selected[#M.selected + 1] = "taxi:" .. M.taxi[i].name end
	G.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
	G.RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
	G.Enum = { SendAddonMessageResult = { Success = 0 }, CompressionMethod = { Deflate = 0 } }

	G.C_Timer = {
		After = function(sec, fn) M.timers[#M.timers + 1] = { at = M.clock + sec, fn = fn } end,
		NewTicker = function(sec, fn)
			local t = newWidget("Ticker")
			local function tick()
				if t._cancelled then return end
				fn(t)
				if not t._cancelled then M.timers[#M.timers + 1] = { at = M.clock + sec, fn = tick } end
			end
			M.timers[#M.timers + 1] = { at = M.clock + sec, fn = tick }
			return t
		end,
	}
	G.C_AddOns = {
		GetAddOnMetadata = function() return "test" end,
		IsAddOnLoaded = function(name) return M.addons[name] or false end,
		LoadAddOn = function(name)
			if M.addons[name] then return true end
			local ok, err = pcall(M.loadAddon, name)
			if not ok then return false, err end
			M.addons[name] = true
			return true
		end,
	}
	G.C_QuestLog = {
		IsQuestFlaggedCompleted = function(q) return M.completed[q] or false end,
		IsOnQuest = function(q) return M.quests[q] ~= nil end,
		ReadyForTurnIn = function(q) return M.quests[q] and M.quests[q].complete or false end,
		IsComplete = function(q) return M.quests[q] and M.quests[q].complete or false end,
		GetQuestObjectives = function(q) return M.quests[q] and M.quests[q].objectives or {} end,
		GetTitleForQuestID = function(q) return M.quests[q] and M.quests[q].title or nil end,
		GetNumQuestLogEntries = function() local n = 0 for _ in pairs(M.quests) do n = n + 1 end return n end,
		GetInfo = function(i)
			local ids = {}
			for id in pairs(M.quests) do ids[#ids + 1] = id end
			table.sort(ids)
			local id = ids[i]
			return id and { questID = id, title = M.quests[id].title or ("Quest " .. id), level = M.quests[id].level or 1 }
		end,
		SetSelectedQuest = function(q) M.selectedQuest = q end,
		SetAbandonQuest = noop, AbandonQuest = noop,
		IsPushableQuest = function() return true end,
	}
	G.QuestLogPushQuest = function() M.selected[#M.selected + 1] = "push:" .. tostring(M.selectedQuest) end
	G.C_Item = {
		GetItemCount = function(id) return M.items[id] or 0 end,
		GetItemIconByID = function() return 134400 end,
		GetItemInfo = function() return nil end,
	}
	G.C_SpellBook = { IsSpellKnown = function(id) return M.spells[id] or false end }
	G.C_Map = {
		GetBestMapForUnit = function() return M.player.map end,
		GetPlayerMapPosition = function() return G.CreateVector2D(M.player.x, M.player.y) end,
		GetMapInfo = function(id) return { name = "Map " .. id, mapID = id } end,
		-- Live maps answer with the same bounds as the Era frames (set by the test).
		GetWorldPosFromMapPos = function(map, v)
			local b = M.bounds and M.bounds[map]
			if not b then return nil end
			return b[1], G.CreateVector2D(b[4] + (b[5] - b[4]) * v.y, b[2] + (b[3] - b[2]) * v.x)
		end,
	}
	G.C_GossipInfo = {
		GetAvailableQuests = function() return M.gossip.available end,
		GetActiveQuests = function() return M.gossip.active end,
		GetOptions = function() return M.gossip.options end,
		SelectAvailableQuest = function(q) M.selected[#M.selected + 1] = "available:" .. q end,
		SelectActiveQuest = function(q) M.selected[#M.selected + 1] = "active:" .. q end,
		SelectOption = function(id) M.selected[#M.selected + 1] = "option:" .. id end,
	}
	G.C_ChatInfo = {
		RegisterAddonMessagePrefix = function() return true end,
		SendAddonMessage = function(prefix, msg, channel)
			if M.trial then return 9 end
			M.sent[#M.sent + 1] = { prefix = prefix, msg = msg, channel = channel }
			return 0
		end,
	}
end

---------------------------------------------------------------------------
-- Loading addons from their TOC
---------------------------------------------------------------------------
M.root = "."
function M.loadAddon(name)
	local dir = M.root .. "/" .. name
	local toc = assert(io.open(dir .. "/" .. name .. ".toc"), "no toc for " .. name)
	local ns = {}
	for line in toc:lines() do
		line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
		if line ~= "" and not line:find("^#") then
			local path = dir .. "/" .. line:gsub("\\", "/")
			local chunk = assert(loadfile(path))
			chunk(name, ns)
		end
	end
	toc:close()
	M.addons[name] = true
end

function M.fire(event, ...)
	local f = _G.WaypostEventFrame
	f._scripts.OnEvent(f, event, ...)
end

-- Advance the fake clock, running timers as they come due.
function M.advance(seconds)
	local target = M.clock + seconds
	while true do
		local best, bi
		for i, t in ipairs(M.timers) do
			if t.at <= target and (not best or t.at < best.at) then best, bi = t, i end
		end
		if not best then break end
		table.remove(M.timers, bi)
		M.clock = math.max(M.clock, best.at)
		best.fn()
	end
	M.clock = target
end

function M.login()
	M.fire("ADDON_LOADED", "Waypost")
	M.fire("PLAYER_LOGIN")
	M.advance(1)
end

-- Quest helpers
function M.accept(id, title, objectives)
	M.quests[id] = { title = title or ("Quest " .. id), objectives = objectives or {} }
	M.fire("QUEST_ACCEPTED", id)
	M.advance(0.5)
end
function M.turnin(id)
	M.quests[id] = nil
	M.completed[id] = true
	M.fire("QUEST_TURNED_IN", id)
	M.advance(0.5)
end
function M.update()
	M.fire("QUEST_LOG_UPDATE")
	M.advance(0.5)
end

return M
