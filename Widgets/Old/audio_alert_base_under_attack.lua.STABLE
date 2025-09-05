function widget:GetInfo()
  return {
    name    = "Audio Alert - Base Under Attack Sound",
    desc    = "Plays a StarCraft-style alert sound when your factory is attacked",
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

local soundFile = "LuaUI/Sounds/baseisunderattack.ogg"
local soundVolume = 3.0
local cooldownFrames = 600 -- 20 seconds at 30 FPS
local lastPlayed = -math.huge

local myTeamID = Spring.GetMyTeamID()

--------------------------------------------------------------------------------
-- UnitDamaged Hook
--------------------------------------------------------------------------------

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  if unitTeam ~= myTeamID then return end

  local ud = UnitDefs[unitDefID]
  if not ud or not ud.isFactory then return end

  local f = Spring.GetGameFrame()
  if lastPlayed + cooldownFrames <= f then
    Spring.PlaySoundFile(soundFile, soundVolume, "ui")
    lastPlayed = f
  end
end
