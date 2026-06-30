--------------------------------------------------------------------------------
-- Battle Begins Countdown
-- Plays one sound exactly when "GameSetup: state=Starting in N" appears.
-- Map: 3 -> battle_begins_in.ogg
--      2 -> three.ogg
--      1 -> two.ogg
--      0 -> one.ogg
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name    = "Battle Begins Countdown Audio Alert",
    desc    = "Plays four countdown cues (3, 2, 1, go) exactly on the engine's pregame ticks.",
    author  = "FrequentPilgrim",
    date    = "2025-08-22",
    license = "MIT",
    layer   = -100,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableBattleCountdown", "battleCountdownSpec" }

options = {
  enableBattleCountdown = {
    name  = "Battle Begins Countdown",
    desc  = "Play an alert sound when the pregame countdown ticks (3, 2, 1, go).",
    type  = "bool",
    value = true,
  },
  battleCountdownSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableBattleCountdown = options.enableBattleCountdown.value,
    battleCountdownSpec   = options.battleCountdownSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableBattleCountdown ~= nil then options.enableBattleCountdown.value = data.enableBattleCountdown end
  if data.battleCountdownSpec   ~= nil then options.battleCountdownSpec.value   = data.battleCountdownSpec   end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SND_DIR = "LuaUI/Sounds/"
local SOUNDS = {
  [3] = SND_DIR .. "battle_begins_in.ogg",
  [2] = SND_DIR .. "three.ogg",
  [1] = SND_DIR .. "two.ogg",
  [0] = SND_DIR .. "one.ogg",
}

local SOUND_VOLUME = 1.0

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local Echo               = Spring.Echo
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState
local FileExists         = VFS.FileExists

local function FeatureEnabled() return options.enableBattleCountdown.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.battleCountdownSpec.value
end

-- Per-countdown state
local played = { [3]=false, [2]=false, [1]=false, [0]=false }
local lastStepSeen    = nil
local countdownActive = false

local function reset()
  played[3], played[2], played[1], played[0] = false, false, false, false
  lastStepSeen    = nil
  countdownActive = false
end

local function parse_step(state)
  if type(state) ~= "string" then return nil end
  local n = state:lower():match("starting%s+in%s+(%d+)")
  local k = n and tonumber(n) or nil
  if k and SOUNDS[k] then return k end
  return nil
end

local function is_choose_state(state)
  return type(state) == "string" and state:lower():find("choose start pos", 1, true) ~= nil
end

local function play_step(step)
  if played[step] then return end
  if not FeatureEnabled() or not spec_ok() then return end
  local path = SOUNDS[step]
  if not path then return end
  if FileExists(path) then
    PlaySoundFile(path, SOUND_VOLUME, "ui")
  else
    Echo("game_message: [Battle Begins Countdown] Missing sound file: " .. path)
  end
  played[step] = true
end

--------------------------------------------------------------------------------
-- Engine hooks
--------------------------------------------------------------------------------
function widget:GameSetup(state, ready)
  if countdownActive and is_choose_state(state) then
    reset()
    return
  end

  local step = parse_step(state)
  if not step then return end

  if lastStepSeen and step > lastStepSeen then reset() end

  countdownActive = true
  lastStepSeen    = step
  play_step(step)
end

function widget:GameStart()
  reset()
end

function widget:Initialize()
  for k, p in pairs(SOUNDS) do
    if not FileExists(p) then
      Echo("game_message: [Battle Begins Countdown] Missing sound file for step " .. k .. ": " .. p)
    end
  end
end

function widget:Shutdown()
  reset()
end
