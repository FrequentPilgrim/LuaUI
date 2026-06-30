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
		license   = "MIT",
		layer     = 0,
		enabled   = true,
	}
end

--------------------------------------------------------------------------------
-- Epic Menu (Settings/Audio/Audio Alerts)
--------------------------------------------------------------------------------

options = {
	starting_beat = {
		name  = "Match Start Fanfare",
		desc  = "Play 'starting_beat.ogg' when the match begins.",
		type  = "bool",
		value = true,
		path  = "Settings/Audio/Audio Alerts",
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
	if options.starting_beat and options.starting_beat.value then
		fired = true
		spPlaySoundFile(FANFARE_PATH, FANFARE_VOLUME, "ui")
	end
end

--------------------------------------------------------------------------------
-- Config persistence
--------------------------------------------------------------------------------

function widget:GetConfigData()
	return {
		starting_beat = options.starting_beat and options.starting_beat.value or true,
	}
end

function widget:SetConfigData(data)
	if data.starting_beat ~= nil and options.starting_beat then
		options.starting_beat.value = (data.starting_beat == true)
	end
end
