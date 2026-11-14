-- World map and minimap pins for the current step.
--
-- World map: our own frames on the map canvas (the map is only read, so the
-- default UI is never tainted). They are laid out when the step changes or
-- the shown map changes; the watcher only runs while the map is open.
-- Minimap: up to a handful of pins, repositioned ten times a second while
-- the player is out of combat (or always, with "keep live in combat").

local W = Waypost
local L = W.L
local UI, E, C = W.UI, W.Engine, W.Coords
local P = {}
W.Pins = P

local sqrt, cos, sin, min = math.sqrt, math.cos, math.sin, math.min

local list = {}          -- pins for the current step: { goal, c, wx, wy, kind = "goal"|"spot", current }
local dirty = true

local function collect()
	for i = #list, 1, -1 do list[i] = nil end
	if not E.guide or not E.index then return end
	local si = E.view or E.index
	local step = E.guide.steps[si]
	if not step then return end
	local target = W.Arrow and W.Arrow.Target()
	local vis = E.Visible(step)
	for i = 1, #vis do
		local g = vis[i]
		if g.x and g.map and not E.GoalState(g, si) then
			local c, wx, wy = C.GoalWorld(g)
			if c then
				list[#list + 1] = { goal = g, c = c, wx = wx, wy = wy, kind = "goal", current = (g == target), si = si }
				if g.spots and W.opt.map.spots then
					for sx, sy in g.spots:gmatch("([%d%.]+),([%d%.]+)") do
						local c2, x2, y2 = C.ToWorld(g.map, tonumber(sx), tonumber(sy), g.era)
						if c2 then list[#list + 1] = { goal = g, c = c2, wx = x2, wy = y2, kind = "spot", si = si } end
					end
				end
			end
		end
	end
	-- The next step's first stop, faded, so you can see where the route goes.
	if W.opt.map.upcoming and not E.view then
		local steps = E.guide.steps
		for sj = si + 1, min(#steps, si + 6) do
			if W.Guides.OnlyOk(steps[sj].only) and not E.IsSkipped(sj) then
				for _, g in ipairs(E.Visible(steps[sj])) do
					if g.x and g.map then
						local c, wx, wy = C.GoalWorld(g)
						if c then list[#list + 1] = { goal = g, c = c, wx = wx, wy = wy, kind = "next", si = sj } end
						break
					end
				end
				break
			end
		end
	end
end

local function pinTooltip(self)
	local p = self.pin
	if not p then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText((E.GoalText(p.goal, p.si)), 1, 0.82, 0, 1, true)
	if p.goal.npc then GameTooltip:AddLine(p.goal.npc, 1, 1, 1) end
	if p.kind == "next" then GameTooltip:AddLine(L["Next step"], 0.6, 0.6, 0.6) end
	if p.goal.note then GameTooltip:AddLine(p.goal.note, 0.9, 0.9, 0.8, true) end
	GameTooltip:AddLine("Waypost", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local function newPin(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(22, 22)
	f.ring = f:CreateTexture(nil, "ARTWORK")
	f.ring:SetAllPoints()
	f.icon = f:CreateTexture(nil, "OVERLAY")
	f.icon:SetPoint("CENTER")
	f:SetScript("OnEnter", pinTooltip)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return f
end

local function dress(f, p, size)
	f.pin = p
	if p.kind == "spot" then
		f:SetSize(size * 0.5, size * 0.5)
		f.ring:SetTexture(UI.MEDIA .. "Dot")
		f.ring:SetVertexColor(1, 0.82, 0.1, 0.85)
		f.icon:Hide()
		f:EnableMouse(false)
		return
	end
	f:EnableMouse(true)
	local s = p.current and size * 1.25 or size
	f:SetSize(s, s)
	f.ring:SetTexture(UI.MEDIA .. "Pin")
	if p.kind == "next" then
		f.ring:SetVertexColor(0.7, 0.7, 0.7, 0.7)
		f:SetAlpha(0.7)
	else
		if p.current then f.ring:SetVertexColor(1, 0.85, 0.2, 1) else f.ring:SetVertexColor(0.95, 0.75, 0.3, 1) end
		f:SetAlpha(1)
	end
	local t = p.goal.t
	f.icon:Show()
	UI.SetIcon(f.icon, W.StepFrame.GLYPH[t] or "note")
	f.icon:SetSize(s * 0.5, s * 0.5)
	local c = (p.kind ~= "next" and W.StepFrame.TINT[t]) or UI.C.text
	f.icon:SetVertexColor(c[1], c[2], c[3])
end

---------------------------------------------------------------------------
-- World map
---------------------------------------------------------------------------
local wm = { pins = {}, map = nil, scale = nil }

local function drawWorld()
	local map = WorldMapFrame
	if not (map and wm.host) then return end
	local id = map:GetMapID()
	local canvas = wm.canvas
	local cw, ch = canvas:GetSize()
	local cscale = (map.GetCanvasScale and map:GetCanvasScale()) or 1
	if cscale <= 0 then cscale = 1 end
	wm.map, wm.scale = id, cscale
	local n = 0
	if id and W.opt.map.world and not W.opt.ui.hidden then
		for i = 1, #list do
			local p = list[i]
			local x, y = C.WorldToMap(p.c, p.wx, p.wy, id)
			if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
				n = n + 1
				local f = wm.pins[n]
				if not f then
					f = newPin(wm.host)
					wm.pins[n] = f
				end
				dress(f, p, 24)
				local s = 1 / cscale
				f:SetScale(s)
				f:ClearAllPoints()
				f:SetPoint("CENTER", canvas, "TOPLEFT", x * cw / s, -y * ch / s)
				f:SetFrameLevel(wm.host:GetFrameLevel() + (p.current and 30 or p.kind == "spot" and 5 or 20))
				f:Show()
			end
		end
	end
	for i = n + 1, #wm.pins do wm.pins[i]:Hide() end
end

local function hookWorldMap()
	if wm.host or not (WorldMapFrame and WorldMapFrame.GetCanvas and WorldMapFrame.GetMapID) then return end
	local canvas = WorldMapFrame:GetCanvas()
	if not canvas then return end
	wm.canvas = canvas
	wm.host = CreateFrame("Frame", nil, canvas)
	wm.host:SetAllPoints(canvas)
	wm.host:SetFrameLevel(math.min(9000, canvas:GetFrameLevel() + 2400))
	local acc = 0
	wm.host:SetScript("OnUpdate", function(_, dt)
		acc = acc + dt
		if acc < 0.15 then return end
		acc = 0
		local id = WorldMapFrame:GetMapID()
		local sc = (WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()) or 1
		if dirty or id ~= wm.map or sc ~= wm.scale then
			if dirty then collect() end
			dirty = false
			drawWorld()
			P.DrawMinimap(true)
		end
	end)
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------
local mm = { pins = {} }
local OUTDOOR = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

local function viewRadius()
	if C_Minimap and C_Minimap.GetViewRadius then
		local r = C_Minimap.GetViewRadius()
		if type(r) == "number" and r > 0 then return r end
	end
	local zoom = Minimap:GetZoom() or 0
	local indoors = IsIndoors and IsIndoors()
	return ((indoors and INDOOR or OUTDOOR)[zoom] or OUTDOOR[0]) / 2
end

function P.DrawMinimap(relayout)
	if not Minimap then return end
	local show = W.opt.map.minimap and not W.opt.ui.hidden and #list > 0
	local pc, px, py
	if show then pc, px, py = C.PlayerWorld() end
	if not (show and pc) then
		for i = 1, #mm.pins do mm.pins[i]:Hide() end
		return
	end
	local radius = viewRadius()
	local half = Minimap:GetWidth() / 2
	local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
	local facing = rotate and C.Facing() or nil
	local cf, sf = 1, 0
	if facing then cf, sf = cos(facing), sin(facing) end
	local n = 0
	for i = 1, #list do
		local p = list[i]
		if p.c == pc and p.kind ~= "next" then
			-- screen right = east = decreasing "west" coordinate; screen up = north
			local dx, dy = (py - p.wy), (p.wx - px)
			if facing then dx, dy = dx * cf - dy * sf, dx * sf + dy * cf end
			local d = sqrt(dx * dx + dy * dy)
			local edge = d > radius * 0.92
			if not edge or p.current then
				n = n + 1
				local f = mm.pins[n]
				if not f then
					f = newPin(Minimap)
					f:SetFrameStrata("MEDIUM")
					f:SetFrameLevel(Minimap:GetFrameLevel() + 6)
					mm.pins[n] = f
				end
				if relayout or f.pin ~= p then dress(f, p, 16) end
				if edge then
					local k = radius * 0.92 / d
					dx, dy = dx * k, dy * k
				end
				f:ClearAllPoints()
				f:SetPoint("CENTER", Minimap, "CENTER", dx / radius * half, dy / radius * half)
				f:SetAlpha(edge and 0.75 or 1)
				f:Show()
			end
		end
	end
	for i = n + 1, #mm.pins do mm.pins[i]:Hide() end
end

local ticker
local function updateTicker()
	local want = W.opt and W.opt.map.minimap and not W.opt.ui.hidden and #list > 0
	if want and not ticker and C_Timer and C_Timer.NewTicker then
		ticker = C_Timer.NewTicker(0.1, function()
			if W.InCombat() and not W.opt.combatUpdates then return end
			P.DrawMinimap(false)
		end)
	elseif not want and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

---------------------------------------------------------------------------
function P.Refresh()
	collect()
	dirty = false
	hookWorldMap()
	if WorldMapFrame and WorldMapFrame:IsShown() then drawWorld() else dirty = true end
	P.DrawMinimap(true)
	updateTicker()
end

local refreshSoon = W.Throttle(0.2, function() P.Refresh() end)
for _, ev in ipairs({ "WP_STEP", "WP_PROGRESS", "WP_GUIDE", "WP_TARGET", "WP_VISIBILITY", "WP_ENGINE_READY" }) do
	W.On(ev, refreshSoon)
end
W.On("WP_SETTINGS", function(path)
	if path == "*" or (type(path) == "string" and path:find("^map")) then refreshSoon() end
end)
W.On("WP_COMBAT_STARTED", function()
	if not W.opt.combatUpdates then
		for i = 1, #mm.pins do mm.pins[i]:Hide() end
	end
end)
W.On("WP_COMBAT_ENDED", function() P.DrawMinimap(true) end)
