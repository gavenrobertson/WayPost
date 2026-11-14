-- A "Waypost" button inside the game menu (Esc), in the menu's own list of
-- buttons, in its own small section after Options (or the Shop).
--
-- The modern menu (Forever's) builds its buttons from a pool in InitButtons
-- and then stacks every shown child by layoutIndex. Ours is our own button,
-- made from the menu's button template and parented to the menu, with a
-- layoutIndex between the button it follows and the next one, so the
-- menu's own layout places it and grows the menu to fit. Nothing of
-- Blizzard's is written or moved. A client with the older, fixed menu gets
-- the button just below the menu instead.
--
-- Click: open Waypost's settings. Right-click: open the guide list.

local W = Waypost
local L = W.L
local UI = W.UI

local M = {}
W.GameMenu = M
local SECTION = 20       -- the menu's own gap between sections

local button, managed

local function open(_, mouse)
	local menu = _G.GameMenuFrame
	if menu and menu:IsShown() then
		if HideUIPanel and not W.InCombat() then pcall(HideUIPanel, menu) else pcall(menu.Hide, menu) end
	end
	if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION) end
	if mouse == "RightButton" then
		W.StepFrame.Toggle(true)
		W.Picker.Toggle(true)
	else
		W.Options.Toggle(true)
	end
end

local function build(menu, template)
	if button then return button end
	local ok, b = pcall(CreateFrame, "Button", "WaypostGameMenuButton", UIParent, template)
	if not ok or not b then
		b = UI.Button(UIParent, "Waypost", 144, 21)
	end
	b:SetParent(menu)
	b:SetSize(144, 21)
	b:SetText("Waypost")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", open)
	UI.Tooltip(b, "Waypost", L["Click for settings. Right-click for the guide list."], "ANCHOR_RIGHT")
	b:Hide()
	button = b
	return b
end

-- The pooled button ours follows (the Shop, else Options) and the layout
-- index of the button after it.
local function anchorFor(menu)
	local pool = menu.buttonPool
	if not (pool and pool.EnumerateActive) then return nil end
	local shop, options, indexes = nil, nil, {}
	for b in pool:EnumerateActive() do
		local text = b.GetText and b:GetText()
		if text ~= nil and text == _G.BLIZZARD_STORE then shop = b end
		if text ~= nil and text == _G.GAMEMENU_OPTIONS then options = b end
		if type(b.layoutIndex) == "number" then indexes[#indexes + 1] = b.layoutIndex end
	end
	local after = shop or options
	if not (after and type(after.layoutIndex) == "number") then return nil end
	local nextIndex = after.layoutIndex + 1
	for _, i in ipairs(indexes) do
		if i > after.layoutIndex and i < nextIndex then nextIndex = i end
	end
	return after, after.layoutIndex, nextIndex
end

-- After the menu's InitButtons, before its layout runs: put ours in the list.
local function place(menu)
	if not W.opt or not W.opt.ui.gameMenu then
		if button then button:Hide() end
		return
	end
	local after, index, nextIndex = anchorFor(menu)
	if not after then
		if button then button:Hide() end
		return
	end
	local b = build(menu, type(menu.buttonTemplate) == "string" and menu.buttonTemplate or "MainMenuFrameButtonTemplate")
	if b:GetParent() ~= menu then b:SetParent(menu) end
	local w, h = after:GetWidth(), after:GetHeight()
	if w and w > 0 and h and h > 0 then b:SetSize(w, h) end
	b:ClearAllPoints()
	b.layoutIndex = index + (nextIndex - index) / 2
	b.topPadding = SECTION
	-- take the neighbour's font, so a reskinned menu still matches
	local mine, theirs = b.GetFontString and b:GetFontString(), after.GetFontString and after:GetFontString()
	if type(mine) == "table" and type(theirs) == "table" and theirs.GetFont then
		local path, size, flags = theirs:GetFont()
		if path then mine:SetFont(path, size, flags or "") end
	end
	b:Show()
end

-- The older menu: our button just under it.
local function refreshOld()
	local menu = _G.GameMenuFrame
	if not menu or managed then return end
	if W.opt.ui.gameMenu and menu:IsShown() then
		local b = build(menu, "UIPanelButtonTemplate")
		local ref = _G.GameMenuButtonContinue
		local w, h = ref and ref:GetWidth() or 0, ref and ref:GetHeight() or 0
		b:SetSize(w > 0 and w or 144, h > 0 and h or 21)
		b:ClearAllPoints()
		b:SetPoint("TOP", menu, "BOTTOM", 0, -4)
		b:Show()
	elseif button then
		button:Hide()
	end
end

function M.Button() return button end
M.Place = place
function M.Managed() return managed end

W.On("WP_LOGIN", function()
	local menu = _G.GameMenuFrame
	if not menu then return end
	if type(rawget(menu, "InitButtons")) == "function" and hooksecurefunc then
		managed = true
		hooksecurefunc(menu, "InitButtons", place)
	else
		menu:HookScript("OnShow", refreshOld)
		menu:HookScript("OnHide", function() if button then button:Hide() end end)
	end
end)

W.On("WP_SETTINGS", function(path)
	if path ~= "*" and path ~= "ui.gameMenu" then return end
	if not managed then return refreshOld() end
	-- turned off with the menu open: ours goes now; the menu closes the gap when it next opens
	if button and not W.opt.ui.gameMenu then button:Hide() end
end)
