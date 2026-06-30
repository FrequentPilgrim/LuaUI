function widget:GetInfo()
	return {
		name = "metal_capacity_reached Audio Alert",
		desc = "Plays a sound when metal is excessing (after first 30s, on 60s cooldown)",
		author = "FrequentPilgrim",
		version = "1.2",
		date = "2025-06-10",
		license = "MIT",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Epic Menu Toggle
--------------------------------------------------------------------------------
options = options or {}
options.metal_capacity_reached = {
	name  = "Metal Capacity Reached",
	desc  = "Play an alert when your metal is near/full capacity.",
	type  = "bool",
	value = true,
	path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
	return {
		metal_capacity_reached = options.metal_capacity_reached
			and options.metal_capacity_reached.value or true,
	}
end

function widget:SetConfigData(data)
	if data and data.metal_capacity_reached ~= nil
	   and options and options.metal_capacity_reached then
		options.metal_capacity_reached.value = data.metal_capacity_reached
	end
end

local function FeatureEnabled()
	return options and options.metal_capacity_reached
	   and options.metal_capacity_reached.value
end

-- Gating (easy one-line reversal; default = do not play in these modes)
local RUN_IN_REPLAY    = false
local RUN_IN_SPECTATOR = false
local RUN_IN_CAMPAIGN  = true

local function play_ok()
  if Spring.IsReplay() and not RUN_IN_REPLAY then return false end
  if Spring.GetSpectatingState() and not RUN_IN_SPECTATOR then return false end
  local mo = Spring.GetModOptions() or {}
  if mo.singleplayercampaignbattleid and not RUN_IN_CAMPAIGN then return false end
  return true
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
			if not play_ok() then return end
			-- WAS: PlaySoundFile("LuaUI/Sounds/metal_capacity_reached.ogg", 3.0, "ui")
			-- NOW: enqueue via shared voice bus so it never overlaps
			SafePlay(soundPath, soundVolume)
			lastSoundFrame = f
		end
	end
end
