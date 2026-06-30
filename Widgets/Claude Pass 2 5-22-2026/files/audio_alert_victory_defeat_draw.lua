function widget:GetInfo()
  return {
    name    = "Victory, Defeat and Draw Audio Alert",
    desc    = "Plays an alert sound at match end: victory, defeat, or draw.",
    author  = "FrequentPilgrim",
    date    = "2025-09-18",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableAlerts", "victoryDefeatSpec" }

options = {
  enableAlerts = {
    name  = "Victory / Defeat / Draw",
    desc  = "Play an alert sound at the end of a match (victory, defeat, or draw).",
    type  = "bool",
    value = true,
  },
  victoryDefeatSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableAlerts      = options.enableAlerts.value,
    victoryDefeatSpec = options.victoryDefeatSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableAlerts      ~= nil then options.enableAlerts.value      = data.enableAlerts      end
  if data.victoryDefeatSpec ~= nil then options.victoryDefeatSpec.value = data.victoryDefeatSpec end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_VICTORY = "LuaUI/Sounds/congratulations_commander.ogg"
local SOUND_DEFEAT  = "LuaUI/Sounds/we_have_been_annihilated.ogg"
local SOUND_DRAW    = "LuaUI/Sounds/it_is_a_draw.ogg"
local SOUND_VOLUME  = 3.0

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetMyPlayerID      = Spring.GetMyPlayerID
local GetMyAllyTeamID    = Spring.GetMyAllyTeamID
local GetPlayerInfo      = Spring.GetPlayerInfo
local IsReplay           = Spring.IsReplay
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState

local played        = false
local wasEverPlayer = false

local function FeatureEnabled() return options.enableAlerts.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.victoryDefeatSpec.value
end

local function updateEverPlayer()
  local myID = GetMyPlayerID()
  if myID then
    local _, _, isSpec = GetPlayerInfo(myID)
    if not isSpec then wasEverPlayer = true end
  end
end

local function LockOutAllFutureAlerts()
  if WG and WG.VoiceBus and not WG.VoiceBus._locked then
    WG.VoiceBus._locked   = true
    WG.VoiceBus._origPlay = WG.VoiceBus.play
    WG.VoiceBus.play      = function() return false end
  end
end

local function EnqueueFinalOutcome(path)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    if WG.VoiceBus.clear then WG.VoiceBus.clear() end
    WG.VoiceBus.play(path, { volume = SOUND_VOLUME, channel = "ui", priority = 999999 })
    LockOutAllFutureAlerts()
  else
    PlaySoundFile(path, SOUND_VOLUME, nil, nil, nil, nil, nil, nil, "ui")
  end
end

--------------------------------------------------------------------------------
-- Engine hooks
--------------------------------------------------------------------------------
function widget:Initialize()
  updateEverPlayer()
end

function widget:PlayerChanged(playerID)
  if playerID == GetMyPlayerID() then
    updateEverPlayer()
  end
end

function widget:GameOver(winningAllyTeams)
  if played then return end
  played = true

  if not FeatureEnabled() then return end
  if not spec_ok() then return end
  if not wasEverPlayer and not options.victoryDefeatSpec.value then return end
  if IsReplay() and not options.victoryDefeatSpec.value then return end

  local myAllyTeamID = GetMyAllyTeamID()

  local outcomeSound
  if winningAllyTeams == nil then
    outcomeSound = SOUND_DEFEAT
  elseif #winningAllyTeams == 0 then
    outcomeSound = SOUND_DRAW
  else
    local amWinner = false
    for _, allyTeamID in ipairs(winningAllyTeams) do
      if allyTeamID == myAllyTeamID then amWinner = true; break end
    end
    outcomeSound = amWinner and SOUND_VICTORY or SOUND_DEFEAT
  end

  EnqueueFinalOutcome(outcomeSound)
end
