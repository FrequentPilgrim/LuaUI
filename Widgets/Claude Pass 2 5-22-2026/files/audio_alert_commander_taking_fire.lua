function widget:GetInfo()
  return {
    name    = "Commander Taking Fire Audio Alert",
    desc    = "Plays an alert sound when your commander takes damage. Supports all commander types.",
    author  = "FrequentPilgrim",
    date    = "2025-06-09",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableCommanderDamageAlert", "commanderDamageAlertSpec" }

options = {
  enableCommanderDamageAlert = {
    name  = "Commander Taking Fire",
    desc  = "Play an alert sound when your commander takes damage.",
    type  = "bool",
    value = true,
  },
  commanderDamageAlertSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableCommanderDamageAlert = options.enableCommanderDamageAlert.value,
    commanderDamageAlertSpec   = options.commanderDamageAlertSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableCommanderDamageAlert ~= nil then options.enableCommanderDamageAlert.value = data.enableCommanderDamageAlert end
  if data.commanderDamageAlertSpec   ~= nil then options.commanderDamageAlertSpec.value   = data.commanderDamageAlertSpec   end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_FILE      = "LuaUI/Sounds/commander_taking_fire.ogg"
local SOUND_VOLUME    = 3.0
local COOLDOWN_FRAMES = 660   -- 22 seconds

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetMyTeamID        = Spring.GetMyTeamID
local GetUnitRulesParam  = Spring.GetUnitRulesParam
local GetGameFrame       = Spring.GetGameFrame
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState
local VFSFileExists      = VFS.FileExists

local lastSoundFrame = -math.huge

local commanderPrefixes = {
  "dynrecon", "dynstrike", "dynassault", "dynsupport", "dynknight",
  "dyntrainer", "zk_commander", "zk_custom", "zk_chassis", "comm"
}

local function FeatureEnabled() return options.enableCommanderDamageAlert.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.commanderDamageAlertSpec.value
end

local function SafePlay(path, vol)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    WG.VoiceBus.play(path, { volume = vol, channel = "ui" })
  else
    PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

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
-- Engine hooks
--------------------------------------------------------------------------------
function widget:Initialize()
  if not VFSFileExists(SOUND_FILE) then
    widgetHandler:RemoveWidget(self)
  end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam)
  if not FeatureEnabled() then return end
  if not spec_ok() then return end
  if unitTeam ~= GetMyTeamID() then return end
  if not IsCommander(unitID, unitDefID) then return end

  local f = GetGameFrame()
  if (f - lastSoundFrame) < COOLDOWN_FRAMES then return end

  SafePlay(SOUND_FILE, SOUND_VOLUME)
  lastSoundFrame = f
end
