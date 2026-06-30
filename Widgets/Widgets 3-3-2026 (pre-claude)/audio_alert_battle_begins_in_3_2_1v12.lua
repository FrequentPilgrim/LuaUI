--------------------------------------------------------------------------------
-- Battle Begins Countdown (Accuracy Only)
-- Plays one sound exactly when "GameSetup: state=Starting in N" appears.
-- Map: 3 -> battle_begins_in.ogg
--      2 -> three.ogg
--      1 -> two.ogg
--      0 -> one.ogg
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Battle Begins Countdown (Accurate 3→0)",
    desc      = "Plays four start cues exactly on the engine's countdown ticks.",
    author    = "You",
    date      = "2025-08-22",
    license   = "GPLv2+",
    layer     = -100,
    enabled   = true,
  }
end

--=== Config ================================================================--
local SND_DIR = "LuaUI/Sounds/"
local SOUNDS = {
  [3] = SND_DIR .. "battle_begins_in.ogg",
  [2] = SND_DIR .. "three.ogg",
  [1] = SND_DIR .. "two.ogg",
  [0] = SND_DIR .. "one.ogg",
}

local RUN_IN_SPECTATOR = false -- false = do not run in spec/replay

--=== Epic Menu =============================================================--
options_path = "Settings/Audio/Audio Alerts"
options = {
  begins_countdown_enable = { name = "Battle Begins Countdown (Accurate 3→0)", type = "bool", value = true },
  begins_countdown_verbose = { name = "Verbose debug", type = "bool", value = true },
}

--=== Locals ================================================================--
local Echo               = Spring.Echo
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState
local GetGameSeconds     = Spring.GetGameSeconds
local FileExists         = VFS.FileExists

local function enabled()  return not options or not options.begins_countdown_enable or options.begins_countdown_enable.value end
local function verbose()  return (options and options.begins_countdown_verbose and options.begins_countdown_verbose.value) or false end
local function spec_ok()
  if RUN_IN_SPECTATOR then return true end
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  return not (isSpec or isReplay)
end

local function dbg(s) if verbose() then Echo("game_message: [begins321] "..s) end end
local function gm(s)  if verbose() then Echo("game_message: "..s) end end

-- per-countdown state: which ticks have already played
local played = { [3]=false, [2]=false, [1]=false, [0]=false }
local lastStepSeen = nil
local countdownActive = false

local function reset(reason)
  played[3], played[2], played[1], played[0] = false, false, false, false
  lastStepSeen = nil
  countdownActive = false
  if verbose() then dbg("RESET ("..tostring(reason)..")") end
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

local function play_step(step, tag)
  if played[step] then return end
  if not enabled() or not spec_ok() then return end
  local path = SOUNDS[step]
  if not path then return end
  dbg(("PLAY step=%d (%s) t=%.2fs"):format(step, tag or "?", GetGameSeconds() or 0))
  if FileExists(path) then
    PlaySoundFile(path, 1.0, "ui")
  else
    gm(("Missing sound file: %s"):format(path))
  end
  played[step] = true
end

--=== Call-ins =============================================================--

-- Only trust GameSetup. No timers, no PGTK, no smoothing.
function widget:GameSetup(state, ready)
  -- If the lobby returns to "Choose start pos", wipe any partial countdown.
  if countdownActive and is_choose_state(state) then
    reset("returned to Choose start pos")
    return
  end

  local step = parse_step(state)
  if not step then
    if verbose() then dbg(("GameSetup: state=%s ready=%s"):format(tostring(state), tostring(ready))) end
    return
  end

  -- If we see a higher step than the last (e.g., 3 after 2/1), treat as a new countdown.
  if lastStepSeen and step > lastStepSeen then
    reset("countdown restarted at "..step)
  end

  countdownActive = true
  lastStepSeen = step
  play_step(step, "GameSetup Starting in "..step)
end

function widget:GameStart()
  dbg("GameStart")
  reset("game started")
end

function widget:Initialize()
  dbg("Initialize")
  -- Optional: warn once if any file is missing.
  for k, p in pairs(SOUNDS) do
    if not FileExists(p) then gm(("Countdown %d missing: %s"):format(k, p)) end
  end
end

function widget:Shutdown()
  dbg("Shutdown")
  reset("shutdown")
end
