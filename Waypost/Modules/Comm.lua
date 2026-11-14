-- Addon messages for party and guild sync.
-- Sending can fail (trial accounts cannot send addon messages; some chat is
-- locked in instances): every failure is swallowed and remembered, so the
-- rest of the addon keeps working and only says "sync unavailable".

local W = Waypost
local Cm = {}
W.Comm = Cm

local PREFIX = "Waypost"
local handlers = {}
Cm.available = true
Cm.reason = nil

function Cm.On(cmd, fn) handlers[cmd] = fn end

local function clean(v)
	return (tostring(v == nil and "" or v):gsub("[\t\n\r]", " "))
end

function Cm.Send(channel, cmd, ...)
	if not Cm.available then return false end
	local fn = C_ChatInfo and C_ChatInfo.SendAddonMessage
	if not fn then return false end
	if channel == "PARTY" and not (IsInGroup and IsInGroup()) then return false end
	if channel == "GUILD" and not (IsInGuild and IsInGuild()) then return false end
	local parts = { cmd }
	for i = 1, select("#", ...) do parts[#parts + 1] = clean((select(i, ...))) end
	local msg = table.concat(parts, "\t")
	if #msg > 250 then msg = msg:sub(1, 250) end
	local ok, result = pcall(fn, PREFIX, msg, channel)
	if not ok then return false end
	local R = Enum and Enum.SendAddonMessageResult
	if R and type(result) == "number" and result ~= R.Success then
		if R.AddOnMessageLockdown and result == R.AddOnMessageLockdown then return false end      -- temporary
		if R.AddonMessageThrottle and result == R.AddonMessageThrottle then return false end       -- temporary
		if R.NotInGroup and result == R.NotInGroup then return false end
		if R.ChannelThrottle and result == R.ChannelThrottle then return false end
		-- Anything else (general failure, invalid target on a restricted account) repeats: stop trying this session.
		Cm.fails = (Cm.fails or 0) + 1
		if Cm.fails >= 3 then
			Cm.available = false
			Cm.reason = "send"
		end
		return false
	elseif result == false then
		Cm.fails = (Cm.fails or 0) + 1
		if Cm.fails >= 3 then Cm.available, Cm.reason = false, "send" end
		return false
	end
	Cm.fails = 0
	return true
end

function Cm.ShortName(sender)
	if type(sender) ~= "string" then return "?" end
	local name, realm = sender:match("^([^-]+)-(.+)$")
	if not name then return sender end
	local mine = (GetNormalizedRealmName and GetNormalizedRealmName()) or (W.player.realm or ""):gsub("[%s%-]", "")
	if realm == mine then return name end
	return sender
end

function Cm.IsMe(sender)
	return Cm.ShortName(sender) == W.player.name
end

W.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
	prefix, text, channel, sender = W.Readable(prefix), W.Readable(text), W.Readable(channel), W.Readable(sender)
	if prefix ~= PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return end
	if Cm.IsMe(sender) then return end
	local fields = {}
	for part in (text .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = part end
	local fn = handlers[fields[1]]
	if fn then fn(sender, channel, unpack(fields, 2)) end
end)

W.On("WP_LOGIN", function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		local ok = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
		if not ok then Cm.available, Cm.reason = false, "prefix" end
	else
		Cm.available, Cm.reason = false, "api"
	end
	if IsTrialAccount and IsTrialAccount() then Cm.available, Cm.reason = false, "trial" end
end)
