-- Slash commands: /waypost (also /wpost, /wayp).

local W = Waypost
local L = W.L
local E = W.Engine

local HELP = {
	{ "", "show or hide the guide window" },
	{ "guides", "choose a guide" },
	{ "config", "open settings" },
	{ "next | back | skip | undo", "move through the guide; undo brings back a skipped step" },
	{ "later", "the quests you set aside; on a step, the Later button sets its quests aside" },
	{ "help", "the welcome and help window" },
	{ "rescan", "re-read the whole guide against your quest log" },
	{ "why", "explain the current step" },
	{ "where", "print your coordinates for writing guides" },
	{ "nearest trainer|vendor|flight|inn", "point the arrow at the nearest one; /waypost resume to return" },
	{ "party", "party progress and sync" },
	{ "guild", "guild leveling board" },
	{ "guildroute", "officers: make your current guide the guild route" },
	{ "announce <text>", "officers: send a notice to the guild" },
	{ "orphans", "quests in your log the route won't finish" },
	{ "talents", "talent guide" },
	{ "tracker", "the live XP tracker" },
	{ "xp", "leveling speed, with a graph of the time each level took" },
	{ "layout simple|standard|detailed", "how much the guide window shows" },
	{ "ding", "preview the level-up animation" },
	{ "editor", "write, import or export a guide" },
	{ "record start|stop", "record your route as a draft guide" },
	{ "report [note]", "copyable problem report" },
	{ "reset", "reset window and arrow positions" },
}

W.Commands = { HELP = HELP }

local function help()
	W.Print("v" .. W.version)
	for _, h in ipairs(HELP) do
		DEFAULT_CHAT_FRAME:AddMessage(("  |cffffd100/waypost %s|r  %s"):format(h[1], L[h[2]]))
	end
end

local function handle(msg)
	msg = W.Trim(msg or "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "toggle" or cmd == "show" or cmd == "hide" then
		W.StepFrame.Toggle(cmd == "show" and true or cmd == "hide" and false or nil)
	elseif cmd == "guides" or cmd == "guide" or cmd == "pick" then
		W.Picker.Toggle(true)
	elseif cmd == "config" or cmd == "options" or cmd == "settings" then
		W.Options.Toggle(true)
	elseif cmd == "next" then E.Next()
	elseif cmd == "back" or cmd == "prev" then E.Back()
	elseif cmd == "skip" then E.Skip()
	elseif cmd == "undo" then E.UndoSkip()
	elseif cmd == "later" or cmd == "aside" then W.SetAside.Toggle(true)
	elseif cmd == "help" or cmd == "welcome" or cmd == "?" then W.Help.Open(cmd == "welcome" and "welcome" or nil)
	elseif cmd == "commands" then help()
	elseif cmd == "ding" then
		W.StepFrame.Toggle(true)
		if not W.Ding.Play(W.player.level or 1, L["This is what a level-up looks like"]) then
			W.Print(L["The level-up animation is switched off in settings."])
		end
	elseif cmd == "rescan" then
		E.Rescan()
		W.Print(L["Guide re-read from the first step."])
	elseif cmd == "why" then
		W.Print(E.Why() or L["No guide loaded."])
	elseif cmd == "where" then
		local map, x, y = W.Coords.PlayerMapPos()
		if map then
			W.Print(("%s: map %d   @%.1f,%.1f,%d"):format(W.Coords.MapName(map), map, x, y, map))
		else
			W.Print(L["No position here."])
		end
	elseif cmd == "nearest" or cmd == "near" then
		W.Nearby.Go((rest or ""):lower())
	elseif cmd == "trainer" or cmd == "vendor" or cmd == "flight" or cmd == "inn" then
		W.Nearby.Go(cmd)
	elseif cmd == "resume" then
		W.Nearby.Resume()
	elseif cmd == "party" or cmd == "group" then
		W.Group.Toggle(true)
	elseif cmd == "sync" then
		W.Group.SyncParty()
	elseif cmd == "guild" or cmd == "board" then
		W.Guild.Toggle(true)
	elseif cmd == "guildroute" then
		W.Guild.PickRoute()
	elseif cmd == "announce" then
		W.Guild.Announce(rest)
	elseif cmd == "orphans" or cmd == "cleanup" then
		W.Orphans.Toggle(true)
	elseif cmd == "talents" or cmd == "talent" then
		W.Talents.Toggle(true)
	elseif cmd == "tracker" or cmd == "xptracker" then
		W.Tracker.Toggle()
	elseif cmd == "layout" then
		local name = (rest or ""):lower()
		if W.StepFrame.PRESETS[name] then
			W.StepFrame.SetLayout(name)
			W.StepFrame.Toggle(true)
		else
			W.Print(L["Usage: /waypost layout simple | standard | detailed"])
		end
	elseif cmd == "xp" or cmd == "stats" then
		W.XP.ToggleWindow(true)
	elseif cmd == "editor" or cmd == "edit" or cmd == "import" or cmd == "export" then
		W.Editor.Open()
	elseif cmd == "record" or cmd == "rec" then
		local sub = (rest or ""):lower()
		if sub == "start" then W.Recorder.Start()
		elseif sub == "stop" then W.Recorder.Stop()
		else W.Print(W.Recorder.Active() and L["Recording. /waypost record stop to finish."] or L["Usage: /waypost record start | stop"]) end
	elseif cmd == "report" or cmd == "bug" then
		W.Report.Open(rest)
	elseif cmd == "reset" then
		W.StepFrame.ResetPosition()
		W.opt.arrow.pos, W.opt.buttons.pos = nil, nil
		W.Fire("WP_SETTINGS", "*")
		W.Print(L["Positions reset."])
	elseif cmd == "debug" then
		W.debug = not W.debug
		W.Print("debug " .. tostring(W.debug))
	elseif cmd == "version" then
		W.Print("v" .. W.version)
	elseif cmd == "mem" then
		if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
			UpdateAddOnMemoryUsage()
			local total = 0
			for _, name in ipairs({ "Waypost", "Waypost_Routes_Alliance", "Waypost_Routes_Horde", "Waypost_Routes_Extras" }) do
				total = total + (GetAddOnMemoryUsage(name) or 0)
			end
			W.Print(("memory: %.2f MB"):format(total / 1024))
		end
	else
		help()
	end
end

SLASH_WAYPOST1 = "/waypost"
SLASH_WAYPOST2 = "/wpost"
SLASH_WAYPOST3 = "/wayp"
SlashCmdList["WAYPOST"] = handle

-- /report, unless something else already owns it.
W.On("WP_LOGIN", function()
	if not (hash_SlashCmdList and hash_SlashCmdList["/REPORT"]) then
		SLASH_WAYPOSTREPORT1 = "/report"
	end
	SLASH_WAYPOSTREPORT2 = "/wpreport"
	SlashCmdList["WAYPOSTREPORT"] = function(msg) W.Report.Open(msg) end
end)
