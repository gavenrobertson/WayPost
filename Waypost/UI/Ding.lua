-- The level-up moment, inside the guide window.
--
-- A gold flash washes over the window, a banner drops in with the new level
-- over spinning rays, a glint sweeps across it, and a line under it says how
-- long the last level took. About three seconds, all done with the client's
-- animation groups (nothing runs per frame in Lua). /waypost ding previews it.

local W = Waypost
local L = W.L
local UI = W.UI
local Col = UI.C
local D = {}
W.Ding = D

local overlay, flash, banner, rays, glow, glint, text, sub
local groups = {}

local function alpha(group, from, to, duration, order, delay)
	local a = group:CreateAnimation("Alpha")
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetDuration(duration)
	a:SetOrder(order or 1)
	if delay then a:SetStartDelay(delay) end
	return a
end

local function build()
	local host = W.StepFrame.frame
	overlay = CreateFrame("Frame", "WaypostDing", host)
	overlay:SetAllPoints(host)
	overlay:SetFrameLevel((host:GetFrameLevel() or 1) + 30)
	overlay:Hide()

	-- 1. the flash over the whole window
	flash = overlay:CreateTexture(nil, "OVERLAY")
	flash:SetTexture(UI.WHITE)
	flash:SetAllPoints()
	flash:SetBlendMode("ADD")
	flash:SetVertexColor(1, 0.78, 0.25)
	flash:SetAlpha(0)
	groups.flash = flash:CreateAnimationGroup()
	alpha(groups.flash, 0, 0.5, 0.12, 1)
	alpha(groups.flash, 0.5, 0, 0.7, 2)
	groups.flash:SetToFinalAlpha(true)

	-- 2. the banner
	banner = CreateFrame("Frame", nil, overlay)
	banner:SetPoint("TOPLEFT", 1, -1)
	banner:SetPoint("TOPRIGHT", -1, -1)
	banner:SetHeight(66)
	banner:SetClipsChildren(true)
	UI.Fill(banner, Col.well, 0.96)
	for _, edge in ipairs({ "TOP", "BOTTOM" }) do
		local line = banner:CreateTexture(nil, "ARTWORK")
		line:SetTexture(UI.WHITE)
		line:SetHeight(1)
		line:SetPoint(edge .. "LEFT")
		line:SetPoint(edge .. "RIGHT")
		line:SetVertexColor(Col.gold[1], Col.gold[2], Col.gold[3], 0.9)
	end

	rays = banner:CreateTexture(nil, "BORDER")
	rays:SetTexture(UI.MEDIA .. "Burst")
	rays:SetBlendMode("ADD")
	rays:SetVertexColor(1, 0.72, 0.2, 0.55)
	rays:SetSize(260, 260)
	rays:SetPoint("CENTER", 0, 4)
	groups.rays = rays:CreateAnimationGroup()
	local spin = groups.rays:CreateAnimation("Rotation")
	spin:SetDegrees(-360)
	spin:SetDuration(14)
	groups.rays:SetLooping("REPEAT")

	glow = banner:CreateTexture(nil, "BORDER", nil, 1)
	glow:SetTexture(UI.MEDIA .. "Glow")
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(1, 0.8, 0.3, 0.7)
	glow:SetSize(300, 90)
	glow:SetPoint("CENTER", 0, 6)

	text = banner:CreateFontString(nil, "OVERLAY", "WaypostFontDing")
	text:SetPoint("CENTER", 0, 9)
	sub = banner:CreateFontString(nil, "OVERLAY", "WaypostFontSmall")
	sub:SetPoint("TOP", text, "BOTTOM", 0, -3)
	sub:SetTextColor(Col.text[1], Col.text[2], Col.text[3])

	-- the glint that sweeps across
	glint = banner:CreateTexture(nil, "OVERLAY")
	glint:SetTexture(UI.MEDIA .. "Glow")
	glint:SetBlendMode("ADD")
	glint:SetVertexColor(1, 0.95, 0.7, 0.8)
	glint:SetSize(70, 150)
	glint:SetPoint("LEFT", -70, 0)
	glint:SetAlpha(0)
	groups.glint = glint:CreateAnimationGroup()
	local move = groups.glint:CreateAnimation("Translation")
	move:SetOffset(520, 0)
	move:SetDuration(0.75)
	move:SetStartDelay(0.25)
	move:SetSmoothing("IN_OUT")
	alpha(groups.glint, 0, 1, 0.15, 1, 0.25)
	alpha(groups.glint, 1, 0, 0.25, 1, 0.75)

	-- banner: pop in, hold, fade
	groups.banner = banner:CreateAnimationGroup()
	alpha(groups.banner, 0, 1, 0.18, 1)
	local pop = groups.banner:CreateAnimation("Scale")
	if pop.SetScaleFrom then
		pop:SetScaleFrom(1.35, 1.35)
		pop:SetScaleTo(1, 1)
	elseif pop.SetFromScale then
		pop:SetFromScale(1.35, 1.35)
		pop:SetToScale(1, 1)
	end
	pop:SetOrigin("CENTER", 0, 0)
	pop:SetDuration(0.28)
	pop:SetSmoothing("OUT")
	pop:SetOrder(1)
	alpha(groups.banner, 1, 1, 2.3, 2)
	alpha(groups.banner, 1, 0, 0.6, 3)
	groups.banner:SetToFinalAlpha(true)
	groups.banner:SetScript("OnFinished", function()
		groups.rays:Stop()
		overlay:Hide()
	end)
end

function D.Play(level, detail)
	if not W.opt.ui.ding then return false end
	local host = W.StepFrame.frame
	if not host or not host:IsShown() then return false end
	if not overlay then build() end
	for _, g in pairs(groups) do g:Stop() end
	text:SetText((L["Level %d"]):format(level))
	sub:SetText(detail or "")
	overlay:Show()
	groups.flash:Play()
	groups.rays:Play()
	groups.glint:Play()
	groups.banner:Play()
	return true
end

W.On("WP_LEVEL", function(level)
	-- a moment later, so the level timer has been closed off
	W.After(0.2, function()
		local secs = W.char.xp and W.char.xp.levels and W.char.xp.levels[level - 1]
		local detail
		if secs and secs > 0 then
			detail = (L["Level %d took %s"]):format(level - 1, W.FormatTime(secs))
		end
		D.Play(level, detail)
	end)
end)
