function widget:GetInfo()
  return {
    name    = "nuclear_launch_detected Audio Alert",
    desc    = "Plays a Starcraft-style alert sound when a nuclear missile is launched",
    author  = "FrequentPilgrim (+Epic Menu toggle patch)",
    date    = "2025-06-08",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu Toggle (preserved; no new knobs)
--------------------------------------------------------------------------------
options = options or {}
options.enableNukeLaunchAlert = {
  name  = "Nuclear Launch Alert",
  desc  = "Play an alert when a nuclear missile launch is detected.",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
  return {
    enableNukeLaunchAlert = options.enableNukeLaunchAlert
      and options.enableNukeLaunchAlert.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.enableNukeLaunchAlert ~= nil
     and options and options.enableNukeLaunchAlert then
    options.enableNukeLaunchAlert.value = data.enableNukeLaunchAlert
  end
end

local function FeatureEnabled()
  return options and options.enableNukeLaunchAlert
     and options.enableNukeLaunchAlert.value
end

--------------------------------------------------------------------------------
-- Original Configuration (preserved)
--------------------------------------------------------------------------------
local nukeSoundFile  = "LuaUI/Sounds/nuclear_launch_detected.ogg"
local soundVolume    = 3.0
local lastPlayed     = -math.huge     -- store last play time in frames
local cooldownFrames = 210            -- 7 seconds at 30 FPS

--------------------------------------------------------------------------------
-- Queue-aware playback (added): use shared voice bus; graceful fallback
--------------------------------------------------------------------------------
local function SafePlay(path, vol)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    -- Queue-only behavior: enqueues behind other alerts to avoid overlap.
    WG.VoiceBus.play(path, {
      volume  = vol,
      channel = "ui",  -- keep intended mixer routing
      -- key = "nuke_launch", cooldown = 0, priority = 0, -- optional dedupe if desired later
    })
  else
    -- Fallback to direct playback; explicitly route to UI channel to match intent.
    Spring.PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

--------------------------------------------------------------------------------
-- GameFrame hook: checks if nuke was launched (behavior preserved)
--------------------------------------------------------------------------------
function widget:GameFrame(f)
  if not FeatureEnabled() then return end  -- Epic Menu gate

  local launch = Spring.GetGameRulesParam("recentNukeLaunch")
  if launch == 1 then
    if lastPlayed + cooldownFrames <= f then
      -- WAS: Spring.PlaySoundFile(nukeSoundFile, soundVolume, "ui")
      -- NOW: enqueue via shared voice bus so it never overlaps
      SafePlay(nukeSoundFile, soundVolume)
      lastPlayed = f
    end
  end
end
