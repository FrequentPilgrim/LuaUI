function widget:GetInfo()
  return {
    name    = "Victory, Defeat and Draw Audio Alert",
    desc    = "Plays a single announcement after match end.",
    author  = "FrequentPilgrim",
    date      = "2025-09-18",
    license = "MIT",
    enabled = true,
    layer   = 0,
  }
end

local debugMode = false   -- set true for console messages. Playback logic is completely independent of this value.

-- DIAGNOSTIC (only shown when debugMode = true)
if debugMode then
  Spring.Echo("[VDD-LOAD] Widget file parsed and top-level code executed")
end

----------------------------------------
-- Epic Menu
----------------------------------------
options = options or {}
options.victory_defeat_draw = {
  name  = "Victory/Defeat/Draw Announcements",
  desc  = "Play end-of-match audio (victory/defeat/draw).",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
  return {
    victory_defeat_draw = options.victory_defeat_draw and options.victory_defeat_draw.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.victory_defeat_draw ~= nil and options and options.victory_defeat_draw then
    options.victory_defeat_draw.value = data.victory_defeat_draw
  end
end

-- Gating (easy one-line reversal; default = do not play in these modes)
--
-- Note: RUN_IN_SPECTATOR is intentionally omitted from this widget.
-- The wasEverPlayer system (combined with PlayerChanged tracking) already
-- ensures that anyone who started as a player will still receive the
-- victory/defeat/draw sound even if they resigned or became a spectator
-- before the game ended. This matches the original baseline design.
local RUN_IN_REPLAY    = false
local RUN_IN_CAMPAIGN  = true

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
-- These flags must be reset at the start of every new game.
-- They are the only reason debugMode could ever appear to affect playback.
local played                 = false
local wasEverPlayer          = false
local missionGameOverChecked = false   -- used only by the scripted mission end-screen path

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

local function EnqueueFinalOutcome(path, label, forceDirect)
  local busAvailable = WG and WG.VoiceBus and WG.VoiceBus.play

  -- Preferred path for mission end screens: use the bus with immediate=true.
  -- This gives us reliable "play right now" behavior while still applying the
  -- user's Voice Alerts Master Volume (masterGain) and participating in the
  -- lock/clear contract.
  if busAvailable and not forceDirect then
    if WG.VoiceBus.clear then WG.VoiceBus.clear() end
    local ok = WG.VoiceBus.play(path, {
      volume   = volume,
      channel  = "ui",
      priority = 999999,
      immediate = true
    })
    LockOutAllFutureAlerts()
    if ok then
      if debugMode then
        Spring.Echo("[VDD] " .. label .. " (final outcome via VoiceBus immediate)")
      end
      return
    end
    -- If the bus rejected it (locked or other reason), fall through to direct.
  end

  -- Fallback / normal GameOver path
  if busAvailable and not forceDirect then
    if WG.VoiceBus.clear then WG.VoiceBus.clear() end
    WG.VoiceBus.play(path, { volume = volume, channel = "ui", priority = 999999 })
    LockOutAllFutureAlerts()
    if debugMode then
      Spring.Echo("[VDD] " .. label .. " (final outcome queued via VoiceBus)")
    end
  else
    Spring.PlaySoundFile(path, volume, nil, nil, nil, nil, nil, nil, "ui")
    if debugMode then
      Spring.Echo("[VDD] " .. label .. " (final outcome DIRECT PlaySoundFile - volume " .. tostring(volume) .. ")")
    end
  end
end

----------------------------------------
-- Engine Hooks
----------------------------------------
function widget:Initialize()
  -- Reset one-shot end-game flags on widget (re)load.
  -- This is critical so the widget works correctly when the user
  -- retries a mission or starts a new game without a full Spring restart.
  played = false
  missionGameOverChecked = false
  wasEverPlayer = false

  updateEverPlayer()

  if debugMode then
    local mo = Spring.GetModOptions() or {}
    local myID = Spring.GetMyPlayerID()
    local _, _, isSpec = myID and Spring.GetPlayerInfo(myID) or nil, nil, nil
    Spring.Echo(string.format(
      "[VDD] Initialize: flags reset | wasEverPlayer=%s | myPlayerID=%s | isSpec=%s | campaignBattleID=%s | RUN_IN_CAMPAIGN=%s",
      tostring(wasEverPlayer), tostring(myID), tostring(isSpec), tostring(mo.singleplayercampaignbattleid), tostring(RUN_IN_CAMPAIGN)
    ))
  end
end

function widget:PlayerChanged(playerID)
  if playerID == Spring.GetMyPlayerID() then
    updateEverPlayer()
  end
end

-- GameStart is the most reliable place to reset per-game one-shot state
-- in Spring widgets (fires after the game has actually begun).
function widget:GameStart()
  played = false
  missionGameOverChecked = false
  wasEverPlayer = false
  updateEverPlayer()
end

function widget:Shutdown()
  -- Belt-and-suspenders reset on widget disable/reload (common during testing).
  played = false
  missionGameOverChecked = false
  wasEverPlayer = false
end

function widget:GameOver(winningAllyTeams)
  if played then return end
  played = true

  if not (options and options.victory_defeat_draw and options.victory_defeat_draw.value) then return end

  local mo = Spring.GetModOptions() or {}
  local isCampaign = mo.singleplayercampaignbattleid and RUN_IN_CAMPAIGN

  -- In normal games we require wasEverPlayer (original behavior).
  -- In campaigns we relax this so the sound can play even if the normal
  -- player tracking didn't fire (common in scripted missions).
  if not wasEverPlayer and not isCampaign then return end

  if Spring.IsReplay() and not RUN_IN_REPLAY then return end

  -- We intentionally do NOT check current spectator state here.
  -- The wasEverPlayer system (original baseline design) ensures that anyone
  -- who started as a player still receives the end-game sound even if they
  -- resigned or became a spectator before the game ended.
  -- This matches the original behavior for both defeat and victory cases
  -- (e.g. resigned but your team still wins).

  if mo.singleplayercampaignbattleid and not RUN_IN_CAMPAIGN then return end

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

--------------------------------------------------------------------------------
-- Support for scripted missions / tutorials that use MissionGameOver params
-- instead of (or before) the normal GameOver callin.
--
-- These missions (singleplayercampaignbattleid + galaxy battle handler) set the
-- values via the synced gadget using SetTeamRulesParam(0, key, ...) -- NOT
-- SetGameRulesParam. We therefore read via GetTeamRulesParam(0, ...).
-- The authoritative win/loss flag is "MissionGameOver" (1=win, 0=loss).
-- Normal skirmish/MP behavior is 100% unaffected because these params are never
-- set outside the mission end-screen system.
--
-- We observe the end condition in two places for maximum reliability:
--   1. GameFrame (every frame for the signal, throttled only for debug spam)
--   2. DrawScreen (catches the exact moment the handler is drawing the window)
-- One-shot flags (played / missionGameOverChecked) are only set after all gates
-- have passed and we are about to actually play audio. This prevents the
-- previous "sometimes it works, sometimes it randomly doesn't" behavior.
--------------------------------------------------------------------------------

function widget:GameFrame(n)
  -- Fast path: if we've already handled end-game audio this game, do nothing.
  if played or missionGameOverChecked then return end

  -- Correct getters (must match the gadget's SetTeamRulesParam(0, ...) hax).
  local frames    = Spring.GetTeamRulesParam(0, "MissionGameOver_frames")
  local losses    = Spring.GetTeamRulesParam(0, "MissionGameOver_losses")
  local missionWin = Spring.GetTeamRulesParam(0, "MissionGameOver")  -- 1 = victory, 0 = defeat (or nil)

  -- Check for the mission end signal **every frame**.
  -- The %5 throttle is now only used to reduce debug spam, not to delay detection.
  -- This makes triggering when the "Defeat/Victory + Click to continue" window appears reliable.
  local missionEndSignal = (frames and frames > 0) or (missionWin ~= nil)

  -- Determine early whether we are in a real campaign/scripted mission (for debug gating only).
  local mo = Spring.GetModOptions() or {}
  local inCampaign = mo.singleplayercampaignbattleid ~= nil

  -- Sane debug output (throttled to every 5 frames so it doesn't flood even in campaigns).
  if debugMode and inCampaign and (n % 5 == 0) then
    Spring.Echo(string.format(
      "[VDD] GameFrame poll: frames=%s | missionWin=%s | losses=%s | wasEverPlayer=%s | n=%d",
      tostring(frames), tostring(missionWin), tostring(losses), tostring(wasEverPlayer), n
    ))
  end

  if missionEndSignal and not missionGameOverChecked then
    -- We saw the mission end params. Print loud diagnostic state so we can see
    -- exactly why we did or did not play (this fires even with debugMode=false
    -- during the current troubleshooting).
    local optionEnabled = (options and options.victory_defeat_draw and options.victory_defeat_draw.value) or false
    local isCampaign = mo.singleplayercampaignbattleid and RUN_IN_CAMPAIGN
    local relaxWasEverPlayer = isCampaign
      or (mo.singleplayercampaignbattleid ~= nil)
      or (frames and frames > 0)
      or (missionWin ~= nil)

    Spring.Echo(string.format(
      "[VDD-MISSION-SIGNAL] frames=%s missionWin=%s wasEverPlayer=%s option=%s isCampaign=%s relax=%s RUN_IN_CAMPAIGN=%s",
      tostring(frames), tostring(missionWin), tostring(wasEverPlayer),
      tostring(optionEnabled), tostring(isCampaign), tostring(relaxWasEverPlayer),
      tostring(RUN_IN_CAMPAIGN)
    ))

    -- IMPORTANT: Do NOT set missionGameOverChecked or played yet.
    -- We only arm the one-shot flags after we have passed every gate and are about to play.

    if not optionEnabled then return end
    if Spring.IsReplay() and not RUN_IN_REPLAY then return end

    -- For anything that produces the actual MissionGameOver params + end window,
    -- we now play the sound. The presence of the param itself is the signal.
    -- We still respect the global option and replay flag above.
    if not wasEverPlayer and not relaxWasEverPlayer then return end

    local isWin = (missionWin == 1)
    local outcomeSound = isWin and victorySound or defeatSound
    local label = isWin and "Victory (mission)" or "Defeat (mission)"

    if debugMode then
      Spring.Echo(string.format(
        "[VictoryDefeatDraw] MissionGameOver signal: frames=%s | missionWin=%s | losses=%s | playing %s",
        tostring(frames), tostring(missionWin), tostring(losses), label
      ))
    end

    -- Only now do we arm the one-shots.
    missionGameOverChecked = true
    played = true
    EnqueueFinalOutcome(outcomeSound, label)  -- will use VoiceBus with immediate=true
  end
end

--------------------------------------------------------------------------------
-- Secondary observer using DrawScreen.
-- The galaxy battle handler draws the actual "Victory/Defeat + Click to continue"
-- window from its own DrawScreen when the end state is active.
-- Checking the public MissionGameOver* TeamRulesParams here gives us another
-- reliable chance to trigger (especially useful if GameFrame timing is unusual
-- in certain tutorials or when the game is paused/fading).
--------------------------------------------------------------------------------
function widget:DrawScreen()
  if played or missionGameOverChecked then return end

  local frames    = Spring.GetTeamRulesParam(0, "MissionGameOver_frames")
  local missionWin = Spring.GetTeamRulesParam(0, "MissionGameOver")

  local missionEndSignal = (frames and frames > 0) or (missionWin ~= nil)
  if not missionEndSignal then return end

  -- Loud diagnostic (even when debugMode=false) so we can see state when the window is drawing.
  local mo = Spring.GetModOptions() or {}
  local optionEnabled = (options and options.victory_defeat_draw and options.victory_defeat_draw.value) or false
  local isCampaign = mo.singleplayercampaignbattleid and RUN_IN_CAMPAIGN
  local relaxWasEverPlayer = isCampaign
    or (mo.singleplayercampaignbattleid ~= nil)
    or (frames and frames > 0)
    or (missionWin ~= nil)

  Spring.Echo(string.format(
    "[VDD-MISSION-SIGNAL-DRAW] frames=%s missionWin=%s wasEverPlayer=%s option=%s isCampaign=%s relax=%s",
    tostring(frames), tostring(missionWin), tostring(wasEverPlayer),
    tostring(optionEnabled), tostring(isCampaign), tostring(relaxWasEverPlayer)
  ))

  if not optionEnabled then return end
  if Spring.IsReplay() and not RUN_IN_REPLAY then return end
  if not wasEverPlayer and not relaxWasEverPlayer then return end

  local isWin = (missionWin == 1)
  local outcomeSound = isWin and victorySound or defeatSound
  local label = isWin and "Victory (mission)" or "Defeat (mission)"

  if debugMode then
    Spring.Echo(string.format(
      "[VictoryDefeatDraw] Mission end detected via DrawScreen: playing %s",
      label
    ))
  end

  missionGameOverChecked = true
  played = true
  EnqueueFinalOutcome(outcomeSound, label)  -- will use VoiceBus with immediate=true
end

--------------------------------------------------------------------------------
-- Tertiary observer in Update().
-- Some scripted missions pause the game or change speed when the end window
-- appears. Update() often continues to run in those situations.
--------------------------------------------------------------------------------
function widget:Update()
  if played or missionGameOverChecked then return end

  local frames    = Spring.GetTeamRulesParam(0, "MissionGameOver_frames")
  local missionWin = Spring.GetTeamRulesParam(0, "MissionGameOver")

  local missionEndSignal = (frames and frames > 0) or (missionWin ~= nil)
  if not missionEndSignal then return end

  local mo = Spring.GetModOptions() or {}
  local optionEnabled = (options and options.victory_defeat_draw and options.victory_defeat_draw.value) or false
  local isCampaign = mo.singleplayercampaignbattleid and RUN_IN_CAMPAIGN
  local relaxWasEverPlayer = isCampaign
    or (mo.singleplayercampaignbattleid ~= nil)
    or (frames and frames > 0)
    or (missionWin ~= nil)

  Spring.Echo(string.format(
    "[VDD-MISSION-SIGNAL-UPDATE] frames=%s missionWin=%s wasEverPlayer=%s option=%s relax=%s",
    tostring(frames), tostring(missionWin), tostring(wasEverPlayer),
    tostring(optionEnabled), tostring(relaxWasEverPlayer)
  ))

  if not optionEnabled then return end
  if Spring.IsReplay() and not RUN_IN_REPLAY then return end
  if not wasEverPlayer and not relaxWasEverPlayer then return end

  local isWin = (missionWin == 1)
  local outcomeSound = isWin and victorySound or defeatSound
  local label = isWin and "Victory (mission)" or "Defeat (mission)"

  if debugMode then
    Spring.Echo("[VictoryDefeatDraw] Mission end detected via Update: playing " .. label)
  end

  missionGameOverChecked = true
  played = true
  EnqueueFinalOutcome(outcomeSound, label)  -- will use VoiceBus with immediate=true
end
