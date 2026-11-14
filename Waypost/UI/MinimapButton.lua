-- Minimap button and the addon compartment entry.

local W = Waypost
local L = W.L
local UI = W.UI

local button

local function menu(owner)
	local E = W.Engine
	UI.ShowMenu(owner, {
		{ text = "Waypost", title = true },
		{ text = L["Show guide window"], checked = not W.opt.ui.hidden, func = function() W.StepFrame.Toggle() end },
		{ text = L["Guides"], func = function() W.Picker.Toggle(true) end },
		{ text = L["Settings"], func = function() W.Options.Toggle(true) end },
		{ text = L["Leveling speed"], func = function() W.XP.ToggleWindow(true) end },
		{ text = L["Talents"], func = function() W.Talents.Toggle(true) end },
		{ text = L["Party progress"], func = function() W.Group.Toggle(true) end },
		{ text = L["Guild leveling board"], func = function() W.Guild.Toggle(true) end },
		{ text = L["Quests the guide won't finish"], func = function() W.Orphans.Toggle(true) end },
		{ text = L["Undo last skip"], disabled = #W.char.undo == 0, func = function() E.UndoSkip() end },
		{ text = L["Guide editor"], func = function() W.Editor.Open() end },
		{ text = L["Report a problem"], func = function() W.Report.Open() end },
	}, 210)
end

local function click(self, mouse)
	if mouse == "RightButton" then
		menu(self)
	elseif IsShiftKeyDown() then
		W.Picker.Toggle()
	else
		W.StepFrame.Toggle()
	end
end

local function position()
	local angle = math.rad(W.opt.minimap.angle or 205)
	local r = (Minimap:GetWidth() / 2) + 6
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function build()
	button = CreateFrame("Button", "WaypostMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(24, 24)
	bg:SetPoint("CENTER")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(UI.MEDIA .. "Logo")
	icon:SetSize(21, 21)
	icon:SetPoint("CENTER")
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	button:SetScript("OnClick", click)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local s = Minimap:GetEffectiveScale()
			W.opt.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
			position()
		end)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Waypost", 1, 0.82, 0)
		local id, si, n, title = W.Engine.Summary()
		if id then
			GameTooltip:AddLine(W.Engine.guide.title or id, 1, 1, 1)
			GameTooltip:AddLine((L["Step %d of %d"]):format(si, n) .. ": " .. title, 0.8, 0.8, 0.8, true)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Click: show or hide the guide"], 0.4, 0.8, 1)
		GameTooltip:AddLine(L["Shift-click: guide list"], 0.4, 0.8, 1)
		GameTooltip:AddLine(L["Right-click: menu"], 0.4, 0.8, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function apply()
	if not button then return end
	button:SetShown(not W.opt.minimap.hide)
	position()
end

W.On("WP_LOGIN", function()
	if not Minimap then return end
	build()
	apply()
end)
W.On("WP_SETTINGS", function(path)
	if path == "*" or path == "minimap.hide" then apply() end
end)

-- Addon compartment (the dropdown by the minimap on the modern client).
function Waypost_OnAddonCompartmentClick(_, mouse)
	if mouse == "RightButton" then W.Options.Toggle(true) else W.StepFrame.Toggle() end
end
function Waypost_OnAddonCompartmentEnter(_, frame)
	GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
	GameTooltip:SetText("Waypost", 1, 0.82, 0)
	GameTooltip:AddLine(L["Click: show or hide the guide"], 1, 1, 1)
	GameTooltip:AddLine(L["Right-click: settings"], 1, 1, 1)
	GameTooltip:Show()
end
function Waypost_OnAddonCompartmentLeave() GameTooltip:Hide() end
