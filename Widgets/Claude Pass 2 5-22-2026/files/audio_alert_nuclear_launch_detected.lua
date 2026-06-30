function widget:GetInfo()
  return {
    name    = "Nuclear Launch Detected Audio Alert",
    desc    = "Plays an alert sound when a nuclear missile launch is detected.",
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
options_order = { "enableNukeLaunchAlert", "nukeLaunchAlertSpec" }

options = {
  enableNukeLaunchAlert = {
    name  = "Nuclear Launch Detected",
    desc  = "Play an alert sound when a nuclear missile launch is detected.",
    type  = "bool",
    value = true,
  },
  nukeLaunchAlertSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableNukeLaunchAlert = options.enableNukeLaunchAlert.value,
    nukeLaunchAlertSpec   = options.nukeLaunchAlertSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableNukeLaunchAlert ~= nil then options.enableNukeLaunchAlert.value = data.enableNukeLaunchAlert end
  if data.nukeLaunchAlertSpec   ~= nil then options.nukeLaunchAlertSpec.value   = data.nukeLaunchAlertSpec   end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_FILE      = "LuaUI/Sounds/nuclear_launch_detected.ogg"
local SOUND_VOLUME    = 3.0
local COOLDOWN_FRAMES = 210   -- 7 seconds

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetGameRulesParam  = Spring.GetGameRulesParam
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState

local lastSoundFrame = -math.huge

local function FeatureEnabled() return options.enableNukeLaunchAlert.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.nukeLaunchAlertSpec.value
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
-- Throttled to every 15 frames (~2× per second); recentNukeLaunch persists
-- for several seconds after launch so no events will be missed.
--------------------------------------------------------------------------------
function widget:GameFrame(f)
  if not FeatureEnabled() then return end
  if not spec_ok() then return end
  if f % 15 ~= 0 then return end

  if GetGameRulesParam("recentNukeLaunch") == 1 then
    if (f - lastSoundFrame) >= COOLDOWN_FRAMES then
      SafePlay(SOUND_FILE, SOUND_VOLUME)
      lastSoundFrame = f
    end
  end
end
