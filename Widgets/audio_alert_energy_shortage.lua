function widget:GetInfo()
	return {
		name = "Audio Alert - Energy Shortage Warning",
		desc = "Plays a sound when energy usage exceeds income and reserves are <50 (after first 30s, on 60s cooldown)",
		author = "FrequentPilgrim",
		version = "1.2",
		date = "2025-06-11",
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
local cooldownFrames = 60 * 30        -- 60 seconds
local gracePeriodFrames = 30 * 30     -- 30 seconds
local lowEnergyThreshold = 50

function widget:Initialize()
	if GetSpectatingState() or IsReplay() then
		widgetHandler:RemoveWidget(self)
		return
	end
	myTeamID = GetMyTeamID()
end

function widget:GameFrame(f)
	if not myTeamID then return end
	if f % 10 ~= 0 then return end  -- check 3x per second
	if f < gracePeriodFrames then return end

	local current, storage, income, usage = GetTeamResources(myTeamID, "energy")

	if current and storage and income and usage then
		if usage > income and current < lowEnergyThreshold then
			if (f - lastSoundFrame) >= cooldownFrames then
				PlaySoundFile("LuaUI/Sounds/energyislow.ogg", 3.0, "ui")
				lastSoundFrame = f
			end
		end
	end
end
