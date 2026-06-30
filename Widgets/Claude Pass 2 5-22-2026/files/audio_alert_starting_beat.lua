--------------------------------------------------------------------------------
-- Match Start Fanfare
-- Plays LuaUI/Sounds/starting_beat.ogg exactly at GameStart.
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name    = "Match Start Fanfare Audio Alert",
    desc    = "Plays a fanfare sound once when the match begins.",
    author  = "FrequentPilgrim",
    date    = "2025-08-18",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableStartFanfare", "startFanfareSpec" }

options = {
  enableStartFanfare = {
    name  = "Match Start Fanfare",
    desc  = "Play an alert sound when the match begins.",
    type  = "bool",
    value = true,
  },
  startFanfareSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableStartFanfare = options.enableStartFanfare.value,
    startFanfareSpec   = options.startFanfareSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableStartFanfare ~= nil then options.enableStartFanfare.value = (data.enableStartFanfare == true) end
  if data.startFanfareSpec   ~= nil then options.startFanfareSpec.value   = (data.startFanfareSpec   == true) end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_FILE   = "LuaUI/Sounds/starting_beat.ogg"
local SOUND_VOLUME = 1.0

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState

local fired = false

local function FeatureEnabled() return options.enableStartFanfare.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.startFanfareSpec.value
end

--------------------------------------------------------------------------------
-- Engine hooks
--------------------------------------------------------------------------------
function widget:GameStart()
  if fired then return end
  if not FeatureEnabled() then return end
  if not spec_ok() then return end
  fired = true
  PlaySoundFile(SOUND_FILE, SOUND_VOLUME, "ui")
end
