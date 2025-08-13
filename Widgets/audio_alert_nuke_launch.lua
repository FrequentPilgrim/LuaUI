function widget:GetInfo()
  return {
    name    = "Audio Alert - Nuke Launch Sound",
    desc    = "Plays a Starcraft-style alert sound when a nuclear missile is launched",
    author  = "FrequentPilgrim",
    date    = "2025-06-08",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local nukeSoundFile = "LuaUI/Sounds/nuclearlaunchdetected.ogg"
local soundVolume = 3.0
local lastPlayed = -math.huge     -- store last play time in frames
local cooldownFrames = 210        -- 7 seconds at 30 FPS

--------------------------------------------------------------------------------
-- GameFrame hook: checks if nuke was launched
--------------------------------------------------------------------------------

function widget:GameFrame(f)
  local launch = Spring.GetGameRulesParam("recentNukeLaunch")
  if launch == 1 then
    if lastPlayed + cooldownFrames <= f then
      Spring.PlaySoundFile(nukeSoundFile, soundVolume, "ui")
      lastPlayed = f
    end
  end
end
