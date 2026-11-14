-- Gear upgrades: points out the best quest reward and upgrades a vendor sells.
-- Uses Pawn's verdict when Pawn is installed; otherwise a plain rule: you can
-- wear it and its item level beats what is in that slot. Forever hides some
-- item data until it has been seen, so anything unknown is simply not marked.

local W = Waypost
local L = W.L
local U = {}
W.Upgrades = U

local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
	INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
	INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

local function info(link)
	local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if not fn or not link then return nil end
	local name, _, quality, ilvl, _, _, _, _, equipLoc, _, price = fn(link)
	if not name then return nil end
	return { name = name, quality = quality, ilvl = ilvl or 0, equipLoc = equipLoc, price = price or 0 }
end

local function usable(link)
	local fn = (C_Item and C_Item.IsUsableItem) or IsUsableItem
	if not fn then return true end
	local ok, can = pcall(fn, link)
	return ok and can and true or false
end

-- Returns the item-level gain over the weakest matching equipped slot, or nil.
function U.Gain(link)
	local it = info(link)
	if not it or not it.equipLoc or not SLOTS[it.equipLoc] then return nil end
	if W.opt.upgrades.pawn and PawnIsItemAnUpgrade and PawnGetItemData then
		local ok, data = pcall(PawnGetItemData, link)
		if ok and data then
			local ok2, up = pcall(PawnIsItemAnUpgrade, data)
			if ok2 then
				if up then return 1, it, true end
				return nil
			end
		end
	end
	if not usable(link) then return nil end
	local worst
	for _, slot in ipairs(SLOTS[it.equipLoc]) do
		local eq = GetInventoryItemLink and GetInventoryItemLink("player", slot)
		local lvl = 0
		if eq then
			local e = info(eq)
			if not e then return nil end     -- equipped item not cached yet: do not guess
			lvl = e.ilvl
		end
		if not worst or lvl < worst then worst = lvl end
	end
	local gain = it.ilvl - (worst or 0)
	if gain > 0 then return gain, it, false end
	return nil
end

local marks = {}
local function mark(button, show)
	if not button then return end
	local m = marks[button]
	if not m and show then
		m = button:CreateTexture(nil, "OVERLAY")
		m:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
		m:SetSize(22, 22)
		m:SetPoint("TOPLEFT", -2, 4)
		marks[button] = m
	end
	if m then m:SetShown(show and true or false) end
end

W.On("WP_REWARD_CHOICE", function(_, choices)
	if not W.opt.upgrades.enabled or not GetQuestItemLink then return end
	local best, bestGain, bestInfo, bestPrice, bestPriceIndex = nil, 0, nil, -1, nil
	for i = 1, choices do
		local link = GetQuestItemLink("choice", i)
		local gain, it = U.Gain(link)
		if gain and gain > bestGain then best, bestGain, bestInfo = i, gain, it end
		local d = info(link)
		if d and d.price > bestPrice then bestPrice, bestPriceIndex = d.price, i end
	end
	for i = 1, choices do
		local ok, btn = pcall(function()
			return QuestInfo_GetRewardButton and QuestInfo_GetRewardButton(QuestInfoFrame.rewardsFrame, i)
		end)
		if ok then mark(btn, i == best) end
	end
	if best then
		W.Print((L["Suggested reward: %s (an upgrade)."]):format(GetQuestItemLink("choice", best) or bestInfo.name))
	elseif bestPriceIndex then
		W.Print((L["No reward is an upgrade. %s sells for the most."]):format(GetQuestItemLink("choice", bestPriceIndex) or "?"))
	end
end)

W.On("MERCHANT_SHOW", function()
	if not W.opt.upgrades.enabled or not GetMerchantNumItems then return end
	local money = W.Readable(GetMoney and GetMoney()) or 0
	local found = {}
	for i = 1, GetMerchantNumItems() or 0 do
		local link = GetMerchantItemLink and GetMerchantItemLink(i)
		if link then
			local gain = U.Gain(link)
			local price = 0
			if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
				local d = C_MerchantFrame.GetItemInfo(i)
				price = d and d.price or 0
			elseif GetMerchantItemInfo then
				price = select(3, GetMerchantItemInfo(i)) or 0
			end
			if gain and price <= money then found[#found + 1] = link end
		end
	end
	if #found > 0 then
		W.Print((L["This vendor sells upgrades you can afford: %s"]):format(table.concat(found, ", ", 1, math.min(4, #found))))
	end
end)
