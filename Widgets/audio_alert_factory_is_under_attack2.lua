function widget:GetInfo()
  return {
    name    = "Audio Alert - factory_is_under_attack",
    desc    = "Alert sound when your factory is attacked",
    author  = "FrequentPilgrim",
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
options.enableBaseUnderAttackAlert = {
  name  = "Base Under Attack Alert",
  desc  = "Play an alert sound when your factory is attacked.",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

-- Persist the checkbox across reloads/sessions (preserved)
function widget:GetConfigData()
  return {
    enableBaseUnderAttackAlert = options.enableBaseUnderAttackAlert
      and options.enableBaseUnderAttackAlert.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.enableBaseUnderAttackAlert ~= nil
     and options and options.enableBaseUnderAttackAlert then
    options.enableBaseUnderAttackAlert.value = data.enableBaseUnderAttackAlert
  end
end

local function FeatureEnabled()
  return options and options.enableBaseUnderAttackAlert
     and options.enableBaseUnderAttackAlert.value
end

--------------------------------------------------------------------------------
-- Configuration (preserved)
--------------------------------------------------------------------------------
local soundFile      = "LuaUI/Sounds/factory_is_under_attack.ogg"
local soundVolume    = 3.0
local cooldownFrames = 600 -- 20 seconds at 30 FPS
local lastPlayed     = -math.huge

local myTeamID       = Spring.GetMyTeamID()

--------------------------------------------------------------------------------
-- Queue-aware playback (added): uses shared voice bus; falls back gracefully
--------------------------------------------------------------------------------
local function SafePlay(path, vol)
  if not path then return end
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    -- Queue-only behavior: enqueues behind other alerts to avoid overlap.
    WG.VoiceBus.play(path, {
      volume  = vol,
      channel = "ui",  -- keep intended mixer routing
      -- key = "factory_under_attack", cooldown = 0, priority = 0, -- optional dedupe if desired later
    })
  else
    -- Fallback to direct playback; explicitly route to UI channel to match intent.
    Spring.PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

--------------------------------------------------------------------------------
-- UnitDamaged Hook (original logic preserved; routing swapped to SafePlay)
--------------------------------------------------------------------------------
function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  if not FeatureEnabled() then return end
  if unitTeam ~= myTeamID then return end

  local ud = UnitDefs[unitDefID]
  if not ud or not ud.isFactory then return end

  local f = Spring.GetGameFrame()
  if lastPlayed + cooldownFrames <= f then
    -- WAS: Spring.PlaySoundFile(soundFile, soundVolume, "ui")
    -- NOW: enqueue via shared voice bus so it never overlaps
    SafePlay(soundFile, soundVolume)
    lastPlayed = f
  end
end
