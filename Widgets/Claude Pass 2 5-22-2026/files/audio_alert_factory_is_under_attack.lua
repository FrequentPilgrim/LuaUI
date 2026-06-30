function widget:GetInfo()
  return {
    name    = "Factory Under Attack Audio Alert",
    desc    = "Plays an alert sound when one of your factories takes damage.",
    author  = "FrequentPilgrim",
    date    = "2025-06-08",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableBaseUnderAttackAlert", "baseUnderAttackAlertSpec" }

options = {
  enableBaseUnderAttackAlert = {
    name  = "Factory Under Attack",
    desc  = "Play an alert sound when one of your factories takes damage.",
    type  = "bool",
    value = true,
  },
  baseUnderAttackAlertSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableBaseUnderAttackAlert = options.enableBaseUnderAttackAlert.value,
    baseUnderAttackAlertSpec   = options.baseUnderAttackAlertSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableBaseUnderAttackAlert ~= nil then options.enableBaseUnderAttackAlert.value = data.enableBaseUnderAttackAlert end
  if data.baseUnderAttackAlertSpec   ~= nil then options.baseUnderAttackAlertSpec.value   = data.baseUnderAttackAlertSpec   end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_FILE      = "LuaUI/Sounds/factory_is_under_attack.ogg"
local SOUND_VOLUME    = 3.0
local COOLDOWN_FRAMES = 600   -- 20 seconds

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetMyTeamID        = Spring.GetMyTeamID
local GetGameFrame       = Spring.GetGameFrame
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState

local myTeamID       = nil
local lastSoundFrame = -math.huge

local function FeatureEnabled() return options.enableBaseUnderAttackAlert.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.baseUnderAttackAlertSpec.value
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

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  if not FeatureEnabled() then return end
  if not spec_ok() then return end
  if unitTeam ~= myTeamID then return end

  local ud = UnitDefs[unitDefID]
  if not ud or not ud.isFactory then return end

  local f = GetGameFrame()
  if (f - lastSoundFrame) >= COOLDOWN_FRAMES then
    SafePlay(SOUND_FILE, SOUND_VOLUME)
    lastSoundFrame = f
  end
end
