-- Quests set aside for later.
--
-- "Later" on a step (or a group quest the route passed over while you were
-- solo) puts its quests here instead of dropping them for good. Waypost
-- offers them back when the reason has gone away: you joined a party, or
-- you are a couple of levels higher than when you set them aside.

local W = Waypost
local L = W.L
local UI, E, G = W.UI, W.Engine, W.Guides
local S = {}
W.SetAside = S

local LEVELS_BEFORE_OFFER = 2
local win, view, note

function S.Count()
	return #E.SetAsideList()
end

local function reasonText(it)
	if it.reason == "group" then return L["needs a group"] end
	return (L["set aside at level %d"]):format(it.level or 1)
end

function S.Refresh()
	if not win or not win:IsShown() then return end
	local list = E.SetAsideList()
	view.SetItems(list, true)
	if #list == 0 then
		note:SetText(L["Nothing set aside. Use Later on a step you cannot do yet and it will wait here."])
	else
		note:SetText(L["Go back makes that step the current one again. Forget leaves the quest out of your route for good."])
	end
end

function S.Toggle(show)
	if not win then
		win = UI.Window("WaypostSetAside", L["Quests Set Aside"], 520, 380)
		note = win:CreateFontString(nil, "ARTWORK", "WaypostFontSmall")
		note:SetPoint("TOPLEFT", 16, -38)
		note:SetPoint("TOPRIGHT", -16, -38)
		note:SetJustifyH("LEFT")
		note:SetHeight(26)
		local box = CreateFrame("Frame", nil, win)
		box:SetPoint("TOPLEFT", 14, -70)
		box:SetPoint("BOTTOMRIGHT", -14, 14)
		UI.Backdrop(box, "well")
		view = UI.VirtualList(box, 38, function(row)
			row.title = row:CreateFontString(nil, "ARTWORK", "WaypostFontGold")
			row.title:SetPoint("TOPLEFT", 8, -4)
			row.title:SetPoint("RIGHT", -190, 0)
			row.title:SetJustifyH("LEFT")
			row.title:SetWordWrap(false)
			row.sub = row:CreateFontString(nil, "ARTWORK", "WaypostFontMuted")
			row.sub:SetPoint("TOPLEFT", 8, -21)
			row.sub:SetPoint("RIGHT", -190, 0)
			row.sub:SetJustifyH("LEFT")
			row.sub:SetWordWrap(false)
			row.forget = UI.Button(row, L["Forget"], 80, 22, function()
				if row.item then E.Forget(row.item.quest) end
			end)
			row.forget:SetPoint("RIGHT", -4, 0)
			row.back = UI.Button(row, L["Go back"], 90, 22, function()
				if row.item and E.ReturnTo(row.item.quest) then
					W.StepFrame.Toggle(true)
					win:Hide()
				end
			end)
			row.back:SetPoint("RIGHT", row.forget, "LEFT", -6, 0)
			row:EnableMouse(false)
		end, function(row, it)
			local meta = G.Meta(it.guide)
			row.title:SetText(it.title)
			row.sub:SetText(("%s  -  %s, %s %d"):format(reasonText(it), meta and meta.title or it.guide, L["step"], it.step))
		end)
		view:SetPoint("TOPLEFT", 6, -8)
		view:SetPoint("BOTTOMRIGHT", -6, 8)
		win:HookScript("OnShow", S.Refresh)
	end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then S.Refresh() end
end

---------------------------------------------------------------------------
-- Offers
---------------------------------------------------------------------------
local function offer(title, text)
	UI.Toast(title, text, nil, function() S.Toggle(true) end, 12)
	W.Print(text .. " " .. L["Open the list with /waypost later."])
end

local wasInGroup = false
W.On("GROUP_ROSTER_UPDATE", function()
	local inGroup = (IsInGroup and IsInGroup()) and true or false
	if inGroup and not wasInGroup then
		local n = 0
		for _, it in ipairs(E.SetAsideList()) do
			if it.reason == "group" then n = n + 1 end
		end
		if n > 0 then
			offer(L["You are in a party"], n == 1 and L["A group quest you set aside can be done now."]
				or (L["%d group quests you set aside can be done now."]):format(n))
		end
	end
	wasInGroup = inGroup
end)

W.On("WP_LEVEL", function(level)
	local n = 0
	for _, it in ipairs(E.SetAsideList()) do
		if it.reason ~= "group" and level >= (it.level or 1) + LEVELS_BEFORE_OFFER and (it.offered or 0) < level then
			n = n + 1
			local e = W.char.setAside[it.quest]
			if e then e.offered = level + 1 end      -- ask again only after two more levels
		end
	end
	if n > 0 then
		offer((L["Level %d"]):format(level), n == 1 and L["A quest you set aside may be doable now."]
			or (L["%d quests you set aside may be doable now."]):format(n))
	end
end)

W.On("WP_LOGIN", function() wasInGroup = (IsInGroup and IsInGroup()) and true or false end)
W.On("WP_SET_ASIDE", S.Refresh)
W.On("QUEST_ACCEPTED", function() if win and win:IsShown() then W.After(0.3, S.Refresh) end end)
