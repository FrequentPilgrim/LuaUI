function widget:GetInfo()
	return {
		name = "metal_capacity_reached Audio Alert",
		desc = "Plays a sound when metal is excessing (after first 30s, on 60s cooldown)",
		author = "FrequentPilgrim",
		version = "1.2",
		date = "2025-06-10",
		license = "GPL v2",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Epic Menu Toggle (preserved; no new knobs)
--------------------------------------------------------------------------------
options = options or {}
options.enableMetalExcessAlert = {
	name  = "Metal Excess Alert",
	desc  = "Play an alert when your metal is near/full capacity.",
	type  = "bool",
	value = true,
	path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
	return {
		enableMetalExcessAlert = options.enableMetalExcessAlert
			and options.enableMetalExcessAlert.value or true,
	}
end

function widget:SetConfigData(data)
	if data and data.enableMetalExcessAlert ~= nil
	   and options and options.enableMetalExcessAlert then
		options.enableMetalExcessAlert.value = data.enableMetalExcessAlert
	end
end

local function FeatureEnabled()
	return options and options.enableMetalExcessAlert
	   and options.enableMetalExcessAlert.value
end

--------------------------------------------------------------------------------
-- Original code (behavior preserved; routing now uses queue)
--------------------------------------------------------------------------------
local GetTeamResources     = Spring.GetTeamResources
local PlaySoundFile        = Spring.PlaySoundFile
local GetGameFrame         = Spring.GetGameFrame
local GetMyTeamID          = Spring.GetMyTeamID
local GetSpectatingState   = Spring.GetSpectatingState
local IsReplay             = Spring.IsReplay

local myTeamID
local lastSoundFrame     = -999999
local cooldownFrames     = 60 * 30
local gracePeriodFrames  = 30 * 30

local soundPath          = "LuaUI/Sounds/metal_capacity_reached.ogg"
local soundVolume        = 3.0

--------------------------------------------------------------------------------
-- Queue-aware playback (added): use shared voice bus; graceful fallback
--------------------------------------------------------------------------------
local function SafePlay(path, vol)
	if WG and WG.VoiceBus and WG.VoiceBus.play then
		-- Queue-only behavior: enqueues behind other alerts to avoid overlap.
		WG.VoiceBus.play(path, {
			volume  = vol,
			channel = "ui",  -- keep intended mixer routing
			-- key = "metal_capacity_reached", cooldown = 0, priority = 0, -- optional dedupe later if desired
		})
	else
		-- Fallback to direct playback; explicitly route to UI channel to match intent.
		PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
	end
end

function widget:Initialize()
	if GetSpectatingState() or IsReplay() then
		widgetHandler:RemoveWidget(self)
		return
	end
	myTeamID = GetMyTeamID()
end

function widget:GameFrame(f)
	if not FeatureEnabled() then return end
	if not myTeamID then return end
	if f % 30 ~= 0 then return end
	if f < gracePeriodFrames then return end

	local current, storage = GetTeamResources(myTeamID, "metal")
	local adjustedStorage = (storage or 0) - 10000

	if current and adjustedStorage and current > adjustedStorage then
		if (f - lastSoundFrame) >= cooldownFrames then
			-- WAS: PlaySoundFile("LuaUI/Sounds/metal_capacity_reached.ogg", 3.0, "ui")
			-- NOW: enqueue via shared voice bus so it never overlaps
			SafePlay(soundPath, soundVolume)
			lastSoundFrame = f
		end
	end
end
