function widget:GetInfo()
  return {
    name    = "economy_sustaining_damage Audio Alert",
    desc    = "Alerts if any key energy structure (Fusion, Singularity, Geo, Adv. Geo) takes 100+ cumulative damage within ~31s",
    author  = "FrequentPilgrim",
    date    = "2025-06-11",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu Toggle
--------------------------------------------------------------------------------
options = options or {}
options.economy_sustaining_damage = {
  name  = "Economy Sustaining Damage",
  desc  = "Play an alert when key energy structures sustain significant damage.",
  type  = "bool",
  value = true,
  path  = "Settings/Audio/Audio Alerts",
}

function widget:GetConfigData()
  return {
    economy_sustaining_damage = options.economy_sustaining_damage
      and options.economy_sustaining_damage.value or true,
  }
end

function widget:SetConfigData(data)
  if data and data.economy_sustaining_damage ~= nil
     and options and options.economy_sustaining_damage then
    options.economy_sustaining_damage.value = data.economy_sustaining_damage
  end
end

local function FeatureEnabled()
  return options and options.economy_sustaining_damage
     and options.economy_sustaining_damage.value
end

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

--------------------------------------------------------------------------------
-- Configuration (preserved)
--------------------------------------------------------------------------------
local soundFile       = "LuaUI/Sounds/economy_sustaining_damage.ogg"
local soundVolume     = 3.0
local delayFrames     = 0        -- 0 seconds at 30 FPS
local cooldownFrames  = 930      -- ~31 seconds at 30 FPS

local lastAlertFrame    = -math.huge
local pendingAlertFrame = nil

local myTeamID = Spring.GetMyTeamID()

--------------------------------------------------------------------------------
-- Watched unitDef IDs (preserved)
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
-- Damage Tracking (preserved)
--------------------------------------------------------------------------------
local unitDamage = {}  -- [unitID] = cumulativeDamage

function widget:Initialize()
  if not VFS.FileExists(soundFile) then
    widgetHandler:RemoveWidget(self)
  end
end

-- Queue-aware playback helper: use WG.VoiceBus if available, else fallback.
local function SafePlay(path, vol)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    -- Queue-only behavior (no drops): will enqueue behind other alerts.
    WG.VoiceBus.play(path, {
      volume  = vol,
      channel = "ui",  -- keep intended mixer routing consistent with original intent
      -- key = "economy_sustaining_damage", cooldown = 0, priority = 0, -- (optional) dedupe later if desired
    })
  else
    -- Fallback to direct playback (kept simple; no behavioral knobs added)
    Spring.PlaySoundFile(path, vol)
    -- If you prefer explicit channel routing on fallback, use:
    -- Spring.PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  if not FeatureEnabled() or not play_ok() then return end
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
  if not FeatureEnabled() or not play_ok() then return end

  if pendingAlertFrame and n >= pendingAlertFrame then
    -- ROUTED THROUGH QUEUE: enqueues behind other alert widgets to avoid overlap
    SafePlay(soundFile, soundVolume)
    lastAlertFrame    = n
    pendingAlertFrame = nil
    unitDamage        = {}
  end

  if n == lastAlertFrame + cooldownFrames then
    unitDamage = {}
  end
end
