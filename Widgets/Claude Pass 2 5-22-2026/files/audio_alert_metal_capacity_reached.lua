function widget:GetInfo()
  return {
    name    = "Metal Capacity Reached Audio Alert",
    desc    = "Plays an alert sound when your metal storage is full (after first 30s, on 60s cooldown).",
    author  = "FrequentPilgrim",
    date    = "2025-06-10",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableMetalExcessAlert", "metalExcessAlertSpec" }

options = {
  enableMetalExcessAlert = {
    name  = "Metal Capacity Reached",
    desc  = "Play an alert sound when your metal storage is at or above capacity.",
    type  = "bool",
    value = true,
  },
  metalExcessAlertSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableMetalExcessAlert = options.enableMetalExcessAlert.value,
    metalExcessAlertSpec   = options.metalExcessAlertSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableMetalExcessAlert ~= nil then options.enableMetalExcessAlert.value = data.enableMetalExcessAlert end
  if data.metalExcessAlertSpec   ~= nil then options.metalExcessAlertSpec.value   = data.metalExcessAlertSpec   end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_FILE        = "LuaUI/Sounds/metal_capacity_reached.ogg"
local SOUND_VOLUME      = 3.0
local COOLDOWN_FRAMES   = 60 * 30   -- 60 seconds
local GRACE_FRAMES      = 30 * 30   -- 30 seconds

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetTeamResources   = Spring.GetTeamResources
local PlaySoundFile      = Spring.PlaySoundFile
local GetMyTeamID        = Spring.GetMyTeamID
local GetSpectatingState = Spring.GetSpectatingState

local myTeamID       = nil
local lastSoundFrame = -math.huge

local function FeatureEnabled() return options.enableMetalExcessAlert.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.metalExcessAlertSpec.value
end

local function SafePlay(path, vol)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    WG.VoiceBus.play(path, { volume = vol, channel = "ui" })
  else
    PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

--------------------------------------------------------------------------------
-- Engine hooks
--------------------------------------------------------------------------------
function widget:Initialize()
  myTeamID = GetMyTeamID()
end

function widget:GameFrame(f)
  if not FeatureEnabled() then return end
  if not spec_ok() then return end
  if not myTeamID then return end
  if f % 30 ~= 0 then return end
  if f < GRACE_FRAMES then return end

  local current, storage = GetTeamResources(myTeamID, "metal")
  local adjustedStorage  = (storage or 0) - 10000

  if current and adjustedStorage and current > adjustedStorage then
    if (f - lastSoundFrame) >= COOLDOWN_FRAMES then
      SafePlay(SOUND_FILE, SOUND_VOLUME)
      lastSoundFrame = f
    end
  end
end
