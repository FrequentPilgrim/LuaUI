function widget:GetInfo()
  return {
    name    = "Audio Alert - Victory and Defeat Sound",
    desc    = "Plays a sound on victory, defeat, or draw (not for spectators or replays)",
    author  = "FrequentPilgrim",
    date    = "2025-06-11",
    license = "GNU GPL v2",
    enabled = true,
    layer   = 0,
  }
end

local victorySound = "LuaUI/Sounds/congratulationscommander.ogg"
local defeatSound  = "LuaUI/Sounds/wehavebeenannihilated.ogg"
local drawSound    = "LuaUI/Sounds/itisadraw.ogg"

local played = false

function widget:GameOver(winningAllyTeams)
  if played then return end
  played = true

  -- Robust check: skip sound if player is currently a spectator or it's a replay
  local _, _, isSpec = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
  if isSpec or Spring.IsReplay() then return end

  -- Handle draw
  if not winningAllyTeams or #winningAllyTeams == 0 then
    Spring.PlaySoundFile(drawSound, 3.0, "ui")
    return
  end

  -- Check for victory
  local myAllyTeamID = Spring.GetMyAllyTeamID()
  for _, allyTeamID in ipairs(winningAllyTeams) do
    if allyTeamID == myAllyTeamID then
      Spring.PlaySoundFile(victorySound, 3.0, "ui")
      return
    end
  end

  -- Otherwise, defeat
  Spring.PlaySoundFile(defeatSound, 3.0, "ui")
end
