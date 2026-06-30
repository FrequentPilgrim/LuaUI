function widget:GetInfo()
  return {
    name      = "Commander Chassis Destroyed and Upgrade Complete Audio Alerts",
    desc      = "Audio alerts for commander death and upgrade completion. Pairs destroy/create events to distinguish upgrades from genuine deaths.",
    author    = "FrequentPilgrim",
    date      = "2025-08-16",
    license   = "MIT",
    layer     = 0,
    enabled   = true,
  }
end

local debugMode = false   -- set true to also print system messages for commander events (edit this file to enable)

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options = {
  commander_chassis_destroyed = {
    name = "Commander Chassis Destroyed",
    desc = "Play audio when your commander truly dies.",
    type = "bool", value = true,
    path = "Settings/Audio/Audio Alerts",
  },
  upgrade_complete = {
    name = "Upgrade Complete",
    desc = "Play audio when your commander finishes an upgrade.",
    type = "bool", value = true,
    path = "Settings/Audio/Audio Alerts",
  },
}

function widget:GetConfigData()
  return {
    commander_chassis_destroyed = options.commander_chassis_destroyed and options.commander_chassis_destroyed.value or true,
    upgrade_complete            = options.upgrade_complete            and options.upgrade_complete.value            or true,
  }
end

function widget:SetConfigData(data)
  if type(data) ~= "table" then return end
  if data.commander_chassis_destroyed ~= nil and options.commander_chassis_destroyed then
    options.commander_chassis_destroyed.value = data.commander_chassis_destroyed
  end
  if data.upgrade_complete ~= nil and options.upgrade_complete then
    options.upgrade_complete.value = data.upgrade_complete
  end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_DEATH_PATH   = "LuaUI/Sounds/commander_chassis_destroyed.ogg"
local SOUND_UPGRADE_PATH = "LuaUI/Sounds/upgrade_complete.ogg"
local VOLUME             = 3
local DETECT_WINDOW      = 12   -- frames to pair destroy→create (~0.4s @30fps)
local DETECT_RADIUS      = 64   -- elmos for "same spot" match
local RECENT_CREATE_WIN  = 6    -- tiny cache if Create arrives before Destroy

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local spGetMyTeamID     = Spring.GetMyTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spPlaySoundFile   = Spring.PlaySoundFile
local spEcho            = Spring.Echo
local VFSFileExists     = VFS.FileExists

local function SystemText(msg)
  if debugMode then
    spEcho("game_message: " .. msg)
  end
end

local function SafePlay(path)
  if not path or path == "" then return end
  if not VFSFileExists(path) then return end
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    WG.VoiceBus.play(path, { volume = VOLUME })
  else
    spPlaySoundFile(path, VOLUME)
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

local function TeamIsCurrentView(teamID)
  local myTeam = spGetMyTeamID()
  if not teamID or myTeam == nil or myTeam < 0 then return false end
  return teamID == myTeam
end

--------------------------------------------------------------------------------
-- Detection state
--------------------------------------------------------------------------------
local pendingDeaths  = {}
local recentCreates  = {}

--------------------------------------------------------------------------------
-- Initialize
--------------------------------------------------------------------------------
function widget:Initialize()
  if not VFSFileExists(SOUND_DEATH_PATH) and not VFSFileExists(SOUND_UPGRADE_PATH) then
    widgetHandler:RemoveWidget(self)
  end
end

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
function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if not IsCommanderDef(unitDefID) then return end
  if not TeamIsCurrentView(unitTeam) then return end

  local x, y, z = spGetUnitPosition(unitID)
  if not x then x, z = 0, 0 end

  local now      = Spring.GetGameFrame()
  local radiusSq = DETECT_RADIUS * DETECT_RADIUS

  local bestOld = TryPairCreate(unitTeam, x, z, now, radiusSq)
  if bestOld then
    pendingDeaths[bestOld] = nil
    if options.upgrade_complete and options.upgrade_complete.value then
      SafePlay(SOUND_UPGRADE_PATH)
      SystemText("Upgrade Complete.")
    end
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
  if not TeamIsCurrentView(unitTeam) then return end

  local x, y, z = spGetUnitPosition(unitID)
  if not x then x, z = 0, 0 end

  local now      = Spring.GetGameFrame()
  local radiusSq = DETECT_RADIUS * DETECT_RADIUS

  local idx = TryPairWithRecentCreate(unitTeam, x, z, now, radiusSq)
  if idx then
    if options.upgrade_complete and options.upgrade_complete.value then
      SafePlay(SOUND_UPGRADE_PATH)
      SystemText("Upgrade Complete.")
    end
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
      if options.commander_chassis_destroyed and options.commander_chassis_destroyed.value then
        SafePlay(SOUND_DEATH_PATH)
        SystemText("Commander Chassis Destroyed.")
      end
      pendingDeaths[oldID] = nil
    end
  end

  for i = #recentCreates, 1, -1 do
    local rc = recentCreates[i]
    if not rc or n > rc.expire then
      recentCreates[i] = nil
    end
  end
end
