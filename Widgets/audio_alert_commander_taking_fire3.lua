function widget:GetInfo()
  return {
    name      = "commander_taking_fire Audio Alert",
    desc      = "Plays a sound when your commander takes damage (supports all commander types)",
    author    = "FrequentPilgrim",
    date      = "2025-06-09",
    license   = "GNU GPL v2",
    layer     = 0,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu toggle (preserved; no new knobs)
--------------------------------------------------------------------------------
options = options or {}
options.enableCommanderDamageAlert = {
  name  = "Commander Taking Fire Alert",
  desc  = "Play an alert sound when your commander takes damage.",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
  return {
    enableCommanderDamageAlert = options.enableCommanderDamageAlert
      and options.enableCommanderDamageAlert.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.enableCommanderDamageAlert ~= nil
     and options and options.enableCommanderDamageAlert then
    options.enableCommanderDamageAlert.value = data.enableCommanderDamageAlert
  end
end

local function FeatureEnabled()
  return options and options.enableCommanderDamageAlert
     and options.enableCommanderDamageAlert.value
end

--------------------------------------------------------------------------------
-- Locals (original behavior preserved)
--------------------------------------------------------------------------------
local GetMyTeamID       = Spring.GetMyTeamID
local GetUnitRulesParam = Spring.GetUnitRulesParam
local GetGameFrame      = Spring.GetGameFrame
local PlaySoundFile     = Spring.PlaySoundFile
local VFS_FileExists    = VFS.FileExists

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
