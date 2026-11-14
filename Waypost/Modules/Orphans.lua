-- Orphaned quests: quests in your log that your route (this guide and the
-- ones it leads into) will never finish, each with an Abandon button.

local W = Waypost
local L = W.L
local UI, E, G, Q = W.UI, W.Engine, W.Guides, W.Quest
local O = {}
W.Orphans = O

local win, view, note

-- Every quest ID in the active guide and the guides after it.
local function routeQuests()
	local set = {}
	local id, guard = E.guide and E.guide.id, 0
	while id and guard < 40 do
		guard = guard + 1
		local steps = G.Peek(id)
		if steps then
			for _, s in ipairs(steps) do
				for _, g in ipairs(s.goals) do
					if g.quest then set[g.quest] = true end
				end
			end
		end
		local meta = G.Meta(id)
		id = meta and meta.next
	end
	return set
end

function O.Find()
	local out = {}
	if not E.guide then return out end
	local set = routeQuests()
	for _, q in ipairs(Q.Log()) do
		if not set[q.id] then out[#out + 1] = q end
	end
	table.sort(out, function(a, b) return (a.level or 0) < (b.level or 0) end)
	return out
end

local function abandon(q)
	if W.InCombat() then return end
	if not (C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest) then return end
	C_QuestLog.SetSelectedQuest(q.id)
	C_QuestLog.SetAbandonQuest()
	-- The game's own confirmation box, so nothing is dropped by a stray click.
	if StaticPopupDialogs and StaticPopupDialogs["ABANDON_QUEST"] then
		StaticPopup_Show("ABANDON_QUEST", q.title or Q.Title(q.id) or "")
	else
		StaticPopupDialogs["WAYPOST_ABANDON"] = {
			text = (L["Abandon \"%s\"?"]):format(q.title or ""), button1 = YES or "Yes", button2 = NO or "No",
			OnAccept = function() C_QuestLog.AbandonQuest() end,
			timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
		}
		StaticPopup_Show("WAYPOST_ABANDON")
	end
end

function O.Refresh()
	if not win or not win:IsShown() then return end
	local list = O.Find()
	view.SetItems(list, true)
	if not E.guide then
		note:SetText(L["Load a guide first."])
	elseif #list == 0 then
		note:SetText(L["Every quest in your log is part of your route."])
	else
		note:SetText((L["%d quest(s) in your log are not part of your route. Class and profession quests can be worth keeping."]):format(#list))
	end
end

function O.Toggle(show)
	if not win then
		win = UI.Window("WaypostOrphans", L["Quests Outside Your Route"], 460, 400)
		note = win:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
		note:SetPoint("TOPLEFT", 16, -38)
		note:SetPoint("TOPRIGHT", -16, -38)
		note:SetJustifyH("LEFT")
		note:SetHeight(26)
		local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 14, -70)
		box:SetPoint("BOTTOMRIGHT", -14, 14)
		UI.Backdrop(box, "inset")
		view = UI.VirtualList(box, 24, function(row)
			row.title = row:CreateFontString(nil, "ARTWORK", "WaypostFontText")
			row.title:SetPoint("LEFT", 8, 0)
			row.title:SetPoint("RIGHT", -100, 0)
			row.title:SetJustifyH("LEFT")
			row.title:SetWordWrap(false)
			row.btn = UI.Button(row, L["Abandon"], 84, 20, function() if row.item then abandon(row.item) end end)
			row.btn:SetPoint("RIGHT", -4, 0)
			row:EnableMouse(false)
		end, function(row, q)
			row.title:SetText(("|cffffd100[%d]|r %s"):format(q.level or 0, q.title or ("#" .. q.id)))
		end)
		view:SetPoint("TOPLEFT", 6, -8)
		view:SetPoint("BOTTOMRIGHT", -6, 8)
		win:HookScript("OnShow", O.Refresh)
	end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then O.Refresh() end
end

W.On("QUEST_REMOVED", function() W.After(0.3, O.Refresh) end)
