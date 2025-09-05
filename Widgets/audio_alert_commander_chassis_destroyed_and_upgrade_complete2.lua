function widget:GetInfo()
  return {
    name      = "commander_chassis_destroyed and upgrade_complete Audio Alerts",
    desc      = "Two audio alerts with minimal Epic Menu: Commander Destroyed / Upgrade Complete",
    author    = "JHB + GPT",
    date      = "2025-08-16",
    license   = "GPLv2+",
    layer     = 0,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
-- Minimal Epic Menu: exactly two toggles (one per audio alert)
--------------------------------------------------------------------------------
options_path  = 'Settings/Audio/Audio Alerts'
options_order = {"alertDeath", "alertUpgrade"}
options = {
  alertDeath = {
    name = "Audio: Commander Chassis Destroyed",
    desc = "Play audio when YOUR current team's commander truly dies.",
    type = "bool", value = true,
  },
  alertUpgrade = {
    name = "Audio: Upgrade Complete",
    desc = "Play audio when YOUR current team's commander finishes an upgrade.",
    type = "bool", value = true,
  },
}

--------------------------------------------------------------------------------
-- Hardcoded defaults (intentionally NOT exposed in the menu)
--------------------------------------------------------------------------------
local SOUND_DEATH_PATH   = "LuaUI/Sounds/commander_chassis_destroyed.ogg"
local SOUND_UPGRADE_PATH = "LuaUI/Sounds/upgrade_complete.ogg"
local VOLUME             = 3           -- overall volume for both lines
local SHOW_TEXT          = false       -- show system-style text when the corresponding alert is on
local DETECT_WINDOW      = 12          -- frames to pair destroy→create (~0.4s @30fps)
local DETECT_RADIUS      = 64          -- elmos for "same spot" match
local RECENT_CREATE_WIN  = 6           -- tiny cache if Create arrives before Destroy

--------------------------------------------------------------------------------
-- Locals / helpers
--------------------------------------------------------------------------------
local spGetMyTeamID     = Spring.GetMyTeamID
local spGetUnitPosition = Spring.GetUnitPosition
local spPlaySoundFile   = Spring.PlaySoundFile
local spEcho            = Spring.Echo
local VFSFileExists     = VFS.FileExists

local function SystemText(msg)
  if SHOW_TEXT then
    spEcho("game_message: " .. msg)
  end
end

-- Queued playback: uses the shared VoiceBus if available; otherwise falls back.
local function SafePlay(path)
  if not path or path == "" then return end
  if not VFSFileExists(path) then return end
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    -- Queue-only behavior: never drops; clips play back-to-back with other alert widgets.
    WG.VoiceBus.play(path, {
      volume = VOLUME,
      -- channel = "ui",    -- (optional) uncomment to route under a specific mixer slider
      -- key = "chassis_alerts", cooldown = 0, priority = 0, -- (optional) dedupe if desired later
    })
  else
    spPlaySoundFile(path, VOLUME)
  end
end

local function Dist2DSq(x1,z1, x2,z2)
  local dx, dz = (x1 - x2), (z1 - z2)
  return dx*dx + dz*dz
end

-- Commander fingerprint tolerant to ZK variants (stock/custom/campaign/captured)
local function IsCommanderDef(unitDefID)
  local ud = UnitDefs[unitDefID]; if not ud then return false end
  local cp = ud.customParams or {}
  if cp.iscommander or cp.commander or cp.commtype or cp.modularcomm or cp.dynamic_comm or cp.dyncomm then
    return true
  end
  local n = (ud.name or ""):lower()
  if n:find("commander", 1, true) or n:find("dyn", 1, true) then
    return true
  end
  return false
end

-- Replay-aware team relevance:
-- We follow the CURRENT viewed team (player you are watching in a replay),
-- which Spring exposes via GetMyTeamID(). When spectating, switching the watched player
-- changes this value; when playing, it’s your own team.
local function TeamIsCurrentView(teamID)
  local myTeam = spGetMyTeamID()
  if not teamID or myTeam == nil then return false end
  if myTeam < 0 then
    -- In rare cases some UIs report -1 when spectating without a selected player.
    -- To avoid cross-team spam, do not play anything if no team is being "watched".
    return false
  end
  return teamID == myTeam
end

--------------------------------------------------------------------------------
-- Detection state (UI-side pairing, no LuaRules access required)
--------------------------------------------------------------------------------
-- pendingDeaths[oldID] = {team=, x=, z=, expire=frame+DETECT_WINDOW}
local pendingDeaths = {}
-- recentCreates[i] = {unitID=, team=, x=, z=, expire=frame+RECENT_CREATE_WIN}
local recentCreates = {}

--------------------------------------------------------------------------------
-- UI Callins
--------------------------------------------------------------------------------
function widget:Initialize()
  -- Nothing to cache; we query GetMyTeamID() dynamically so replays follow the highlighted team.
end

-- Try match a created comm to a pending death (normal order)
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

-- Rare order: Destroy after Create (use tiny cache)
local function TryPairWithRecentCreate(team, x, z, nowFrame, radiusSq)
  local bestIdx, bestDist = nil, 1e30
  for i=1,#recentCreates do
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

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if not IsCommanderDef(unitDefID) then return end
  if not TeamIsCurrentView(unitTeam) then return end

  local x, y, z = spGetUnitPosition(unitID)
  if not x then x, z = 0, 0 end  -- LOS guard

  local now      = Spring.GetGameFrame()
  local radiusSq = DETECT_RADIUS * DETECT_RADIUS

  -- Normal order: Destroy then Create -> UPGRADE
  local bestOld = TryPairCreate(unitTeam, x, z, now, radiusSq)
  if bestOld then
    pendingDeaths[bestOld] = nil
    if options.alertUpgrade.value then
      SafePlay(SOUND_UPGRADE_PATH)
      SystemText("Upgrade Complete.")
    end
    return
  end

  -- Otherwise cache this Create briefly (for rare reversed order)
  recentCreates[#recentCreates+1] = {
    unitID = unitID, team = unitTeam, x = x or 0, z = z or 0,
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

  -- Rare order: Create came first → pair now => UPGRADE
  local idx = TryPairWithRecentCreate(unitTeam, x, z, now, radiusSq)
  if idx then
    if options.alertUpgrade.value then
      SafePlay(SOUND_UPGRADE_PATH)
      SystemText("Upgrade Complete.")
    end
    recentCreates[idx] = nil
    return
  end

  -- Otherwise, queue as maybe-death; confirm later if no matching Create appears
  pendingDeaths[unitID] = { team = unitTeam, x = x or 0, z = z or 0, expire = now + DETECT_WINDOW }
end

function widget:GameFrame(n)
  -- Confirm genuine deaths (no upgrade match within window)
  for oldID, pd in pairs(pendingDeaths) do
    if n > pd.expire then
      if options.alertDeath.value then
        SafePlay(SOUND_DEATH_PATH)
        SystemText("Commander Chassis Destroyed.")
      end
      pendingDeaths[oldID] = nil
    end
  end
  -- Clean recent-create cache
  for i = #recentCreates, 1, -1 do
    local rc = recentCreates[i]
    if not rc or n > rc.expire then
      recentCreates[i] = nil
    end
  end
end

-- Optional: if your UI environment triggers this when switching watched players,
-- you could use it for debugging. We query dynamically, so it's not required.
-- function widget:PlayerChanged(playerID)
--   local t = spGetMyTeamID()
--   spEcho("game_message: Now viewing team "..(t or -1))
-- end
