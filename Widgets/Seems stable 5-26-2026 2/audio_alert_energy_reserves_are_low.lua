function widget:GetInfo()
	return {
		name = "Audio Alert - energy_reserves_are_low",
		desc = "Plays a sound when energy usage exceeds income and reserves are <50 (after first 30s, on 60s cooldown)",
		author = "FrequentPilgrim (+Epic Menu toggle patch)",
		version = "1.2",
		date = "2025-06-11",
		license = "MIT",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Epic Menu Toggle
--------------------------------------------------------------------------------
options = options or {}
options.energy_reserves_are_low = {
	name  = "Energy Reserves Are Low",
	desc  = "Play an alert when energy usage exceeds income and reserves are low.",
	type  = "bool",
	value = true,
	path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
	return {
		energy_reserves_are_low = options.energy_reserves_are_low
			and options.energy_reserves_are_low.value or true,
	}
end

function widget:SetConfigData(data)
	if data and data.energy_reserves_are_low ~= nil
	   and options and options.energy_reserves_are_low then
		options.energy_reserves_are_low.value = data.energy_reserves_are_low
	end
end

local function FeatureEnabled()
	return options and options.energy_reserves_are_low
	   and options.energy_reserves_are_low.value
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

local myTeamID
local lastSoundFrame     = -999999
local cooldownFrames     = 60 * 30        -- 60 seconds
local gracePeriodFrames  = 30 * 30        -- 30 seconds
local lowEnergyThreshold = 50
local criticalLowThreshold = 30   -- when energy is this low or lower, we become more sensitive (see below)

--------------------------------------------------------------------------------
-- Debug Mode (for widget developers)
--------------------------------------------------------------------------------
-- Set this to true to enable detailed console output about energy shortage
-- detection decisions (condition checks, cooldown state, critical low mode, etc.).
-- This is intended for future developers who want to test or improve the logic.
-- Normal users should leave this as false to avoid spam.
local debugMode = false
local soundPath          = "LuaUI/Sounds/energy_reserves_are_low.ogg"
local soundVolume        = 3.0

--------------------------------------------------------------------------------
-- Queue-aware playback (added): uses shared voice bus; falls back gracefully
--------------------------------------------------------------------------------
local function SafePlay(path, vol)
	if not path then return end
	if WG and WG.VoiceBus and WG.VoiceBus.play then
		-- Queue-only behavior: enqueues behind other alerts to avoid overlap.
		WG.VoiceBus.play(path, {
			volume  = vol,
			channel = "ui",  -- keep intended mixer routing
			-- key = "energy_reserves_are_low", cooldown = 0, priority = 0, -- optional dedupe if desired later
		})
	else
		-- Fallback to direct playback; explicitly route to UI channel to match intent.
		PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
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
		local isLow = current < lowEnergyThreshold
		local isCriticallyLow = current < criticalLowThreshold

		-- Normal case: require overconsumption + low energy
		-- When critically low, relax the "usage > income" requirement
		-- This helps catch cases where the reserve system + high priority units
		-- are causing builder starvation even if usage isn't strictly above income
		-- at the exact moment we check.
		local shouldAlert = isLow and (isCriticallyLow or usage > income)

		if shouldAlert then
			local timeSinceLast = f - lastSoundFrame
			local cooldownReady = timeSinceLast >= cooldownFrames

			if cooldownReady then
				SafePlay(soundPath, soundVolume)
				lastSoundFrame = f
				if debugMode then
					Spring.Echo(string.format("[EnergyLow] PLAYING | current=%.1f | usage=%.1f > income=%.1f | critLow=%s | cooldown passed (%d frames)", current, usage, income, tostring(isCriticallyLow), timeSinceLast))
				end
			else
				-- Debug: condition is true but cooldown is still blocking
				if debugMode then
					Spring.Echo(string.format("[EnergyLow] BLOCKED by cooldown | current=%.1f | %d frames since last play (need %d) | critLow=%s", current, timeSinceLast, cooldownFrames, tostring(isCriticallyLow)))
				end
			end
		end
	end
end
