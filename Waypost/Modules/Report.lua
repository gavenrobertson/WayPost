-- /waypost report: one block of text with everything needed to fix a wrong
-- step or coordinate (guide, step, goals, where you stand, client build).

local W = Waypost
local L = W.L
local UI, E, C = W.UI, W.Engine, W.Coords
local R = {}
W.Report = R

function R.Build(comment)
	local lines = {}
	local function add(fmt, ...) lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt end
	local version, build, _, toc = "?", "?", nil, "?"
	if GetBuildInfo then version, build, _, toc = GetBuildInfo() end
	local p = W.player
	add("Waypost report")
	add("Addon: %s   Client: %s (%s) interface %s   Locale: %s", W.version, tostring(version), tostring(build), tostring(toc), GetLocale and GetLocale() or "?")
	add("Character: level %s %s %s (%s)", tostring(p.level), tostring(p.race), tostring(p.class), tostring(p.faction))
	local map, x, y = C.PlayerMapPos()
	if map then
		add("Position: %s (map %d) %.2f, %.2f   Zone: %s / %s", C.MapName(map), map, x, y,
			GetRealZoneText and GetRealZoneText() or "?", GetSubZoneText and GetSubZoneText() or "")
	else
		add("Position: unavailable (instance?)")
	end
	local target = W.Readable(UnitName("target"))
	if target then
		local guid = W.Readable(UnitGUID("target"))
		local id = type(guid) == "string" and select(6, strsplit("-", guid)) or "?"
		add("Target: %s (id %s)", target, tostring(id))
	end
	if E.guide and E.index then
		local si = E.view or E.index
		local step = E.guide.steps[si]
		add("Guide: %s   Step %d/%d: %s", E.guide.id, si, #E.guide.steps, step.title or "")
		for _, g in ipairs(E.Visible(step)) do
			local done = E.GoalState(g, si)
			local text = (E.GoalText(g, si)):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			local at = g.map and (" @%.2f,%.2f map %d%s"):format(g.x, g.y, g.map, g.era and " era" or "") or ""
			local dist = g.map and C.GoalDistance(g)
			add("  [%s] %s%s%s%s", done and "x" or " ", text, g.quest and (" (quest " .. g.quest .. ")") or "", at,
				dist and (" %.0f yd away"):format(dist) or "")
		end
	else
		add("Guide: none")
	end
	if W.lastError then add("Last error: %s", tostring(W.lastError)) end
	if comment and comment ~= "" then add("Note: %s", comment) end
	return table.concat(lines, "\n")
end

function R.Open(comment)
	local text = R.Build(comment)
	W.db.reports = W.db.reports or {}
	table.insert(W.db.reports, { at = time(), text = text })
	while #W.db.reports > 20 do table.remove(W.db.reports, 1) end
	UI.CopyText(L["Report a Problem"], text,
		L["Copy this (Ctrl+C) into a new issue at github.com/gavenrobertson/waypost/issues. Say what was wrong in a sentence."])
end
