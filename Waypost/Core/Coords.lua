-- Map and world coordinates.
--
-- Route coordinates come in two frames: "era" (the classic map bounds the
-- quest data was measured in, see Data/MapFrames.lua) and "live" (whatever
-- the running client's maps say). Everything is converted to world yards
-- (continent, north, west) so distance and bearing work across zone borders
-- and survive Forever re-cutting a zone map.

local W = Waypost
local C = {}
W.Coords = C

local sqrt, atan2, pi, floor = math.sqrt, math.atan2, math.pi, math.floor
local Readable = W.Readable

local eraFrames = {}
function W.RegisterMapFrames(t) eraFrames = t end

local scratch
local function vec(x, y)
	if not scratch then scratch = CreateVector2D and CreateVector2D(0, 0) or {} end
	scratch.x, scratch.y = x, y
	return scratch
end

local function xy(v)
	if not v then return nil end
	if v.GetXY then return v:GetXY() end
	return v.x, v.y
end

-- live map position (0-100) -> continent, north, west
local function liveToWorld(map, x, y)
	if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
	local ok, c, pos = pcall(C_Map.GetWorldPosFromMapPos, map, vec(x / 100, y / 100))
	if not ok or not c then return nil end
	local wx, wy = xy(pos)
	if not wx then return nil end
	return c, wx, wy
end

-- Converts a map point to world yards. era=true reads the point in the Era frame.
function C.ToWorld(map, x, y, era)
	if not (map and x and y) then return nil end
	if era then
		local b = eraFrames[map]
		if b then
			-- { continent, left, right, top, bottom }
			return b[1], b[4] + (b[5] - b[4]) * y / 100, b[2] + (b[3] - b[2]) * x / 100
		end
	end
	return liveToWorld(map, x, y)
end

-- Cache world positions on the goal table itself (computed once per goal).
function C.GoalWorld(goal)
	if goal._wc == nil then
		local c, wx, wy = C.ToWorld(goal.map, goal.x, goal.y, goal.era)
		if c then
			goal._wc, goal._wx, goal._wy = c, wx, wy
		else
			goal._wc = false
		end
	end
	if goal._wc then return goal._wc, goal._wx, goal._wy end
	return nil
end

-- world -> position on a given live map (0-1), for map pins
local liveBounds = {}
local function boundsOf(map)
	local b = liveBounds[map]
	if b == nil then
		b = false
		local c1, top, left = liveToWorld(map, 0, 0)
		local c2, bottom, right = liveToWorld(map, 100, 100)
		if c1 and c1 == c2 and top ~= bottom and left ~= right then
			b = { c = c1, top = top, bottom = bottom, left = left, right = right }
		end
		liveBounds[map] = b
	end
	return b or nil
end

function C.WorldToMap(continent, wx, wy, map)
	local b = boundsOf(map)
	if not b or b.c ~= continent then return nil end
	local x = (wy - b.left) / (b.right - b.left)
	local y = (wx - b.top) / (b.bottom - b.top)
	return x, y
end

-- Player position (map, x, y in 0-100). nil in instances or while secret.
function C.PlayerMapPos()
	if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
	local map = Readable(C_Map.GetBestMapForUnit("player"))
	if not map then return nil end
	local pos = C_Map.GetPlayerMapPosition(map, "player")
	local x, y = xy(pos)
	x, y = Readable(x), Readable(y)
	if not x or (x == 0 and y == 0) then return nil end
	return map, x * 100, y * 100
end

-- Player world position. UnitPosition first (cheapest), map fallback.
function C.PlayerWorld()
	if UnitPosition then
		local ok, wx, wy, _, instance = pcall(UnitPosition, "player")
		if ok then
			wx, wy, instance = Readable(wx), Readable(wy), Readable(instance)
			if type(wx) == "number" and type(wy) == "number" and instance then
				return instance, wx, wy
			end
		end
	end
	local map, x, y = C.PlayerMapPos()
	if not map then return nil end
	return liveToWorld(map, x, y)
end

-- Distance (yards) and bearing (radians, counter-clockwise from north) from the player.
function C.DistanceTo(c, wx, wy)
	local pc, px, py = C.PlayerWorld()
	if not pc or pc ~= c then return nil end
	local dn, dw = wx - px, wy - py
	return sqrt(dn * dn + dw * dw), atan2(dw, dn)
end

function C.GoalDistance(goal)
	local c, wx, wy = C.GoalWorld(goal)
	if not c then return nil end
	return C.DistanceTo(c, wx, wy)
end

function C.Facing()
	local f = GetPlayerFacing and Readable(GetPlayerFacing())
	return f
end

function C.MapName(map)
	if not map then return "" end
	local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return info and info.name or ("Map " .. map)
end

-- Two-decimal "x, y" readout.
function C.Format(x, y)
	return ("%.1f, %.1f"):format(floor(x * 10 + 0.5) / 10, floor(y * 10 + 0.5) / 10)
end

C.PI2 = pi * 2
