function widget:GetInfo()
  return {
    name      = "commander_taking_fire Audio Alert",
    desc      = "Plays a sound when your commander takes damage (supports all commander types)",
    author    = "FrequentPilgrim",
    date      = "2025-06-09",
    license   = "MIT",
    layer     = 0,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu toggle
--------------------------------------------------------------------------------
options = options or {}
options.commander_taking_fire = {
  name  = "Commander Taking Fire",
  desc  = "Play an alert sound when your commander takes damage.",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
  return {
    commander_taking_fire = options.commander_taking_fire
      and options.commander_taking_fire.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.commander_taking_fire ~= nil
     and options and options.commander_taking_fire then
    options.commander_taking_fire.value = data.commander_taking_fire
  end
end

local function FeatureEnabled()
  return options and options.commander_taking_fire
     and options.commander_taking_fire.value
end

--------------------------------------------------------------------------------
-- Locals (original behavior preserved)
--------------------------------------------------------------------------------
local GetMyTeamID       = Spring.GetMyTeamID
local GetUnitRulesParam = Spring.GetUnitRulesParam
local GetGameFrame      = Spring.GetGameFrame
local PlaySoundFile     = Spring.PlaySoundFile
local VFS_FileExists    = VFS.FileExists

-- Gating (easy one-line reversal; default = do not play in these modes)
local RUN_IN_REPLAY    = false
local RUN_IN_SPECTATOR = false
local RUN_IN_CAMPAIGN  = true

local function play_ok()
  if Spring.IsReplay() and not RUN_IN_REPLAY then return false end
  if Spring.GetSpectatingState() and not RUN_IN_SPECTATOR then return false end
  local mo = Spring.GetModOptions() or {}
  if mo.singleplayercampaignbattleid and not RUN_IN_CAMPAIGN then return false end
  return true
end

local UnitDefs          = UnitDefs
local SOUND_FILE        = "LuaUI/sounds/commander_taking_fire.ogg"
local COOLDOWN_FRAMES   = 660  -- 22s * 30 FPS (preserved)
local lastPlayFrame     = 0

local commanderPrefixes = {
  "dynrecon", "dynstrike", "dynassault", "dynsupport", "dynknight",
  "dyntrainer", "zk_commander", "zk_custom", "zk_chassis", "comm"
}

local function IsCommander(unitID, unitDefID)
  local ud = UnitDefs[unitDefID]; if not ud then return false end
  local name     = ud.name or ""
  local isCmd    = GetUnitRulesParam(unitID, "iscommander")
  local commtype = GetUnitRulesParam(unitID, "commtype")
  local level    = GetUnitRulesParam(unitID, "level")
  if isCmd == 1 then return true end
  if commtype or (level and level > 0) then return true end
  for _, p in ipairs(commanderPrefixes) do
    if name:sub(1, #p) == p then return true end
  end
  if name:find("_base") then return true end
  return false
end

--------------------------------------------------------------------------------
-- Engine Hooks
--------------------------------------------------------------------------------
function widget:UnitDamaged(unitID, unitDefID, unitTeam)
  if not FeatureEnabled() then return end
  if unitTeam ~= GetMyTeamID() then return end
  if not IsCommander(unitID, unitDefID) then return end

  local currentFrame = GetGameFrame()
  if currentFrame - lastPlayFrame < COOLDOWN_FRAMES then return end

  if not play_ok() then return end
  -- Always route through the queueing bus; never cancel.
  local path = SOUND_FILE
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    WG.VoiceBus.play(path, {
      volume = 3.0,
      -- channel = "ui",   -- optional: set "voice" or "ui" if you want mixer routing
      -- key = "commander_taking_fire", cooldown = 0, priority = 0, -- optional dedupe if you ever want it
    })
  else
    -- Graceful fallback if bus isn't loaded for some reason
    PlaySoundFile(path, 3.0)
  end

  lastPlayFrame = currentFrame
end

function widget:Initialize()
  if not VFS_FileExists(SOUND_FILE) then
    widgetHandler:RemoveWidget(self)
  end
end
