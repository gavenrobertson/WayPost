-- Guild mode:
--   * leveling board: who is on which guide and level (remembered between sessions)
--   * guild route: officers pick a guide the whole guild is pointed to
--   * officer announcements shown as a notice
-- Officers are the guild master and the two ranks below.

local W = Waypost
local L = W.L
local UI, E, G, Cm = W.UI, W.Engine, W.Guides, W.Comm
local Gd = {}
W.Guild = Gd

local OFFICER_RANK = 2
local win, view, header, pickBtn

local function guildName()
	if not (IsInGuild and IsInGuild()) then return nil end
	return W.Readable(GetGuildInfo and GetGuildInfo("player"))
end

local function store()
	local g = guildName()
	if not g then return nil end
	W.db.guild[g] = W.db.guild[g] or { board = {} }
	W.db.guild[g].board = W.db.guild[g].board or {}
	return W.db.guild[g]
end

local function rankOf(name)
	if not GetNumGuildMembers then return nil end
	for i = 1, GetNumGuildMembers() or 0 do
		local full, _, rankIndex = GetGuildRosterInfo(i)
		if full and (full == name or Cm.ShortName(full) == name) then return rankIndex end
	end
	return nil
end

function Gd.IsOfficer(name)
	if not name or name == W.player.name then
		local _, _, rankIndex = GetGuildInfo("player")
		return rankIndex ~= nil and rankIndex <= OFFICER_RANK
	end
	local r = rankOf(name)
	return r ~= nil and r <= OFFICER_RANK
end

local lastSent, lastSentAt = nil, 0
local function sendState(force)
	if not W.opt.guild.board or not guildName() then return end
	local id, si, total = E.Summary()
	local payload = table.concat({ W.player.level or 1, W.player.class or "", id or "", si or 0, total or 0 }, "|")
	local t = GetTime()
	if not force and (payload == lastSent or t - lastSentAt < 120) then return end
	if Cm.Send("GUILD", "B", W.player.level or 1, W.player.class or "", id or "", si or 0, total or 0) then
		lastSent, lastSentAt = payload, t
	end
end

Cm.On("B", function(sender, channel, level, class, guide, step, total)
	if channel ~= "GUILD" then return end
	local s = store()
	if not s then return end
	s.board[Cm.ShortName(sender)] = { level = tonumber(level) or 1, class = class, guide = guide ~= "" and guide or nil,
		step = tonumber(step) or 0, total = tonumber(total) or 0, seen = time() }
	Gd.Refresh()
end)

Cm.On("Q", function(_, channel)
	if channel == "GUILD" then
		-- spread replies so a big guild does not answer all at once
		W.After(math.random() * 8, function() sendState(true) end)
	end
end)

Cm.On("P", function(sender, channel, guide)
	if channel ~= "GUILD" then return end
	local name = Cm.ShortName(sender)
	if not Gd.IsOfficer(name) then return end
	local s = store()
	if not s then return end
	s.pick = { guide = guide ~= "" and guide or nil, by = name, at = time() }
	if s.pick.guide and W.opt.guild.banner then
		local meta = G.Meta(s.pick.guide)
		UI.Toast(L["Guild route"], (L["%s picked %s for the guild."]):format(name, meta and meta.title or s.pick.guide),
			"Interface\\Icons\\INV_Misc_Map_01", function() Gd.Toggle(true) end, 10)
	end
	Gd.Refresh()
end)

Cm.On("A", function(sender, channel, text)
	if channel ~= "GUILD" or not W.opt.guild.banner then return end
	local name = Cm.ShortName(sender)
	if not Gd.IsOfficer(name) or not text or text == "" then return end
	UI.Toast((L["Guild announcement from %s"]):format(name), text, "Interface\\Icons\\INV_Misc_Horn_02", nil, 14)
	W.Print(("|cff40ff40[%s]|r %s"):format(name, text))
end)

function Gd.Announce(text)
	if not guildName() then return W.Print(L["You are not in a guild."]) end
	if not Gd.IsOfficer() then return W.Print(L["Only guild officers can send announcements."]) end
	if not text or text == "" then return W.Print(L["Usage: /waypost announce <message>"]) end
	if Cm.Send("GUILD", "A", text) then
		W.Print(L["Announcement sent to guild members using Waypost."])
		UI.Toast((L["Guild announcement from %s"]):format(W.player.name), text, "Interface\\Icons\\INV_Misc_Horn_02", nil, 8)
	else
		W.Print(L["Could not send: guild sync is unavailable."])
	end
end

function Gd.PickRoute()
	if not guildName() then return W.Print(L["You are not in a guild."]) end
	if not Gd.IsOfficer() then return W.Print(L["Only guild officers can pick the guild route."]) end
	local id = E.Summary()
	if not id then return W.Print(L["Load the guide you want to pick first."]) end
	if Cm.Send("GUILD", "P", id) then
		local s = store()
		s.pick = { guide = id, by = W.player.name, at = time() }
		W.Print((L["Guild route set to %s."]):format(E.guide.title or id))
		Gd.Refresh()
	end
end

---------------------------------------------------------------------------
-- Board
---------------------------------------------------------------------------
local function classColor(class)
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
	if c then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
	return "|cffffffff"
end

local function ago(t)
	local d = time() - (t or 0)
	if d < 120 then return L["now"] end
	if d < 3600 then return ("%dm"):format(d / 60) end
	if d < 86400 then return ("%dh"):format(d / 3600) end
	return ("%dd"):format(d / 86400)
end

local function items()
	local out = {}
	local s = store()
	if not s then return out end
	local id, si, total = E.Summary()
	s.board[W.player.name or "?"] = { level = W.player.level or 1, class = W.player.class, guide = id, step = si or 0, total = total or 0, seen = time() }
	local cutoff = time() - 30 * 86400
	for name, m in pairs(s.board) do
		if (m.seen or 0) < cutoff then
			s.board[name] = nil
		else
			out[#out + 1] = { name = name, m = m }
		end
	end
	table.sort(out, function(a, b)
		if a.m.level ~= b.m.level then return a.m.level > b.m.level end
		return a.name < b.name
	end)
	return out
end

function Gd.Refresh()
	if not win or not win:IsShown() then return end
	local s = store()
	if not s then
		header:SetText(L["You are not in a guild."])
		pickBtn:Hide()
		view.SetItems({})
		return
	end
	local pick = s.pick and s.pick.guide and G.Meta(s.pick.guide)
	if pick then
		header:SetText((L["Guild route: |cffffd100%s|r (%d-%d), picked by %s"]):format(pick.title or pick.id, pick.minLevel or 1, pick.maxLevel or 60, s.pick.by or "?"))
		pickBtn:Show()
		pickBtn.guide = pick.id
		pickBtn:SetEnabled(not (E.guide and E.guide.id == pick.id))
	else
		header:SetText((L["%s leveling board. Officers can pick a guild route with /waypost guildroute."]):format(guildName()))
		pickBtn:Hide()
	end
	view.SetItems(items(), true)
end

function Gd.Toggle(show)
	if not win then
		win = UI.Window("WaypostGuild", L["Guild Leveling Board"], 560, 440)
		header = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		header:SetPoint("TOPLEFT", 20, -34)
		header:SetPoint("RIGHT", -120, 0)
		header:SetJustifyH("LEFT")
		header:SetWordWrap(false)
		pickBtn = UI.Button(win, L["Start"], 90, 20, function(self)
			if self.guide then E.Load(self.guide) W.StepFrame.Toggle(true) end
		end)
		pickBtn:SetPoint("TOPRIGHT", -22, -30)
		local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 18, -56)
		box:SetPoint("BOTTOMRIGHT", -18, 18)
		UI.Backdrop(box, "inset")
		view = UI.VirtualList(box, 20, function(row)
			row.level = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			row.level:SetPoint("LEFT", 6, 0)
			row.level:SetWidth(22)
			row.level:SetJustifyH("RIGHT")
			row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.name:SetPoint("LEFT", 36, 0)
			row.name:SetWidth(110)
			row.name:SetJustifyH("LEFT")
			row.name:SetWordWrap(false)
			row.guide = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.guide:SetPoint("LEFT", 150, 0)
			row.guide:SetWidth(170)
			row.guide:SetJustifyH("LEFT")
			row.guide:SetWordWrap(false)
			row.bar = CreateFrame("StatusBar", nil, row)
			row.bar:SetPoint("LEFT", 326, 0)
			row.bar:SetSize(96, 9)
			row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
			row.bar:SetStatusBarColor(0.95, 0.72, 0.1)
			row.bar:SetMinMaxValues(0, 1)
			row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
			row.bar.bg:SetAllPoints()
			row.bar.bg:SetColorTexture(0, 0, 0, 0.6)
			row.seen = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
			row.seen:SetPoint("RIGHT", -6, 0)
			row:EnableMouse(false)
		end, function(row, it)
			local m = it.m
			row.level:SetText(m.level)
			row.name:SetText(classColor(m.class) .. it.name .. "|r")
			local meta = m.guide and G.Meta(m.guide)
			row.guide:SetText(meta and meta.title or (m.guide and m.guide or "|cff9d9d9d" .. L["no guide"] .. "|r"))
			row.bar:SetShown(m.guide ~= nil and (m.total or 0) > 0)
			if (m.total or 0) > 0 then row.bar:SetValue((m.step or 0) / m.total) end
			row.seen:SetText(ago(m.seen))
		end)
		view:SetPoint("TOPLEFT", 6, -8)
		view:SetPoint("BOTTOMRIGHT", -6, 8)
		win:HookScript("OnShow", function()
			if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
			Cm.Send("GUILD", "Q")
			Gd.Refresh()
		end)
	end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then Gd.Refresh() end
end

W.On("WP_READY", function() W.After(12, function() sendState(true) end) end)
W.On("WP_GUIDE", function() W.After(3, function() sendState(false) end) end)
W.On("WP_LEVEL", function() W.After(3, function() sendState(true) end) end)
W.On("WP_STEP", function() sendState(false) end)
