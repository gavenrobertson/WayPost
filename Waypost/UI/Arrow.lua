-- The navigation arrow: a 3D gold arrow that lies on the ground plane and
-- turns toward the next objective, with distance and time-to-arrive under it.
--
-- Media/Arrow3D.tga is a sheet of 108 pre-rendered views (tools/make_arrow3d.py),
-- one every 3.33 degrees. Two textures show the two views either side of the
-- exact heading and cross-fade between them, so the arrow glides with the
-- character's turn instead of ticking from view to view.
-- The update only runs while the arrow is shown, and it is hidden in combat
-- unless "keep live in combat" is on.

local W = Waypost
local L = W.L
local UI, E, C = W.UI, W.Engine, W.Coords

local A = {}
W.Arrow = A

local COLS, ROWS, CW, CH, SHEET = 9, 12, 112, 84, 1024
local FRAMES = COLS * ROWS
local PI2 = math.pi * 2
local floor, sin, min = math.floor, math.sin, math.min

local frame, tex, tex2, glow, title, distText, etaText
local target, targetStep
local shownAngle, lastCell, lastCell2 = 0, -1, -1
local arrived, arrivedFor = false, nil
local textAcc, bob = 1, 0
local tomtomUid

local ARRIVE = { kill = 30, collect = 30, explore = 35, enter = 25 }

local function coords(texture, i)
	local col, row = i % COLS, floor(i / COLS)
	local l, t = col * CW / SHEET, row * CH / SHEET
	texture:SetTexCoord(l, l + CW / SHEET, t, t + CH / SHEET)
end

-- Show the view for a heading given in frames (fractional): the lower view at
-- full strength with the next one faded in over it by the fraction.
local function setHeading(f)
	local i = floor(f) % FRAMES
	local frac = f - floor(f)
	if i ~= lastCell then
		lastCell = i
		coords(tex, i)
	end
	local j = (i + 1) % FRAMES
	if j ~= lastCell2 then
		lastCell2 = j
		coords(tex2, j)
	end
	tex2:SetAlpha(frac)
end

local function setCell(i)
	setHeading(i)
end

local function colorFor(dist)
	local o = W.opt.arrow
	local mode = o.colorblind and "colorblind" or (o.color or "gold")
	if mode == "gold" then return 1, 0.86, 0.3 end
	local f = min(1, (dist or 0) / 500)
	if mode == "colorblind" then
		-- blue (near) -> white -> orange (far): readable with any colour vision
		if f < 0.5 then
			local k = f * 2
			return 0.35 + 0.65 * k, 0.7 + 0.3 * k, 1
		end
		local k = (f - 0.5) * 2
		return 1, 1 - 0.4 * k, 1 - 0.8 * k
	end
	-- green (near) -> gold -> red (far)
	if f < 0.5 then
		local k = f * 2
		return 0.3 + 0.7 * k, 0.95 - 0.1 * k, 0.3
	end
	local k = (f - 0.5) * 2
	return 1, 0.85 - 0.55 * k, 0.3 - 0.1 * k
end

local function formatDistance(d)
	if d >= 1000 then return ("%.1fk %s"):format(d / 1000, L["yd"]) end
	return ("%d %s"):format(floor(d + 0.5), L["yd"])
end

local function formatETA(d)
	local speed = GetUnitSpeed and W.Readable(GetUnitSpeed("player")) or 0
	if type(speed) ~= "number" or speed <= 0 then speed = 7 end
	local s = floor(d / speed + 0.5)
	if s >= 3600 then return ("%d:%02d:%02d"):format(floor(s / 3600), floor(s % 3600 / 60), s % 60) end
	return ("%d:%02d"):format(floor(s / 60), s % 60)
end

local function shortName(g)
	if g.t == "accept" or g.t == "turnin" or g.t == "talk" or g.t == "buy" or g.t == "getfp" or g.t == "sethome" then
		return g.npc or g.title or g.location or ""
	elseif g.t == "kill" then return g.target or g.npc or ""
	elseif g.t == "collect" or g.t == "use" then return g.itemName or ""
	end
	return g.text or g.location or g.npc or g.title or ""
end

local function onUpdate(_, dt)
	if not target then return end
	local c, wx, wy = C.GoalWorld(target)
	local dist, bearing
	if c then dist, bearing = C.DistanceTo(c, wx, wy) end

	textAcc = textAcc + dt
	if not dist then
		-- Other continent, an instance, or the client hides the position.
		if textAcc >= 0.5 then
			textAcc = 0
			tex:SetVertexColor(0.55, 0.55, 0.55)
			tex2:SetVertexColor(0.55, 0.55, 0.55)
			tex:SetAlpha(0.6)
			setCell(0)
			distText:SetText(C.MapName(target.map))
			etaText:SetText(L["travel there"])
		end
		return
	end
	tex:SetAlpha(1)

	local radius = ARRIVE[target.t] or 9
	local here = dist <= radius
	if here ~= arrived or arrivedFor ~= target then
		if here and arrivedFor ~= target and W.opt.arrow.arriveSound and W.opt.sound and PlaySound and SOUNDKIT then
			pcall(PlaySound, SOUNDKIT.MAP_PING or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		arrived, arrivedFor = here, here and target or arrivedFor
		textAcc = 1
	end

	if here then
		-- Point down at the spot and bob.
		bob = bob + dt * 4
		setCell(FRAMES / 2)
		tex:SetPoint("CENTER", frame, "CENTER", 0, 10 + sin(bob) * 4)
		tex:SetVertexColor(0.35, 1, 0.4)
		tex2:SetVertexColor(0.35, 1, 0.4)
		shownAngle = math.pi
	else
		local facing = C.Facing() or 0
		local rel = (bearing - facing) % PI2
		-- Follow the true heading every frame. The short ease (about 1/30 s) only
		-- takes out jitter; it is far quicker than a character can turn, so the
		-- arrow stays locked to the turn rather than trailing it.
		local diff = (rel - shownAngle + math.pi) % PI2 - math.pi
		if diff > 2.4 or diff < -2.4 then
			shownAngle = rel                       -- a jump (new target, teleport): snap
		else
			shownAngle = (shownAngle + diff * min(1, dt * 30)) % PI2
		end
		setHeading(shownAngle / PI2 * FRAMES)
		tex:SetPoint("CENTER", frame, "CENTER", 0, 10)
	end

	if textAcc >= 0.2 then
		textAcc = 0
		if here then
			distText:SetText(L["Here"])
			etaText:SetText("")
		else
			local r, g, b = colorFor(dist)
			tex:SetVertexColor(r, g, b)
			tex2:SetVertexColor(r, g, b)
			distText:SetText(W.opt.arrow.showDistance and formatDistance(dist) or "")
			etaText:SetText(W.opt.arrow.showETA and formatETA(dist) or "")
		end
	end
end

local function savePosition()
	local x, y = frame:GetCenter()
	if not x then return end
	local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	W.opt.arrow.pos = { x = x * s, y = y * s }
end

local function restorePosition()
	frame:ClearAllPoints()
	local pos = W.opt.arrow.pos
	if type(pos) == "table" and pos.x then
		local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x / s, pos.y / s)
	else
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 215)
	end
end

local function build()
	frame = CreateFrame("Button", "WaypostArrow", UIParent)
	A.frame = frame
	frame:SetSize(150, 128)
	frame:SetFrameStrata("LOW")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:RegisterForClicks("RightButtonUp")
	frame:SetScript("OnDragStart", function(self) if not W.opt.arrow.locked then self:StartMoving() end end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
		restorePosition()
	end)
	frame:SetScript("OnClick", function(self)
		UI.ShowMenu(self, {
			{ text = "Waypost", title = true },
			{ text = L["Lock arrow"], checked = W.opt.arrow.locked, func = function() W.Set("arrow.locked", not W.opt.arrow.locked) end },
			{ text = L["Reset position"], func = function() W.opt.arrow.pos = nil; restorePosition() end },
			{ text = L["Hide arrow"], func = function() W.Set("arrow.enabled", false) end },
			{ text = L["Settings"], func = function() W.Options.Toggle(true) end },
		}, 160)
	end)

	glow = frame:CreateTexture(nil, "BACKGROUND")
	glow:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(1, 0.8, 0.3)
	glow:SetAlpha(0)
	glow:SetSize(150, 90)
	glow:SetPoint("CENTER", 0, 8)

	tex = frame:CreateTexture(nil, "ARTWORK")
	tex:SetTexture(UI.MEDIA .. "Arrow3D")
	tex:SetSize(CW * 1.1, CH * 1.1)
	tex:SetPoint("CENTER", 0, 10)

	tex2 = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	tex2:SetTexture(UI.MEDIA .. "Arrow3D")
	tex2:SetAllPoints(tex)
	tex2:SetAlpha(0)

	title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	title:SetPoint("BOTTOM", tex, "TOP", 0, -8)
	title:SetWidth(220)
	title:SetWordWrap(false)

	distText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	distText:SetPoint("TOP", frame, "CENTER", 0, -32)
	etaText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	etaText:SetPoint("TOP", distText, "BOTTOM", 0, -1)
	etaText:SetTextColor(0.8, 0.8, 0.8)

	frame:SetScript("OnEnter", function(self)
		if not target then return end
		glow:SetAlpha(0.25)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText((E.GoalText(target, targetStep)), 1, 0.82, 0, 1, true)
		if target.map and target.x then
			GameTooltip:AddLine(("%s  %s"):format(C.MapName(target.map), C.Format(target.x, target.y)), 1, 1, 1)
		end
		GameTooltip:AddLine(L["Drag to move. Right-click for options."], 0.4, 0.8, 1)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function() glow:SetAlpha(0) GameTooltip:Hide() end)
	frame:SetScript("OnUpdate", onUpdate)
	frame:Hide()
	setCell(0)
end

---------------------------------------------------------------------------
-- TomTom hand-off
---------------------------------------------------------------------------
local function clearTomTom()
	if tomtomUid and TomTom and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, tomtomUid) end
	tomtomUid = nil
end

local function useTomTom()
	return W.opt.arrow.tomtom and TomTom and TomTom.AddWaypoint and true or false
end

local function setTomTom(g)
	clearTomTom()
	if not g then return end
	local map, x, y = g.map, g.x / 100, g.y / 100
	if g.era then
		local c, wx, wy = C.GoalWorld(g)
		if c then
			local mx, my = C.WorldToMap(c, wx, wy, g.map)
			if mx then x, y = mx, my end
		end
	end
	local ok, uid = pcall(TomTom.AddWaypoint, TomTom, map, x, y, {
		title = (E.GoalText(g, targetStep)):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""),
		from = "Waypost", persistent = false, minimap = true, world = true, crazy = true,
	})
	if ok then tomtomUid = uid end
end

---------------------------------------------------------------------------
-- Target selection and visibility
---------------------------------------------------------------------------
function A.Target() return target, targetStep end

function A.Refresh()
	if not frame then return end
	local g, si = E.Target()
	local changed = g ~= target
	target, targetStep = g, si
	if changed then
		arrived, arrivedFor, textAcc = false, nil, 1
		W.Fire("WP_TARGET", g, si)
		if useTomTom() then setTomTom(g) else clearTomTom() end
	end
	local o = W.opt.arrow
	local show = g and o.enabled and not useTomTom() and not W.opt.ui.hidden
		and not (W.InCombat() and not W.opt.combatUpdates)
	if show then
		title:SetText(shortName(g))
		frame:SetScale(o.scale or 1)
		frame:SetAlpha(o.alpha or 1)
		if changed or not frame:IsShown() then restorePosition() end
		frame:Show()
	else
		frame:Hide()
	end
end

local refreshSoon = W.Throttle(0.1, function() A.Refresh() end)

W.On("WP_LOGIN", function()
	build()
	restorePosition()
end)
for _, ev in ipairs({ "WP_STEP", "WP_PROGRESS", "WP_GUIDE", "WP_VISIBILITY", "WP_COMBAT_STARTED", "WP_COMBAT_ENDED" }) do
	W.On(ev, refreshSoon)
end
W.On("WP_SETTINGS", function(path)
	if not frame then return end
	if path == "*" or (type(path) == "string" and (path:find("^arrow") or path == "combatUpdates")) then
		if path == "*" or path == "arrow.tomtom" then target = nil end
		A.Refresh()
		restorePosition()
	end
end)
