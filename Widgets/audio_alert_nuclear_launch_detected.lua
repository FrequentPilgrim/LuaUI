function widget:GetInfo()
  return {
    name    = "Nuclear Launch Detected Audio Alert",
    desc    = "Plays an alert sound when a nuclear missile is launched.",
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
options = options or {}
options.nuclear_launch_detected = {
  name  = "Nuclear Launch Detected",
  desc  = "Play an alert when a nuclear missile launch is detected.",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
  return {
    nuclear_launch_detected = options.nuclear_launch_detected
      and options.nuclear_launch_detected.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.nuclear_launch_detected ~= nil
     and options and options.nuclear_launch_detected then
    options.nuclear_launch_detected.value = data.nuclear_launch_detected
  end
end

local function FeatureEnabled()
  return options and options.nuclear_launch_detected
     and options.nuclear_launch_detected.value
end

-- Gating (easy one-line reversal; default = do not play in these modes)
local RUN_IN_REPLAY    = true
local RUN_IN_SPECTATOR = true
local RUN_IN_CAMPAIGN  = true

local function play_ok()
  if Spring.IsReplay() and not RUN_IN_REPLAY then return false end
  if Spring.GetSpectatingState() and not RUN_IN_SPECTATOR then return false end
  local mo = Spring.GetModOptions() or {}
  if mo.singleplayercampaignbattleid and not RUN_IN_CAMPAIGN then return false end
  return true
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local nukeSoundFile  = "LuaUI/Sounds/nuclear_launch_detected.ogg"
local soundVolume    = 3.0
local lastPlayed     = -math.huge
local cooldownFrames = 210   -- 7 seconds at 30 FPS

--------------------------------------------------------------------------------
-- Queue-aware playback
--------------------------------------------------------------------------------
local function SafePlay(path, vol)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    WG.VoiceBus.play(path, {
      volume  = vol,
      channel = "ui",
    })
  else
    Spring.PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

--------------------------------------------------------------------------------
-- GameFrame hook
-- FIX: throttled to every 15 frames (~2× per second) instead of every frame.
-- The recentNukeLaunch param is set for several seconds after launch so
-- no events will be missed.
--------------------------------------------------------------------------------
function widget:GameFrame(f)
  if not FeatureEnabled() then return end
  if f % 15 ~= 0 then return end

  local launch = Spring.GetGameRulesParam("recentNukeLaunch")
  if launch == 1 then
    if not play_ok() then return end
    if lastPlayed + cooldownFrames <= f then
      SafePlay(nukeSoundFile, soundVolume)
      lastPlayed = f
    end
  end
end
