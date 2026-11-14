-- Action buttons for the current step: use the quest item, target the NPC.
--
-- Both are secure buttons, so they are only ever configured out of combat;
-- a step change during a fight is applied when the fight ends. Each has a
-- key binding (Key Bindings > Waypost).

local W = Waypost
local L = W.L
local E = W.Engine
local B = {}
W.Buttons = B

BINDING_HEADER_WAYPOST = "Waypost"
BINDING_NAME_WAYPOST_TOGGLE = "Show / hide the guide window"
BINDING_NAME_WAYPOST_NEXT = "Next step"
BINDING_NAME_WAYPOST_PREV = "Previous step"
BINDING_NAME_WAYPOST_SKIP = "Skip step"
BINDING_NAME_WAYPOST_GUIDES = "Open the guide list"
_G["BINDING_NAME_CLICK WaypostItemButton:LeftButton"] = "Use the step's quest item"
_G["BINDING_NAME_CLICK WaypostTargetButton:LeftButton"] = "Target the step's NPC or enemy"

local bar, item, targetBtn

local function getCount(id)
	return E.ItemCount(id)
end

local function itemIcon(id)
	local fn = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
	return fn and fn(id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- The item this step wants used: a "use" goal, or an item that starts a quest.
local function stepItem()
	if not E.guide or not E.index then return nil end
	local si = E.view or E.index
	local vis = E.Visible(E.guide.steps[si])
	for i = 1, #vis do
		local g = vis[i]
		if not E.GoalState(g, si) then
			if g.t == "use" and g.item then return g.item, g.itemName end
			if g.t == "accept" and g.startItem then return g.startItem, g.startItemName end
			if g.startItem and g.quest and getCount(g.startItem) > 0 then return g.startItem, g.startItemName end
		end
	end
	return nil
end

local function cleanName(n)
	if type(n) ~= "string" or n == "" or #n > 60 or n:find("[%c|;/%[%]]") then return nil end
	return n
end

-- Names to target: enemies to kill first, then the NPC to talk to.
local function stepTargets()
	local out, seen = {}, {}
	if not E.guide or not E.index then return out end
	local si = E.view or E.index
	local vis = E.Visible(E.guide.steps[si])
	local function add(n)
		n = cleanName(n)
		if n and not seen[n] and #out < 5 then seen[n] = true; out[#out + 1] = n end
	end
	for pass = 1, 2 do
		for i = 1, #vis do
			local g = vis[i]
			if not E.GoalState(g, si) then
				if pass == 1 and g.t == "kill" then add(g.target or g.npc) end
				if pass == 2 and (g.t == "accept" or g.t == "turnin" or g.t == "talk" or g.t == "buy" or g.t == "getfp" or g.t == "sethome") then add(g.npc) end
			end
		end
	end
	return out
end

local function makeButton(name, tipTitle, tipBody)
	local b = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
	b:SetSize(40, 40)
	b:RegisterForClicks("AnyUp", "AnyDown")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.border = b:CreateTexture(nil, "OVERLAY")
	b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	b.border:SetSize(68, 68)
	b.border:SetPoint("CENTER", 0, -1)
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.count:SetPoint("BOTTOMRIGHT", -2, 2)
	b.key = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	b.key:SetPoint("TOPRIGHT", -2, -2)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if self.itemID and GameTooltip.SetItemByID then
			GameTooltip:SetItemByID(self.itemID)
		else
			GameTooltip:SetText(tipTitle, 1, 0.82, 0)
			if self.tipLines then
				for _, l in ipairs(self.tipLines) do GameTooltip:AddLine(l, 1, 1, 1) end
			end
		end
		GameTooltip:AddLine(tipBody, 0.4, 0.8, 1, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:Hide()
	return b
end

local function build()
	bar = CreateFrame("Frame", "WaypostButtonBar", UIParent)
	bar:SetSize(88, 44)
	bar:SetMovable(true)
	bar:SetClampedToScreen(true)
	bar:EnableMouse(false)

	item = makeButton("WaypostItemButton", L["Quest item"], L["Click to use. Shift-drag to move. Bind a key in Key Bindings > Waypost."])
	targetBtn = makeButton("WaypostTargetButton", L["Target"], L["Click to target. Shift-drag to move. Bind a key in Key Bindings > Waypost."])
	targetBtn.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
	item.cooldown = CreateFrame("Cooldown", nil, item, "CooldownFrameTemplate")
	item.cooldown:SetAllPoints()

	for _, b in ipairs({ item, targetBtn }) do
		b:RegisterForDrag("LeftButton")
		b:SetScript("OnDragStart", function()
			if IsShiftKeyDown() and not W.InCombat() then bar:StartMoving() end
		end)
		b:SetScript("OnDragStop", function()
			bar:StopMovingOrSizing()
			local x, y = bar:GetCenter()
			if x then W.opt.buttons.pos = { x = x, y = y } end
		end)
	end
end

local function place()
	bar:ClearAllPoints()
	local pos = W.opt.buttons.pos
	if type(pos) == "table" and pos.x then
		bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	else
		bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 150, 235)
	end
end

local function bindingText(name)
	local key = GetBindingKey and GetBindingKey("CLICK " .. name .. ":LeftButton")
	if not key then return "" end
	return (GetBindingText and GetBindingText(key, 1)) or key
end

local function apply()
	if not bar then return end
	local o = W.opt.buttons
	local hidden = W.opt.ui.hidden

	local id = stepItem()
	if id and o.item and not hidden and getCount(id) > 0 then
		item.itemID = id
		item:SetAttribute("type", "item")
		item:SetAttribute("item", "item:" .. id)
		item.icon:SetTexture(itemIcon(id))
		local n = getCount(id)
		item.count:SetText(n > 1 and n or "")
		item.key:SetText(bindingText("WaypostItemButton"))
		item:Show()
	else
		item.itemID = nil
		item:SetAttribute("type", nil)
		item:SetAttribute("item", nil)
		item:Hide()
	end

	local names = stepTargets()
	if #names > 0 and o.target and not hidden then
		local lines = { "/cleartarget [nocombat]", "/targetexact " .. names[1] }
		for i = 2, #names do lines[#lines + 1] = "/targetexact [noexists] " .. names[i] end
		if o.mark then lines[#lines + 1] = "/tm [exists,nodead] 8" end
		targetBtn:SetAttribute("type", "macro")
		targetBtn:SetAttribute("macrotext", table.concat(lines, "\n"))
		targetBtn.tipLines = names
		targetBtn.key:SetText(bindingText("WaypostTargetButton"))
		targetBtn:Show()
	else
		targetBtn:SetAttribute("type", nil)
		targetBtn:SetAttribute("macrotext", nil)
		targetBtn:Hide()
	end

	item:ClearAllPoints()
	targetBtn:ClearAllPoints()
	item:SetPoint("LEFT", bar, "LEFT", 2, 0)
	if item:IsShown() then
		targetBtn:SetPoint("LEFT", item, "RIGHT", 6, 0)
	else
		targetBtn:SetPoint("LEFT", bar, "LEFT", 2, 0)
	end
	place()
end

local function refresh()
	W.OutOfCombat("buttons", apply)
end
B.Refresh = refresh
local refreshSoon = W.Throttle(0.25, refresh)

local function cooldown()
	if not (item and item:IsShown() and item.itemID) then return end
	local fn = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
	if not fn then return end
	local ok, start, duration = pcall(fn, item.itemID)
	start, duration = W.Readable(start), W.Readable(duration)
	if ok and type(start) == "number" and type(duration) == "number" and duration > 0 then
		item.cooldown:SetCooldown(start, duration)
	end
end

W.On("WP_LOGIN", function()
	build()
	refresh()
end)
for _, ev in ipairs({ "WP_STEP", "WP_PROGRESS", "WP_GUIDE", "WP_VISIBILITY", "UPDATE_BINDINGS", "BAG_UPDATE_DELAYED", "WP_COMBAT_ENDED" }) do
	W.On(ev, refreshSoon)
end
W.On("BAG_UPDATE_COOLDOWN", cooldown)
W.On("WP_SETTINGS", function(path)
	if path == "*" or (type(path) == "string" and path:find("^buttons")) then refreshSoon() end
end)
