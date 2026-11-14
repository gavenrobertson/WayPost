-- Waypost guide text format: parse, serialize, and share as import strings.
-- The format is documented in docs/GUIDE_FORMAT.md; tools/editor.html speaks it too.
--
--   title Goldshire loop
--   faction Alliance
--   levels 5-10
--   map 1429
--
--   step Marshal Dughan
--     note He stands outside the inn.
--     accept 62 The Fargodeep Mine @42.1,65.9
--     kill 10 Kobold Vermin quest 62 obj 1 @40.5,79.0
--     turnin 62 @42.1,65.9 -- back at the inn
--
-- Every line error carries its line number so the editor can point at it.

local W = Waypost
local L = W.L
local P = {}
W.Parser = P

local tonumber, trim = tonumber, W.Trim

local HEADER = { guide = "id", id = "id", title = "title", faction = "faction", zone = "zone",
	category = "category", next = "next", why = "why", author = "author" }

local CLASSES = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1, DRUID = 1 }
local RACES = { Human = 1, Dwarf = 1, NightElf = 1, Gnome = 1, Orc = 1, Troll = 1, Scourge = 1, Tauren = 1, Skyborne = 1 }
local RACE_ALIAS = { ["night elf"] = "NightElf", nightelf = "NightElf", undead = "Scourge", forsaken = "Scourge", scourge = "Scourge" }

local function splitList(s)
	local out = {}
	for part in s:gmatch("[^,]+") do
		part = trim(part)
		if part ~= "" then out[#out + 1] = part end
	end
	return out
end

local function normRace(s)
	local low = s:lower()
	if RACE_ALIAS[low] then return RACE_ALIAS[low] end
	for r in pairs(RACES) do if r:lower() == low then return r end end
	return nil
end

-- "only Warrior, Mage" / "only Human" -> { classes=, races= }
local function parseOnly(s)
	local o = {}
	s = s:gsub("[Nn]ight [Ee]lf", "NightElf")
	for _, w in ipairs(splitList((s:gsub("%s+", ",")))) do
		local up = w:upper()
		if CLASSES[up] then
			o.classes = o.classes or {}
			o.classes[#o.classes + 1] = up
		elseif w == "Alliance" or w == "Horde" then
			o.factions = o.factions or {}
			o.factions[#o.factions + 1] = w
		else
			local r = normRace(w)
			if r then
				o.races = o.races or {}
				o.races[#o.races + 1] = r
			elseif w:lower() ~= "race" and w:lower() ~= "class" then
				return nil, ("unknown class or race '%s'"):format(w)
			end
		end
	end
	return o
end

local GOALS = {
	accept = true, turnin = true, complete = true, kill = true, collect = true, use = true,
	interact = true, talk = true, ["goto"] = true, level = true, train = true, fly = true,
	getfp = true, sethome = true, buy = true, vendor = true, learn = true, money = true,
	hearth = true, note = true, explore = true, enter = true,
}

-- Pull "@x,y[,map][,era]", "optional", "quest N", "obj N", "-- note" out of a goal line.
local function extract(rest, defMap, defEra)
	local g = {}
	local note = rest:match("%s*%-%-%s*(.-)%s*$")
	if note then
		rest = rest:gsub("%s*%-%-.*$", "")
		if note ~= "" then g.note = note end
	end
	if rest:find("%f[%w]optional%f[%W]") then
		g.optional = true
		rest = rest:gsub("%s*%f[%w]optional%f[%W]", "")
	end
	local at = rest:match("@%s*([%w%.,%s]-)%s*$")
	if at then
		local parts = splitList(at)
		local x, y = tonumber(parts[1]), tonumber(parts[2])
		if not (x and y) then return nil, "bad coordinates after @ (use @x,y or @x,y,mapID)" end
		g.x, g.y = x, y
		g.map = tonumber(parts[3] or "") or defMap
		if parts[3] == "era" or parts[4] == "era" or (not parts[3] and defEra) then g.era = true end
		rest = rest:gsub("%s*@[^@]*$", "")
		if not g.map then return nil, "coordinates need a map: add 'map <uiMapID>' to the header or @x,y,mapID" end
	end
	local q = rest:match("%f[%w]quest%s+(%d+)")
	if q then g.quest = tonumber(q); rest = rest:gsub("%s*%f[%w]quest%s+%d+", "") end
	local o = rest:match("%f[%w]obj%s+(%d+)")
	if o then g.oi = tonumber(o); rest = rest:gsub("%s*%f[%w]obj%s+%d+", "") end
	return g, nil, trim(rest)
end

local function goalFrom(verb, rest, defMap, defEra)
	local g, err, args = extract(rest, defMap, defEra)
	if not g then return nil, err end
	g.t = verb
	local n, tail = args:match("^(%d+)%s*(.*)$")
	if verb == "accept" or verb == "turnin" or verb == "complete" then
		if not n then return nil, verb .. " needs a quest ID" end
		g.quest = tonumber(n)
		if tail ~= "" then g.title = tail end
	elseif verb == "kill" then
		if n then g.count = tonumber(n); g.target = tail ~= "" and tail or nil else g.target = args end
		if not g.target then return nil, "kill needs a target name" end
		g.count = g.count or 1
	elseif verb == "collect" or verb == "buy" then
		if not n then return nil, verb .. " needs <count> <itemID>" end
		local id, name = tail:match("^(%d+)%s*(.*)$")
		if not id then return nil, verb .. " needs <count> <itemID>" end
		g.count, g.item = tonumber(n), tonumber(id)
		if name ~= "" then g.itemName = name end
	elseif verb == "use" then
		if not n then return nil, "use needs an itemID" end
		g.item = tonumber(n)
		if tail ~= "" then g.itemName = tail end
	elseif verb == "interact" or verb == "talk" then
		if args == "" then return nil, verb .. " needs a name" end
		g.npc = args
	elseif verb == "goto" or verb == "explore" or verb == "enter" then
		-- "goto 48.2,42.9[,map] text" is allowed without the @
		local cx, cy, cm, txt = args:match("^([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*(%d*)%s*(.*)$")
		if cx then
			g.x, g.y = tonumber(cx), tonumber(cy)
			g.map = tonumber(cm) or defMap
			g.era = (not tonumber(cm) and defEra) or nil
			if txt and txt ~= "" then g.text = txt end
			if not g.map then return nil, "goto needs a map: add 'map <uiMapID>' to the header" end
		elseif args ~= "" then
			g.text = args
		end
		if not g.x then return nil, verb .. " needs coordinates" end
	elseif verb == "level" then
		if not n then return nil, "level needs a number" end
		g.level = tonumber(n)
	elseif verb == "fly" or verb == "getfp" or verb == "sethome" then
		if args == "" then return nil, verb .. " needs a location name" end
		g.location = args
	elseif verb == "learn" then
		if not n then return nil, "learn needs a spellID" end
		g.spell = tonumber(n)
		if tail ~= "" then g.spellName = tail end
	elseif verb == "money" then
		if not n then return nil, "money needs copper" end
		g.money = tonumber(n)
	elseif verb == "note" then
		if args == "" then return nil, "note needs text" end
		g.text = args
	elseif verb == "train" then
		g.class = true
		if args ~= "" then g.text = args end
	end
	return g
end

-- Returns guide table, or nil plus a list of { line=, msg= } errors.
function P.Parse(text)
	local guide = { steps = {}, category = "Custom", minLevel = 1, maxLevel = 60, source = "Custom" }
	local errors = {}
	local step
	local defMap, defEra
	local ln = 0
	local function err(msg) errors[#errors + 1] = { line = ln, msg = msg } end

	for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
		ln = ln + 1
		local line = trim((raw:gsub("\r", "")))
		if line ~= "" and not line:find("^#") and not line:find("^%-%-") then
			local key, rest = line:match("^(%S+)%s*(.*)$")
			key = key:lower()
			if HEADER[key] and not step then
				guide[HEADER[key]] = rest
			elseif key == "races" and not step then
				guide.races = {}
				for _, r in ipairs(splitList(rest)) do
					local nr = normRace(r)
					if nr then guide.races[#guide.races + 1] = nr else err("unknown race '" .. r .. "'") end
				end
			elseif key == "classes" and not step then
				guide.classes = {}
				for _, c in ipairs(splitList(rest)) do
					if CLASSES[c:upper()] then guide.classes[#guide.classes + 1] = c:upper() else err("unknown class '" .. c .. "'") end
				end
			elseif key == "levels" and not step then
				local a, b = rest:match("^(%d+)%s*%-%s*(%d+)$")
				if a then guide.minLevel, guide.maxLevel = tonumber(a), tonumber(b) else err("levels must look like 1-10") end
			elseif key == "map" then
				local m, e = rest:match("^(%d+)%s*(%a*)$")
				if not m then err("map needs a uiMapID number") else defMap, defEra = tonumber(m), e == "era" or nil end
			elseif key == "step" then
				step = { title = rest ~= "" and rest or ("Step " .. (#guide.steps + 1)), goals = {} }
				guide.steps[#guide.steps + 1] = step
			elseif not step then
				err(("'%s' must come after a 'step' line (or is not a header keyword)"):format(key))
			elseif key == "tip" then
				step.note = step.note and (step.note .. " " .. rest) or rest
			elseif key == "why" then
				step.why = rest
			elseif key == "danger" then
				step.danger = rest
			elseif key == "only" then
				local o, e = parseOnly(rest)
				if not o then err(e) else step.only = o end
			elseif key == "label" then
				step.label = rest
			elseif GOALS[key] then
				local g, e = goalFrom(key, rest, defMap, defEra)
				if not g then err(e) else step.goals[#step.goals + 1] = g end
			else
				err(("unknown keyword '%s'"):format(key))
			end
		end
	end
	if not guide.title then err("missing 'title' line") end
	if #guide.steps == 0 then err("a guide needs at least one 'step'") end
	if not guide.id and guide.title then
		guide.id = "custom/" .. guide.title:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
	end
	if #errors > 0 then return nil, errors end
	return guide
end

---------------------------------------------------------------------------
-- Serialize any guide (imported or custom) back to text
---------------------------------------------------------------------------
local function num(v) return (("%.2f"):format(v):gsub("%.?0+$", "")) end

local function at(g, defMap)
	if not (g.x and g.y and g.map) then return "" end
	local s = " @" .. num(g.x) .. "," .. num(g.y)
	if g.map ~= defMap or g.era then s = s .. "," .. g.map end
	if g.era then s = s .. ",era" end
	return s
end

local function tail(g)
	local s = ""
	if g.quest and not (g.t == "accept" or g.t == "turnin" or g.t == "complete") then s = s .. " quest " .. g.quest end
	if g.oi then s = s .. " obj " .. g.oi end
	return s
end

local function onlyText(o)
	local parts = {}
	for _, c in ipairs(o.classes or {}) do parts[#parts + 1] = c:sub(1, 1) .. c:sub(2):lower() end
	for _, r in ipairs(o.races or {}) do parts[#parts + 1] = r end
	for _, f in ipairs(o.factions or {}) do parts[#parts + 1] = f end
	return table.concat(parts, ", ")
end

function P.Serialize(guide)
	local out = {}
	-- one logical line per entry: notes with line breaks are flattened
	local function add(s) out[#out + 1] = (s:gsub("%s*[\r\n]+%s*", " ")) end
	add("title " .. (guide.title or "Untitled"))
	if guide.id and not guide.id:find("^custom/") then add("guide " .. guide.id) end
	if guide.faction then add("faction " .. guide.faction) end
	if guide.races then add("races " .. table.concat(guide.races, ", ")) end
	if guide.classes then add("classes " .. table.concat(guide.classes, ", ")) end
	add(("levels %d-%d"):format(guide.minLevel or 1, guide.maxLevel or 60))
	if guide.zone then add("zone " .. guide.zone) end
	if guide.next then add("next " .. guide.next) end
	if guide.why then add("why " .. guide.why) end
	add("")
	for _, s in ipairs(guide.steps or {}) do
		add("step " .. (s.title or ""))
		if s.note then add("  tip " .. s.note) end
		if s.why then add("  why " .. s.why) end
		if s.danger then add("  danger " .. s.danger) end
		if s.only then add("  only " .. onlyText(s.only)) end
		if s.label then add("  label " .. s.label) end
		for _, g in ipairs(s.goals or {}) do
			local t = g.t
			local line
			if t == "accept" or t == "turnin" or t == "complete" then
				line = ("%s %d%s"):format(t, g.quest or 0, g.title and (" " .. g.title) or "")
			elseif t == "kill" then
				line = ("kill %d %s"):format(g.count or 1, g.target or g.npc or "?")
			elseif t == "collect" or t == "buy" then
				line = ("%s %d %d%s"):format(t, g.count or 1, g.item or 0, g.itemName and (" " .. g.itemName) or "")
			elseif t == "use" then
				line = ("use %d%s"):format(g.item or 0, g.itemName and (" " .. g.itemName) or "")
			elseif t == "interact" or t == "talk" then
				line = t .. " " .. (g.npc or "?")
			elseif t == "goto" or t == "explore" or t == "enter" then
				line = t .. " " .. (g.text or g.location or "")
			elseif t == "level" then
				line = "level " .. (g.level or 1)
			elseif t == "fly" or t == "getfp" or t == "sethome" then
				line = t .. " " .. (g.location or "?")
			elseif t == "learn" then
				line = ("learn %d%s"):format(g.spell or 0, g.spellName and (" " .. g.spellName) or "")
			elseif t == "money" then
				line = "money " .. (g.money or 0)
			elseif t == "train" then
				line = "train" .. (g.text and (" " .. g.text) or "")
			elseif t == "hearth" or t == "vendor" then
				line = t
			else
				line = "note " .. (g.text or g.title or t)
			end
			line = "  " .. line .. tail(g)
			if g.optional then line = line .. " optional" end
			if t == "goto" or t == "explore" or t == "enter" then
				if g.x then line = line .. at(g) end
			else
				line = line .. at(g)
			end
			if g.note then line = line .. " -- " .. g.note:gsub("\n", " ") end
			add(line)
		end
		add("")
	end
	return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Import strings:  WP1:<base64 text>  or  WP2:<base64 deflate>  (when the client can compress)
---------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local decodeMap = {}
for i = 1, 64 do decodeMap[B64:byte(i)] = i - 1 end

local function b64encode(data)
	local out, byte = {}, string.byte
	for i = 1, #data, 3 do
		local a, b, c = byte(data, i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function b64decode(data)
	data = data:gsub("[^%w%+/=]", "")
	local out, char = {}, string.char
	for i = 1, #data, 4 do
		local a, b, c, d = data:byte(i, i + 3)
		local n1, n2 = decodeMap[a], decodeMap[b]
		if not (n1 and n2) then return nil end
		local n3, n4 = decodeMap[c or 61], decodeMap[d or 61]
		local n = n1 * 262144 + n2 * 4096 + (n3 or 0) * 64 + (n4 or 0)
		out[#out + 1] = char(math.floor(n / 65536) % 256)
		if n3 then out[#out + 1] = char(math.floor(n / 256) % 256) end
		if n4 then out[#out + 1] = char(n % 256) end
	end
	return table.concat(out)
end
P.B64Encode, P.B64Decode = b64encode, b64decode

function P.Export(text)
	local E = C_EncodingUtil
	if E and E.CompressString and E.EncodeBase64 and Enum and Enum.CompressionMethod then
		local ok, packed = pcall(E.CompressString, text, Enum.CompressionMethod.Deflate)
		if ok and packed then
			local ok2, enc = pcall(E.EncodeBase64, packed)
			if ok2 and enc then return "WP2:" .. enc end
		end
	end
	return "WP1:" .. b64encode(text)
end

function P.Import(str)
	str = trim(str or "")
	local kind, body = str:match("^WP(%d):(.+)$")
	if not kind then
		-- Plain guide text pasted directly is fine too.
		if str:find("\n") and str:find("step") then return str end
		return nil, L["Not a Waypost import string."]
	end
	if kind == "1" then
		local t = b64decode(body)
		if not t then return nil, L["The import string is damaged."] end
		return t
	elseif kind == "2" then
		local E = C_EncodingUtil
		if not (E and E.DecodeBase64 and E.DecompressString) then return nil, L["This client cannot read compressed strings."] end
		local ok, packed = pcall(E.DecodeBase64, body)
		if not ok or not packed then return nil, L["The import string is damaged."] end
		local ok2, t = pcall(E.DecompressString, packed, Enum.CompressionMethod.Deflate)
		if not ok2 or not t then return nil, L["The import string is damaged."] end
		return t
	end
	return nil, L["Not a Waypost import string."]
end
