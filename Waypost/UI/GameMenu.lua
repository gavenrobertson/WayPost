-- A "Waypost" button on the game menu (Esc), so the guide is one click away
-- even when its window is hidden.
--
-- The button is our own frame, shown and hidden with the menu and anchored
-- under it. Nothing of the menu's is changed or moved, so the default UI is
-- not tainted. It opens the guide window and the guide list (which has the
-- settings button in its corner).

local W = Waypost
local L = W.L
local UI = W.UI

local button

local function open()
	local menu = _G.GameMenuFrame
	if menu and menu:IsShown() then
		if HideUIPanel and not W.InCombat() then pcall(HideUIPanel, menu) else pcall(menu.Hide, menu) end
	end
	W.StepFrame.Toggle(true)
	W.Picker.Toggle(true)
end

local function place()
	local menu = _G.GameMenuFrame
	if not (button and menu) then return end
	local show = W.opt.ui.gameMenu and menu:IsShown()
	button:SetShown(show and true or false)
	if show then
		button:ClearAllPoints()
		button:SetPoint("TOP", menu, "BOTTOM", 0, -6)
		button:SetWidth(math.max(160, (menu:GetWidth() or 200) - 40))
		button:SetFrameStrata(menu:GetFrameStrata() or "DIALOG")
	end
end

W.On("WP_LOGIN", function()
	local menu = _G.GameMenuFrame
	if not menu then return end
	button = UI.Button(UIParent, "Waypost", 180, 30, open)
	button:Hide()
	local logo = button:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(UI.MEDIA .. "Logo")
	logo:SetSize(18, 18)
	logo:SetPoint("LEFT", 8, 0)
	UI.Tooltip(button, "Waypost", L["Open the guide window and the list of guides."], "ANCHOR_RIGHT")
	menu:HookScript("OnShow", place)
	menu:HookScript("OnHide", place)
end)

W.On("WP_SETTINGS", function(path)
	if path == "*" or path == "ui.gameMenu" then place() end
end)
