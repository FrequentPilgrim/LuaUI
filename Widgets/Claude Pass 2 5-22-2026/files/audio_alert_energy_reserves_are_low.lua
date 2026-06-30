function widget:GetInfo()
  return {
    name    = "Energy Reserves Low Audio Alert",
    desc    = "Plays an alert sound when energy usage exceeds income and reserves are below 50 (after first 30s, on 60s cooldown).",
    author  = "FrequentPilgrim",
    date    = "2025-06-11",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableEnergyShortageAlert", "energyShortageAlertSpec" }

options = {
  enableEnergyShortageAlert = {
    name  = "Energy Reserves Low",
    desc  = "Play an alert sound when energy usage exceeds income and reserves are critically low.",
    type  = "bool",
    value = true,
  },
  energyShortageAlertSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableEnergyShortageAlert = options.enableEnergyShortageAlert.value,
    energyShortageAlertSpec   = options.energyShortageAlertSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableEnergyShortageAlert ~= nil then options.enableEnergyShortageAlert.value = data.enableEnergyShortageAlert end
  if data.energyShortageAlertSpec   ~= nil then options.energyShortageAlertSpec.value   = data.energyShortageAlertSpec   end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_FILE          = "LuaUI/Sounds/energyislow.ogg"
local SOUND_VOLUME        = 3.0
local COOLDOWN_FRAMES     = 60 * 30   -- 60 seconds
local GRACE_FRAMES        = 30 * 30   -- 30 seconds
local LOW_ENERGY_THRESHOLD = 50

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetTeamResources   = Spring.GetTeamResources
local PlaySoundFile      = Spring.PlaySoundFile
local GetMyTeamID        = Spring.GetMyTeamID
local GetSpectatingState = Spring.GetSpectatingState
local VFSFileExists      = VFS.FileExists

local myTeamID       = nil
local lastSoundFrame = -math.huge

local function FeatureEnabled() return options.enableEnergyShortageAlert.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.energyShortageAlertSpec.value
end

local function SafePlay(path, vol)
  if not path or not VFSFileExists(path) then return end
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
  if f % 10 ~= 0 then return end   -- check 3× per second
  if f < GRACE_FRAMES then return end

  local current, storage, income, usage = GetTeamResources(myTeamID, "energy")
  if current and storage and income and usage then
    if usage > income and current < LOW_ENERGY_THRESHOLD then
      if (f - lastSoundFrame) >= COOLDOWN_FRAMES then
        SafePlay(SOUND_FILE, SOUND_VOLUME)
        lastSoundFrame = f
      end
    end
  end
end
