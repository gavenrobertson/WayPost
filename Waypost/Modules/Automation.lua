-- Quest automation, for guide quests only.
--   * accepts and turns in quests that are part of the active guide
--   * stops at reward choices (the Upgrades module points at the best one)
--   * hold Shift while opening the NPC to do everything by hand
--   * picks the flight master / trainer / vendor dialogue option the step asks for
--   * takes the guide's flight, and remembers which flight points are learned

local W = Waypost
local L = W.L
local E = W.Engine
local Au = {}
W.Automation = Au

local function bypass()
	return IsShiftKeyDown and IsShiftKeyDown()
end

local function wanted(q)
	if not q or q == 0 or not E.guide then return false end
	if W.char.skippedQuests[q] then return false end
	return E.QuestSet()[q] and true or false
end

---------------------------------------------------------------------------
-- NPC dialogue
---------------------------------------------------------------------------
local SERVICE_ICON = { fly = 132057, getfp = 132057, train = 132058, vendor = 132060, buy = 132060, sethome = 132052 }

local function stepServiceIcon()
	if not (E.guide and E.index) or E.view then return nil end
	local vis = E.Visible(E.guide.steps[E.index])
	for i = 1, #vis do
		local g = vis[i]
		if SERVICE_ICON[g.t] and not E.GoalState(g, E.index) then return SERVICE_ICON[g.t] end
	end
	return nil
end

W.On("GOSSIP_SHOW", function()
	if bypass() or not E.guide then return end
	local GI = C_GossipInfo
	if not GI then return end
	local o = W.opt.auto
	if o.turnin and GI.GetActiveQuests then
		for _, q in ipairs(GI.GetActiveQuests() or {}) do
			if q.questID and q.isComplete and wanted(q.questID) then
				GI.SelectActiveQuest(q.questID)
				return
			end
		end
	end
	if o.accept and GI.GetAvailableQuests then
		for _, q in ipairs(GI.GetAvailableQuests() or {}) do
			if q.questID and wanted(q.questID) then
				GI.SelectAvailableQuest(q.questID)
				return
			end
		end
	end
	if o.gossip and GI.GetOptions then
		local icon = stepServiceIcon()
		if icon then
			for _, opt in ipairs(GI.GetOptions() or {}) do
				if opt.icon == icon and opt.gossipOptionID then
					GI.SelectOption(opt.gossipOptionID)
					return
				end
			end
		end
	end
end)

W.On("QUEST_GREETING", function()
	if bypass() or not E.guide then return end
	local o = W.opt.auto
	if o.turnin and GetNumActiveQuests and GetActiveQuestID then
		for i = 1, GetNumActiveQuests() or 0 do
			local q = GetActiveQuestID(i)
			local _, complete = GetActiveTitle(i)
			if complete and wanted(q) then
				SelectActiveQuest(i)
				return
			end
		end
	end
	if o.accept and GetNumAvailableQuests and GetAvailableQuestInfo then
		for i = 1, GetNumAvailableQuests() or 0 do
			local q = select(5, GetAvailableQuestInfo(i))
			if wanted(q) then
				SelectAvailableQuest(i)
				return
			end
		end
	end
end)

W.On("QUEST_DETAIL", function()
	if bypass() or not W.opt.auto.accept then return end
	local q = GetQuestID and GetQuestID()
	if not wanted(q) then return end
	if QuestGetAutoAccept and QuestGetAutoAccept() then
		if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
	else
		AcceptQuest()
	end
end)

W.On("QUEST_ACCEPT_CONFIRM", function()
	-- Escort quests started by a party member: only confirm guide quests.
	if bypass() or not W.opt.auto.accept then return end
	local q = GetQuestID and GetQuestID()
	if wanted(q) and ConfirmAcceptQuest then ConfirmAcceptQuest() end
end)

W.On("QUEST_PROGRESS", function()
	if bypass() or not W.opt.auto.turnin then return end
	local q = GetQuestID and GetQuestID()
	if wanted(q) and IsQuestCompletable and IsQuestCompletable() then CompleteQuest() end
end)

W.On("QUEST_COMPLETE", function()
	local q = GetQuestID and GetQuestID()
	local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
	if choices > 1 then
		W.Fire("WP_REWARD_CHOICE", q, choices)
	end
	if bypass() or not W.opt.auto.turnin or not wanted(q) then return end
	if choices <= 1 then
		GetQuestReward(math.max(1, choices))
	end
end)

---------------------------------------------------------------------------
-- Flight points
---------------------------------------------------------------------------
local function shortNode(name)
	if type(name) ~= "string" then return nil end
	return (name:match("^(.-),%s") or name)
end

local function stepGoal(t)
	if not (E.guide and E.index) or E.view then return nil end
	local vis = E.Visible(E.guide.steps[E.index])
	for i = 1, #vis do
		local g = vis[i]
		if g.t == t and not E.GoalState(g, E.index) then return g end
	end
	return nil
end

local function nodeMatches(node, location)
	if not node or not location then return false end
	node, location = node:lower(), location:lower()
	return node == location or node:find(location, 1, true) == 1 or location:find(node, 1, true) == 1
end

W.On("TAXIMAP_OPENED", function()
	if not (NumTaxiNodes and TaxiNodeName and TaxiNodeGetType) then return end
	local fly = stepGoal("fly")
	local getfp = stepGoal("getfp")
	local slot
	for i = 1, NumTaxiNodes() or 0 do
		local kind = TaxiNodeGetType(i)
		local name = shortNode(TaxiNodeName(i))
		if name and (kind == "CURRENT" or kind == "REACHABLE") then
			W.char.fps[name] = true
			if kind == "CURRENT" and getfp and getfp.location then
				-- Standing at the flight master with the map open: this point is learned.
				W.char.fps[getfp.location] = true
			end
			if kind == "REACHABLE" and fly and nodeMatches(name, fly.location) then slot = i end
		end
	end
	E.EvaluateSoon()
	if slot and W.opt.auto.flight and not bypass() and TakeTaxiNode then
		W.Print(L["Taking the flight to %s. Hold Shift at the flight master to choose yourself."], fly.location)
		TakeTaxiNode(slot)
	end
end)

W.On("UI_INFO_MESSAGE", function(_, msg)
	if msg and ERR_NEWTAXIPATH and msg == ERR_NEWTAXIPATH then
		local g = stepGoal("getfp")
		if g and g.location then W.char.fps[g.location] = true end
		E.EvaluateSoon()
	end
end)

-- A flight counts as flown when the taxi lands.
local onTaxi = false
W.On("PLAYER_CONTROL_LOST", function()
	W.After(1.5, function()
		if UnitOnTaxi and W.Readable(UnitOnTaxi("player")) then onTaxi = true end
	end)
end)
W.On("PLAYER_CONTROL_GAINED", function()
	if onTaxi then
		onTaxi = false
		E.LatchType("fly")
	end
end)
