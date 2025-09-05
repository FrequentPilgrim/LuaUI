--------------------------------------------------------------------------------
-- Start Fanfare
-- Plays LuaUI/Sounds/starting_beat.ogg exactly at GameStart.
--------------------------------------------------------------------------------

local version = "1.001"

function widget:GetInfo()
	return {
		name      = "starting_beat Audio Alert",
		desc      = "Plays a fanfare once at GameStart.",
		author    = "FrequentPilgrim",
		date      = "2025-08-18",
		license   = "GNU GPL v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Epic Menu (Settings/Audio/Audio Alerts)
--------------------------------------------------------------------------------

options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableStartFanfare" }

options = {
	enableStartFanfare = {
		name  = "Match Start Fanfare",
		desc  = "Play 'starting_beat.ogg' when the match begins (GameStart).",
		type  = "bool",
		value = true,
	},
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------

local spPlaySoundFile = Spring.PlaySoundFile

local FANFARE_PATH   = "LuaUI/Sounds/starting_beat.ogg"
local FANFARE_VOLUME = 1.0  -- Adjust if desired
local fired          = false

--------------------------------------------------------------------------------
-- Core
--------------------------------------------------------------------------------

-- Called once when the actual game begins (after pregame countdown).
function widget:GameStart()
	if fired then return end
	if options.enableStartFanfare and options.enableStartFanfare.value then
		fired = true
		spPlaySoundFile(FANFARE_PATH, FANFARE_VOLUME, "ui")
	end
end

--------------------------------------------------------------------------------
-- Config persistence
--------------------------------------------------------------------------------

function widget:GetConfigData()
	return {
		enableStartFanfare = options.enableStartFanfare and options.enableStartFanfare.value or true,
	}
end

function widget:SetConfigData(data)
	if data.enableStartFanfare ~= nil and options.enableStartFanfare then
		options.enableStartFanfare.value = (data.enableStartFanfare == true)
	end
end
