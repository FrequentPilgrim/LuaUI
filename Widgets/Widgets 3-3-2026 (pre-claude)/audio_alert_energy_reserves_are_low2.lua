function widget:GetInfo()
	return {
		name = "Audio Alert - Energy Shortage Warning",
		desc = "Plays a sound when energy usage exceeds income and reserves are <50 (after first 30s, on 60s cooldown)",
		author = "FrequentPilgrim (+Epic Menu toggle patch)",
		version = "1.2",
		date = "2025-06-11",
		license = "GPL v2",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Epic Menu Toggle (preserved; no new knobs)
--------------------------------------------------------------------------------
options = options or {}
options.enableEnergyShortageAlert = {
	name  = "Energy Shortage Alert",
	desc  = "Play an alert when energy usage exceeds income and reserves are low.",
	type  = "bool",
	value = true,
	path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
	return {
		enableEnergyShortageAlert = options.enableEnergyShortageAlert
			and options.enableEnergyShortageAlert.value or true,
	}
end

function widget:SetConfigData(data)
	if data and data.enableEnergyShortageAlert ~= nil
	   and options and options.enableEnergyShortageAlert then
		options.enableEnergyShortageAlert.value = data.enableEnergyShortageAlert
	end
end

local function FeatureEnabled()
	return options and options.enableEnergyShortageAlert
	   and options.enableEnergyShortageAlert.value
end

--------------------------------------------------------------------------------
-- Original config (preserved)
--------------------------------------------------------------------------------
local GetTeamResources     = Spring.GetTeamResources
local PlaySoundFile        = Spring.PlaySoundFile
local GetGameFrame         = Spring.GetGameFrame
local GetMyTeamID          = Spring.GetMyTeamID
local GetSpectatingState   = Spring.GetSpectatingState
local IsReplay             = Spring.IsReplay
local VFSFileExists        = VFS.FileExists

local myTeamID
local lastSoundFrame     = -999999
local cooldownFrames     = 60 * 30        -- 60 seconds
local gracePeriodFrames  = 30 * 30        -- 30 seconds
local lowEnergyThreshold = 50
local soundPath          = "LuaUI/Sounds/energyislow.ogg"
local soundVolume        = 3.0

--------------------------------------------------------------------------------
-- Safe, queue-aware playback (added)
--------------------------------------------------------------------------------
local function SafePlay(path, vol)
	if not path or not VFSFileExists(path) then return end
	if WG and WG.VoiceBus and WG.VoiceBus.play then
		-- Queue-only behavior: will enqueue behind other alerts, avoiding overlap.
		WG.VoiceBus.play(path, {
			volume  = vol,
			channel = "ui",  -- keep intended routing consistent
			-- key = "energy_shortage", cooldown = 0, priority = 0, -- optional dedupe if desired later
		})
	else
		-- Graceful fallback if the bus isn't loaded for some reason.
		PlaySoundFile(path, vol)
		-- (If you prefer explicit channel on fallback, use:
		--  PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui"))
	end
end

--------------------------------------------------------------------------------
-- Init & main logic (unchanged behavior apart from routing through the queue)
--------------------------------------------------------------------------------
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
	if f % 10 ~= 0 then return end  -- check 3x per second
	if f < gracePeriodFrames then return end

	local current, storage, income, usage = GetTeamResources(myTeamID, "energy")
	if current and storage and income and usage then
		if usage > income and current < lowEnergyThreshold then
			if (f - lastSoundFrame) >= cooldownFrames then
				-- WAS: PlaySoundFile("LuaUI/Sounds/energyislow.ogg", 3.0, "ui")
				-- NOW: enqueue via shared voice bus so it never overlaps
				SafePlay(soundPath, soundVolume)
				lastSoundFrame = f
			end
		end
	end
end
