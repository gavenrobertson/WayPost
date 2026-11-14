-- Party sync, built in:
--   * see every member's guide and step
--   * "Sync to my guide": invite the party onto your guide and step
--   * share a quest a member is missing
-- Members without Waypost simply show as "no data".

local W = Waypost
local L = W.L
local UI, E, G, Q, Cm = W.UI, W.Engine, W.Guides, W.Quest, W.Comm
local Gr = {}
W.Group = Gr

local members = {}      -- [shortName] = { guide, step, total, title, level, need = {questIds}, seen }
local win, view, note

local function myNeeds()
	local out = {}
	if E.guide and E.index then
		for _, g in ipairs(E.Visible(E.guide.steps[E.index])) do
			if g.t == "accept" and g.quest and not Q.IsOn(g.quest) and not Q.IsDone(g.quest) and #out < 6 then
				out[#out + 1] = g.quest
			end
		end
	end
	return table.concat(out, ",")
end

local lastSent
local function sendState(force)
	if not W.opt.group.sync then return end
	local id, si, total, title = E.Summary()
	local payload = table.concat({ id or "", si or 0, total or 0, title or "", W.player.level or 1, myNeeds() }, "|")
	if not force and payload == lastSent then return end
	if Cm.Send("PARTY", "S", id or "", si or 0, total or 0, title or "", W.player.level or 1, myNeeds()) then
		lastSent = payload
	end
end
local sendSoon = W.Throttle(2, function() sendState(false) end)

Cm.On("S", function(sender, channel, guide, step, total, title, level, need)
	if channel ~= "PARTY" and channel ~= "RAID" then return end
	local name = Cm.ShortName(sender)
	local m = members[name] or {}
	members[name] = m
	m.guide, m.step, m.total, m.title = guide ~= "" and guide or nil, tonumber(step) or 0, tonumber(total) or 0, title
	m.level = tonumber(level)
	m.need = {}
	for q in (need or ""):gmatch("%d+") do m.need[#m.need + 1] = tonumber(q) end
	m.seen = time and time() or 0
	Gr.Refresh()
end)

Cm.On("R", function(_, channel)
	if channel == "PARTY" or channel == "RAID" then sendState(true) end
end)

-- "Sync to my guide"
Cm.On("G", function(sender, channel, guide, step)
	if channel ~= "PARTY" and channel ~= "RAID" then return end
	local meta = G.Meta(guide)
	local name = Cm.ShortName(sender)
	if not meta then
		W.Print((L["%s invited you to a guide you do not have (%s)."]):format(name, guide))
		return
	end
	step = tonumber(step) or 1
	StaticPopupDialogs["WAYPOST_SYNC"] = {
		text = (L["%s wants you to follow their guide:\n|cffffd100%s|r, step %d.\nSwitch to it?"]):format(name, meta.title or guide, step),
		button1 = YES or "Yes", button2 = NO or "No",
		OnAccept = function()
			if E.Load(guide) and E.guide and E.guide.steps[step] then E.JumpTo(step) end
			W.StepFrame.Toggle(true)
		end,
		timeout = 60, whileDead = true, hideOnEscape = true, preferredIndex = 3,
	}
	StaticPopup_Show("WAYPOST_SYNC")
end)

function Gr.SyncParty()
	local id, si = E.Summary()
	if not id then return W.Print(L["Load a guide first."]) end
	if not (IsInGroup and IsInGroup()) then return W.Print(L["You are not in a party."]) end
	if Cm.Send("PARTY", "G", id, si) then
		W.Print(L["Asked your party to join your guide and step."])
	else
		W.Print(L["Party sync is not available right now."])
	end
end

function Gr.ShareQuest(q)
	if W.InCombat() then return end
	if not Q.IsOn(q) then return W.Print(L["You are not on that quest."]) end
	if C_QuestLog and C_QuestLog.IsPushableQuest and not C_QuestLog.IsPushableQuest(q) then
		return W.Print(L["That quest cannot be shared."])
	end
	if C_QuestLog and C_QuestLog.SetSelectedQuest and QuestLogPushQuest then
		C_QuestLog.SetSelectedQuest(q)
		QuestLogPushQuest()
		W.Print((L["Shared %s with your party."]):format(Q.Title(q) or ("#" .. q)))
	end
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function roster()
	local out = {}
	local id, si, total, title = E.Summary()
	out[#out + 1] = { name = W.player.name or "?", me = true, level = W.player.level, guide = id, step = si, total = total, title = title }
	if IsInGroup and IsInGroup() then
		local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
		for i = 1, n do
			local unit = "party" .. i
			local name = W.Readable(UnitName(unit))
			if name then
				local m = members[name] or {}
				out[#out + 1] = { name = name, unit = unit, level = m.level or W.Readable(UnitLevel(unit)), guide = m.guide,
					step = m.step, total = m.total, title = m.title, need = m.need, known = m.seen ~= nil }
			end
		end
	end
	return out
end

function Gr.Refresh()
	if not win or not win:IsShown() then return end
	view.SetItems(roster(), true)
	if not Cm.available then
		note:SetText(Cm.reason == "trial" and L["Trial accounts cannot send addon messages, so your party cannot see your step. You can still see theirs."]
			or L["Party sync is unavailable on this client right now. Everything else works as usual."])
		note:SetTextColor(1, 0.5, 0.3)
	elseif not (IsInGroup and IsInGroup()) then
		note:SetText(L["Join a party to see where everyone is in the guide."])
		note:SetTextColor(0.7, 0.7, 0.7)
	else
		note:SetText(L["Members without Waypost show as \"no data\"."])
		note:SetTextColor(0.7, 0.7, 0.7)
	end
end

function Gr.Toggle(show)
	if not win then
		win = UI.Window("WaypostParty", L["Party Progress"], 480, 330)
		note = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		note:SetPoint("TOPLEFT", 20, -32)
		note:SetPoint("TOPRIGHT", -20, -32)
		note:SetJustifyH("LEFT")
		local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 18, -52)
		box:SetPoint("BOTTOMRIGHT", -18, 48)
		UI.Backdrop(box, "inset")
		view = UI.VirtualList(box, 38, function(row)
			row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			row.name:SetPoint("TOPLEFT", 8, -4)
			row.guide = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.guide:SetPoint("TOPLEFT", 8, -20)
			row.guide:SetPoint("RIGHT", -110, 0)
			row.guide:SetJustifyH("LEFT")
			row.guide:SetWordWrap(false)
			row.delta = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.delta:SetPoint("TOPRIGHT", -8, -5)
			row.share = UI.Button(row, L["Share quest"], 96, 18, function() if row.shareQuest then Gr.ShareQuest(row.shareQuest) end end)
			row.share:SetPoint("BOTTOMRIGHT", -4, 2)
			row:EnableMouse(false)
		end, function(row, m)
			row.name:SetText(m.name .. (m.level and ("  |cff9d9d9d" .. L["level"] .. " " .. m.level .. "|r") or ""))
			row.shareQuest = nil
			if m.guide then
				local meta = G.Meta(m.guide)
				row.guide:SetText(("%s  |cffffd100%d/%d|r  %s"):format(meta and meta.title or m.guide, m.step or 0, m.total or 0, m.title or ""))
				local id, si = E.Summary()
				if m.me then
					row.delta:SetText("|cff9d9d9d" .. L["you"] .. "|r")
				elseif id and id == m.guide then
					local d = (m.step or 0) - si
					row.delta:SetText(d == 0 and ("|cff40ff40" .. L["same step"] .. "|r")
						or d > 0 and ("|cffffd100" .. (L["%d ahead"]):format(d) .. "|r") or ("|cffff8040" .. (L["%d behind"]):format(-d) .. "|r"))
				else
					row.delta:SetText("|cff9d9d9d" .. L["other guide"] .. "|r")
				end
				for _, q in ipairs(m.need or {}) do
					if Q.IsOn(q) then row.shareQuest = q break end
				end
			else
				row.guide:SetText("|cff9d9d9d" .. (m.me and L["No guide loaded."] or L["no data"]) .. "|r")
				row.delta:SetText("")
			end
			row.share:SetShown(row.shareQuest ~= nil)
		end)
		view:SetPoint("TOPLEFT", 6, -8)
		view:SetPoint("BOTTOMRIGHT", -6, 8)
		local sync = UI.Button(win, L["Sync party to my guide"], 190, 22, Gr.SyncParty)
		sync:SetPoint("BOTTOMLEFT", 18, 18)
		UI.Tooltip(sync, L["Sync party to my guide"], L["Asks every member to switch to your guide and step. Each of them confirms."])
		local ask = UI.Button(win, L["Refresh"], 90, 22, function() Cm.Send("PARTY", "R") sendState(true) end)
		ask:SetPoint("BOTTOMRIGHT", -18, 18)
		win:HookScript("OnShow", function() Cm.Send("PARTY", "R") Gr.Refresh() end)
	end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then Gr.Refresh() end
end

W.On("WP_STEP", sendSoon)
W.On("WP_GUIDE", sendSoon)
W.On("GROUP_ROSTER_UPDATE", function()
	if not (IsInGroup and IsInGroup()) then
		for k in pairs(members) do members[k] = nil end
		lastSent = nil
	else
		lastSent = nil
		sendSoon()
	end
	Gr.Refresh()
end)

W.On("WP_STEP_DONE", function(_, step)
	if W.opt.group.chat and IsInGroup and IsInGroup() and not W.InCombat() and SendChatMessage then
		pcall(SendChatMessage, ("[Waypost] %s: %s"):format(L["Finished"], step.title or ""), "PARTY")
	end
end)
