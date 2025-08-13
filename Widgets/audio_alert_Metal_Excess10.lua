function widget:GetInfo()
	return {
		name = "Audio Alert - Metal Excess Warning",
		desc = "Plays a sound when metal is excessing (after first 30s, on 60s cooldown)",
		author = "FrequentPilgrim",
		version = "1.1",
		date = "2025-06-10",
		license = "GPL v2",
		layer = 0,
		enabled = true,
	}
end

local GetTeamResources = Spring.GetTeamResources
local PlaySoundFile = Spring.PlaySoundFile
local GetGameFrame = Spring.GetGameFrame
local GetMyTeamID = Spring.GetMyTeamID
local GetSpectatingState = Spring.GetSpectatingState
local IsReplay = Spring.IsReplay

local myTeamID
local lastSoundFrame = -999999
local cooldownFrames = 60 * 30
local gracePeriodFrames = 30 * 30

function widget:Initialize()
	if GetSpectatingState() or IsReplay() then
		widgetHandler:RemoveWidget(self)
		return
	end
	myTeamID = GetMyTeamID()
end

function widget:GameFrame(f)
	if not myTeamID then return end
	if f % 30 ~= 0 then return end
	if f < gracePeriodFrames then return end

	local current, storage = GetTeamResources(myTeamID, "metal")
	local adjustedStorage = (storage or 0) - 10000

	if current and adjustedStorage and current > adjustedStorage then
		if (f - lastSoundFrame) >= cooldownFrames then
			PlaySoundFile("LuaUI/Sounds/metalcapacityreached.ogg", 3.0, "ui")
			lastSoundFrame = f
		end
	end
end
