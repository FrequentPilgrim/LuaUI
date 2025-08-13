function widget:GetInfo()
  return {
    name    = "Audio Alert - Economy Sustaining Damage",
    desc    = "Alerts if any key energy structure (Fusion, Singularity, Geo, Adv. Geo) takes 100+ cumulative damage within 31s",
    author  = "FrequentPilgrim",
    date    = "2025-06-11",
    license = "GNU GPL v2",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local soundFile = "LuaUI/Sounds/economysustainingdamage.ogg"
local soundVolume = 3.0
local delayFrames = 30       -- 1 seconds at 30 FPS
local cooldownFrames = 930   -- 31 seconds at 30 FPS

local lastAlertFrame = -math.huge
local pendingAlertFrame = nil

local myTeamID = Spring.GetMyTeamID()
local enabled = true

--------------------------------------------------------------------------------
-- Watched unitDef IDs
--------------------------------------------------------------------------------

local watchedDefs = {
  "energyfusion",
  "energysingu",
  "energygeo",
  "energyheavygeo",
}

local watchedDefIDs = {}
for _, defName in ipairs(watchedDefs) do
  local def = UnitDefNames[defName]
  if def then
    watchedDefIDs[def.id] = true
  end
end

--------------------------------------------------------------------------------
-- Damage Tracking
--------------------------------------------------------------------------------

local unitDamage = {}  -- [unitID] = cumulativeDamage

function widget:Initialize()
  if Spring.IsReplay() or Spring.GetSpectatingState() then
    enabled = false
  end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  if not enabled then return end
  if unitTeam ~= myTeamID then return end
  if not watchedDefIDs[unitDefID] then return end
  if paralyzer then return end
  if Spring.GetGameFrame() < lastAlertFrame + cooldownFrames then return end
  if pendingAlertFrame then return end

  unitDamage[unitID] = (unitDamage[unitID] or 0) + damage

  if unitDamage[unitID] >= 100 then
    pendingAlertFrame = Spring.GetGameFrame() + delayFrames
  end
end

function widget:GameFrame(n)
  if not enabled then return end

  if pendingAlertFrame and n >= pendingAlertFrame then
    Spring.PlaySoundFile(soundFile, soundVolume, "ui")
    lastAlertFrame = n
    pendingAlertFrame = nil
    unitDamage = {}
  end

  if n == lastAlertFrame + cooldownFrames then
    unitDamage = {}
  end
end
