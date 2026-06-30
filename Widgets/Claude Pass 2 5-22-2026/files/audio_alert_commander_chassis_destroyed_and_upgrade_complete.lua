function widget:GetInfo()
  return {
    name    = "Commander Chassis Destroyed and Upgrade Complete Audio Alerts",
    desc    = "Plays alert sounds for commander death and upgrade completion. Pairs destroy/create events to distinguish upgrades from genuine deaths.",
    author  = "FrequentPilgrim",
    date    = "2025-08-16",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "alertDeath", "alertUpgrade", "commanderAlertsSpec" }

options = {
  alertDeath = {
    name  = "Commander Chassis Destroyed",
    desc  = "Play an alert sound when your commander is destroyed.",
    type  = "bool",
    value = true,
  },
  alertUpgrade = {
    name  = "Commander Upgrade Complete",
    desc  = "Play an alert sound when your commander finishes an upgrade.",
    type  = "bool",
    value = true,
  },
  commanderAlertsSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play these alerts when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    alertDeath          = options.alertDeath.value,
    alertUpgrade        = options.alertUpgrade.value,
    commanderAlertsSpec = options.commanderAlertsSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.alertDeath          ~= nil then options.alertDeath.value          = data.alertDeath          end
  if data.alertUpgrade        ~= nil then options.alertUpgrade.value        = data.alertUpgrade        end
  if data.commanderAlertsSpec ~= nil then options.commanderAlertsSpec.value = data.commanderAlertsSpec end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_DEATH_PATH   = "LuaUI/Sounds/commander_chassis_destroyed.ogg"
local SOUND_UPGRADE_PATH = "LuaUI/Sounds/upgrade_complete.ogg"
local SOUND_VOLUME       = 3.0
local DETECT_WINDOW      = 12   -- frames to pair destroy→create (~0.4s @30fps)
local DETECT_RADIUS      = 64   -- elmos for "same spot" match
local RECENT_CREATE_WIN  = 6    -- cache window if Create arrives before Destroy

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetMyTeamID        = Spring.GetMyTeamID
local GetUnitPosition    = Spring.GetUnitPosition
local GetGameFrame       = Spring.GetGameFrame
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState
local VFSFileExists      = VFS.FileExists

local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.commanderAlertsSpec.value
end

local function SafePlay(path, vol)
  if not path or path == "" then return end
  if not VFSFileExists(path) then return end
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    WG.VoiceBus.play(path, { volume = vol, channel = "ui" })
  else
    PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

local function Dist2DSq(x1, z1, x2, z2)
  local dx, dz = x1 - x2, z1 - z2
  return dx * dx + dz * dz
end

local function IsCommanderDef(unitDefID)
  local ud = UnitDefs[unitDefID]; if not ud then return false end
  local cp = ud.customParams or {}
  if cp.iscommander or cp.commander or cp.commtype
     or cp.modularcomm or cp.dynamic_comm or cp.dyncomm then
    return true
  end
  local n = (ud.name or ""):lower()
  return n:find("commander", 1, true) or n:find("dyn", 1, true)
end

local function TeamIsMyTeam(teamID)
  local myTeam = GetMyTeamID()
  if not teamID or myTeam == nil or myTeam < 0 then return false end
  return teamID == myTeam
end

--------------------------------------------------------------------------------
-- Detection state
--------------------------------------------------------------------------------
local pendingDeaths = {}
local recentCreates = {}

--------------------------------------------------------------------------------
-- Pairing helpers
--------------------------------------------------------------------------------
local function TryPairCreate(team, x, z, nowFrame, radiusSq)
  local bestOld, bestDist = nil, 1e30
  for oldID, pd in pairs(pendingDeaths) do
    if pd.team == team and nowFrame <= pd.expire then
      local d2 = Dist2DSq(pd.x, pd.z, x, z)
      if d2 <= radiusSq and d2 < bestDist then
        bestDist, bestOld = d2, oldID
      end
    end
  end
  return bestOld
end

local function TryPairWithRecentCreate(team, x, z, nowFrame, radiusSq)
  local bestIdx, bestDist = nil, 1e30
  for i = 1, #recentCreates do
    local rc = recentCreates[i]
    if rc and rc.team == team and nowFrame <= rc.expire then
      local d2 = Dist2DSq(x, z, rc.x, rc.z)
      if d2 <= radiusSq and d2 < bestDist then
        bestDist, bestIdx = d2, i
      end
    end
  end
  return bestIdx
end

--------------------------------------------------------------------------------
-- Engine hooks
--------------------------------------------------------------------------------
function widget:Initialize()
  if not VFSFileExists(SOUND_DEATH_PATH) and not VFSFileExists(SOUND_UPGRADE_PATH) then
    widgetHandler:RemoveWidget(self)
  end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if not IsCommanderDef(unitDefID) then return end
  if not TeamIsMyTeam(unitTeam) then return end
  if not spec_ok() then return end

  local x, y, z = GetUnitPosition(unitID)
  if not x then x, z = 0, 0 end

  local now      = GetGameFrame()
  local radiusSq = DETECT_RADIUS * DETECT_RADIUS

  local bestOld = TryPairCreate(unitTeam, x, z, now, radiusSq)
  if bestOld then
    pendingDeaths[bestOld] = nil
    if options.alertUpgrade.value then SafePlay(SOUND_UPGRADE_PATH, SOUND_VOLUME) end
    return
  end

  recentCreates[#recentCreates + 1] = {
    unitID = unitID, team = unitTeam,
    x = x or 0, z = z or 0,
    expire = now + RECENT_CREATE_WIN,
  }
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if not IsCommanderDef(unitDefID) then return end
  if not TeamIsMyTeam(unitTeam) then return end
  if not spec_ok() then return end

  local x, y, z = GetUnitPosition(unitID)
  if not x then x, z = 0, 0 end

  local now      = GetGameFrame()
  local radiusSq = DETECT_RADIUS * DETECT_RADIUS

  local idx = TryPairWithRecentCreate(unitTeam, x, z, now, radiusSq)
  if idx then
    if options.alertUpgrade.value then SafePlay(SOUND_UPGRADE_PATH, SOUND_VOLUME) end
    recentCreates[idx] = nil
    return
  end

  pendingDeaths[unitID] = {
    team   = unitTeam,
    x      = x or 0,
    z      = z or 0,
    expire = now + DETECT_WINDOW,
  }
end

function widget:GameFrame(n)
  for oldID, pd in pairs(pendingDeaths) do
    if n > pd.expire then
      if options.alertDeath.value then SafePlay(SOUND_DEATH_PATH, SOUND_VOLUME) end
      pendingDeaths[oldID] = nil
    end
  end

  for i = #recentCreates, 1, -1 do
    local rc = recentCreates[i]
    if not rc or n > rc.expire then recentCreates[i] = nil end
  end
end
