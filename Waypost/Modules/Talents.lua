-- Talent guide: a leveling plan per class, shown when you level up.
-- Plans come from Data/Talents.lua (see the About screen for credits).

local W = Waypost
local L = W.L
local UI = W.UI
local T = {}
W.Talents = T

local plans = {}
function W.RegisterTalents(t) plans = t end

local function plan() return plans[W.player.class or ""] end

-- Keep only this character's class once we know it.
W.On("WP_LOGIN", function()
	local class = W.player.class
	if class and plans[class] then plans = { [class] = plans[class] } end
end)

function T.Build()
	local p = plan()
	if not p then return nil end
	local key = W.char.talentBuild
	for _, b in ipairs(p.builds) do if b.key == key then return b end end
	-- Default: the first build of the spec the plan lists first for leveling.
	return p.builds[1]
end

function T.PicksAt(level)
	local b = T.Build()
	return b and b.levels[level] or nil
end

local function describe(picks)
	local parts = {}
	for _, p in ipairs(picks) do
		parts[#parts + 1] = ("%s |cff9d9d9d(%s, %s %d)|r"):format(p.talent, p.tree, L["rank"], p.rank or 1)
	end
	return table.concat(parts, ", ")
end

W.On("WP_LEVEL", function(level)
	if not W.opt.talents.enabled then return end
	local picks = T.PicksAt(level)
	if not picks then return end
	local text = describe(picks)
	W.Print((L["Level %d talent: %s"]):format(level, text))
	if picks[1].note then W.Print("|cffaaaaaa" .. picks[1].note .. "|r") end
	UI.Toast((L["Level %d talent point"]):format(level), text, "Interface\\Icons\\Ability_Marksmanship", function() T.Toggle(true) end, 10)
end)

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local win, view, pickBuild, summary

local function items()
	local b = T.Build()
	local out = {}
	if not b then return out end
	local levels = {}
	for lv in pairs(b.levels) do levels[#levels + 1] = lv end
	table.sort(levels)
	for _, lv in ipairs(levels) do
		for _, p in ipairs(b.levels[lv]) do
			out[#out + 1] = { level = lv, talent = p.talent, tree = p.tree, rank = p.rank, note = p.note }
		end
	end
	return out
end

local function refresh()
	local p = plan()
	if not p then
		summary:SetText(L["No talent plan for this class yet."])
		view.SetItems({})
		return
	end
	summary:SetText(p.summary or "")
	pickBuild.Refresh()
	local list = items()
	view.SetItems(list)
	for i, it in ipairs(list) do
		if it.level >= (W.player.level or 1) then view.ScrollTo(i) break end
	end
end

function T.Toggle(show)
	if not win then
		win = UI.Window("WaypostTalents", L["Talent Guide"], 460, 500)
		summary = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		summary:SetPoint("TOPLEFT", 20, -34)
		summary:SetPoint("TOPRIGHT", -20, -34)
		summary:SetJustifyH("LEFT")
		summary:SetJustifyV("TOP")
		summary:SetHeight(40)
		pickBuild = UI.Dropdown(win, L["Build"], 240, function()
			local out = {}
			local p = plan()
			if p then
				for _, b in ipairs(p.builds) do
					out[#out + 1] = { b.key, (b.spec or b.key) .. (b.split and b.split ~= "" and ("  " .. b.split) or "") }
				end
			end
			return out
		end, function() local b = T.Build() return b and b.key end, function(v)
			W.char.talentBuild = v
			refresh()
		end)
		pickBuild:SetPoint("TOPLEFT", 20, -78)
		local box = CreateFrame("Frame", nil, win, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 18, -124)
		box:SetPoint("BOTTOMRIGHT", -18, 34)
		UI.Backdrop(box, "inset")
		view = UI.VirtualList(box, 20, function(row)
			row.level = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			row.level:SetPoint("LEFT", 8, 0)
			row.level:SetWidth(26)
			row.level:SetJustifyH("RIGHT")
			row.talent = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.talent:SetPoint("LEFT", 44, 0)
			row.talent:SetWidth(200)
			row.talent:SetJustifyH("LEFT")
			row.talent:SetWordWrap(false)
			row.tree = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
			row.tree:SetPoint("RIGHT", -8, 0)
			row.now = row:CreateTexture(nil, "BACKGROUND")
			row.now:SetAllPoints()
			row.now:SetColorTexture(1, 0.82, 0, 0.13)
			row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			row:SetScript("OnEnter", function(self)
				local it = self.item
				if not it then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(it.talent, 1, 0.82, 0)
				GameTooltip:AddLine(("%s, %s %d"):format(it.tree, L["rank"], it.rank or 1), 1, 1, 1)
				if it.note then GameTooltip:AddLine(it.note, 0.9, 0.9, 0.8, true) end
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end, function(row, it)
			local lv = W.player.level or 1
			row.level:SetText(it.level)
			row.talent:SetText(it.talent .. ((it.rank or 1) > 1 and (" |cff9d9d9d" .. it.rank .. "|r") or ""))
			row.tree:SetText(it.tree)
			row.now:SetShown(it.level == lv)
			row.talent:SetAlpha(it.level < lv and 0.5 or 1)
			row.level:SetAlpha(it.level < lv and 0.5 or 1)
		end)
		view:SetPoint("TOPLEFT", 6, -8)
		view:SetPoint("BOTTOMRIGHT", -6, 8)
		local credit = win:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		credit:SetPoint("BOTTOMLEFT", 20, 16)
		credit:SetText(L["Plans: ForeverDB and Polestar. See About for credits."])
		win:HookScript("OnShow", refresh)
	end
	if show == nil then show = not win:IsShown() end
	win:SetShown(show)
	if show then refresh() end
end
