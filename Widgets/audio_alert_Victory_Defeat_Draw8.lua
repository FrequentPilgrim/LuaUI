function widget:GetInfo()
  return {
    name    = "Victory, Defeat and Draw Audio Alert",
    desc    = "Plays a sound on victory, defeat, or draw (not for replays or pure spectators)",
    author  = "FrequentPilgrim (+bus routing & post-match lock)",
    date    = "2025-08-13",
    license = "GNU GPL v2",
    enabled = true,
    layer   = 0,
  }
end

----------------------------------------
-- Epic Menu Option (preserved)
----------------------------------------
options = options or {
  enableAlerts = {
    name  = "Victory/Defeat/Draw Alerts",
    desc  = "Play end-of-match sounds (victory/defeat/draw).",
    type  = "bool",
    value = true,
    path  = "Settings/Audio/Audio Alerts",
  },
}

-- Persist the checkbox value across reloads/restarts (preserved)
function widget:GetConfigData()
  return {
    enableAlerts = options and options.enableAlerts and options.enableAlerts.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.enableAlerts ~= nil and options and options.enableAlerts then
    options.enableAlerts.value = data.enableAlerts
  end
end

----------------------------------------
-- Config (preserved)
----------------------------------------
local victorySound = "LuaUI/Sounds/congratulations_commander.ogg"
local defeatSound  = "LuaUI/Sounds/we_have_been_annihilated.ogg"
local drawSound    = "LuaUI/Sounds/it_is_a_draw.ogg"
local volume       = 3.0

----------------------------------------
-- State (preserved)
----------------------------------------
local played = false
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
local function SafePlayQueued(path, vol)
  -- Queue-only behavior: we enqueue the outcome line after clearing all pending items.
  -- If the bus isn't available, fall back to direct playback.
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    -- Highest priority so if anything slips into the queue after clear (shouldn't), it stays behind.
    WG.VoiceBus.play(path, { volume = vol, channel = "ui", priority = 999999 })
  else
    Spring.PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

local function LockOutAllFutureAlerts()
  if WG and WG.VoiceBus then
    -- Drop anything waiting.
    if WG.VoiceBus.clear then WG.VoiceBus.clear() end
    -- Hard lock: prevent ANY future enqueues from any widget after match end.
    if not WG.VoiceBus._locked then
      WG.VoiceBus._locked = true
      WG.VoiceBus._origPlay = WG.VoiceBus.play
      WG.VoiceBus.play = function() return false end
    end
  end
end

----------------------------------------
-- Engine Hooks (preserved + queue/lock behavior)
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

  -- Respect Epic Menu toggle
  if not (options and options.enableAlerts and options.enableAlerts.value) then
    return
  end

  -- Never play in replays; only suppress if we were a pure spectator all game
  if Spring.IsReplay() or not wasEverPlayer then
    return
  end

  -- Ensure nothing else will play AFTER the outcome line:
  -- 1) Clear any queued alerts
  if WG and WG.VoiceBus and WG.VoiceBus.clear then
    WG.VoiceBus.clear()
  end

  -- Choose which outcome sound to enqueue (or fallback direct if no bus)
  local myAllyTeamID = Spring.GetMyAllyTeamID()

  -- Draw
  if not winningAllyTeams or #winningAllyTeams == 0 then
    SafePlayQueued(drawSound, volume)
    LockOutAllFutureAlerts()
    return
  end

  -- Victory?
  for _, allyTeamID in ipairs(winningAllyTeams) do
    if allyTeamID == myAllyTeamID then
      SafePlayQueued(victorySound, volume)
      LockOutAllFutureAlerts()
      return
    end
  end

  -- Otherwise, defeat
  SafePlayQueued(defeatSound, volume)
  LockOutAllFutureAlerts()
end

-- (Optional) quick debug — uncomment if you want log lines
-- local function dbg(msg) Spring.Echo("[AudioAlert]", msg) end
-- Insert dbg("outcome=defeat/victory/draw, wasEverPlayer="..tostring(wasEverPlayer))
-- right before SafePlayQueued(...) if needed.
