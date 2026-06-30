function widget:GetInfo()
  return {
    name    = "Victory, Defeat and Draw Audio Alert",
    desc    = "Plays a single clean outcome line after match end, across all scenarios.",
    author  = "FrequentPilgrim",
    date    = "2025-09-18",
    license = "MIT",
    enabled = true,
    layer   = 0,
  }
end

local debugMode = false   -- set true for console messages

----------------------------------------
-- Epic Menu
----------------------------------------
options = options or {}
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableAlerts" }

options.enableAlerts = {
  name  = "Victory/Defeat/Draw Alerts",
  desc  = "Play end-of-match sounds (victory/defeat/draw).",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
  return {
    enableAlerts = options.enableAlerts and options.enableAlerts.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.enableAlerts ~= nil and options and options.enableAlerts then
    options.enableAlerts.value = data.enableAlerts
  end
end

----------------------------------------
-- Config
----------------------------------------
local victorySound = "LuaUI/Sounds/congratulations_commander.ogg"
local defeatSound  = "LuaUI/Sounds/we_have_been_annihilated.ogg"
local drawSound    = "LuaUI/Sounds/it_is_a_draw.ogg"
local volume       = 3.0

----------------------------------------
-- State
----------------------------------------
local played        = false
local wasEverPlayer = false

local function updateEverPlayer()
  local myID = Spring.GetMyPlayerID()
  if myID then
    local _, _, isSpec = Spring.GetPlayerInfo(myID)
    if not isSpec then wasEverPlayer = true end
  end
end

----------------------------------------
-- Helpers
----------------------------------------
local function LockOutAllFutureAlerts()
  if WG and WG.VoiceBus then
    if not WG.VoiceBus._locked then
      WG.VoiceBus._locked   = true
      WG.VoiceBus._origPlay = WG.VoiceBus.play
      WG.VoiceBus.play      = function() return false end
    end
  end
end

local function EnqueueFinalOutcome(path, label)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    if WG.VoiceBus.clear then WG.VoiceBus.clear() end
    WG.VoiceBus.play(path, { volume = volume, channel = "ui", priority = 999999 })
    LockOutAllFutureAlerts()
    if debugMode then
      Spring.Echo("game_message: " .. label .. " (final outcome queued)")
    end
  else
    Spring.PlaySoundFile(path, volume, nil, nil, nil, nil, nil, nil, "ui")
    if debugMode then
      Spring.Echo("game_message: " .. label .. " (final outcome direct)")
    end
  end
end

----------------------------------------
-- Engine Hooks
----------------------------------------
function widget:Initialize()
  updateEverPlayer()
end

function widget:PlayerChanged(playerID)
  if playerID == Spring.GetMyPlayerID() then
    updateEverPlayer()
  end
end

function widget:GameOver(winningAllyTeams)
  if played then return end
  played = true

  if not (options and options.enableAlerts and options.enableAlerts.value) then return end
  if Spring.IsReplay() or not wasEverPlayer then return end

  local myAllyTeamID = Spring.GetMyAllyTeamID()

  if debugMode then
    Spring.Echo("GameOver: myAllyTeamID=" .. tostring(myAllyTeamID)
      .. " winners=" .. Spring.Utilities.TableToString(winningAllyTeams))
  end

  local outcomeSound, label
  if winningAllyTeams == nil then
    outcomeSound, label = defeatSound, "Defeat (resign)"
  elseif #winningAllyTeams == 0 then
    outcomeSound, label = drawSound, "Draw"
  else
    local amWinner = false
    for _, allyTeamID in ipairs(winningAllyTeams) do
      if allyTeamID == myAllyTeamID then
        amWinner = true
        break
      end
    end
    outcomeSound, label = amWinner and victorySound or defeatSound,
                          amWinner and "Victory"    or "Defeat"
  end

  EnqueueFinalOutcome(outcomeSound, label)
end
