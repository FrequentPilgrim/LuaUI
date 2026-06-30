function widget:GetInfo()
  return {
    name    = "Economy Sustaining Damage Audio Alert",
    desc    = "Plays an alert sound when a key energy structure (Fusion, Singularity, Geo, Adv. Geo) takes 100+ cumulative damage within ~31 seconds.",
    author  = "FrequentPilgrim",
    date    = "2025-06-11",
    license = "MIT",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Epic Menu
--------------------------------------------------------------------------------
options_path  = "Settings/Audio/Audio Alerts"
options_order = { "enableEconomyDamageAlert", "economyDamageAlertSpec" }

options = {
  enableEconomyDamageAlert = {
    name  = "Economy Sustaining Damage",
    desc  = "Play an alert sound when a key energy structure sustains significant damage.",
    type  = "bool",
    value = true,
  },
  economyDamageAlertSpec = {
    name  = "Enable in Spectator / Replay",
    desc  = "Also play this alert when spectating or watching a replay.",
    type  = "bool",
    value = false,
  },
}

function widget:GetConfigData()
  return {
    enableEconomyDamageAlert = options.enableEconomyDamageAlert.value,
    economyDamageAlertSpec   = options.economyDamageAlertSpec.value,
  }
end

function widget:SetConfigData(data)
  if not data then return end
  if data.enableEconomyDamageAlert ~= nil then options.enableEconomyDamageAlert.value = data.enableEconomyDamageAlert end
  if data.economyDamageAlertSpec   ~= nil then options.economyDamageAlertSpec.value   = data.economyDamageAlertSpec   end
end

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local SOUND_FILE      = "LuaUI/Sounds/economy_sustaining_damage.ogg"
local SOUND_VOLUME    = 3.0
local COOLDOWN_FRAMES = 930   -- ~31 seconds
local DELAY_FRAMES    = 0
local DAMAGE_THRESHOLD = 100

--------------------------------------------------------------------------------
-- Watched unit def names
--------------------------------------------------------------------------------
local WATCHED_DEFS = {
  "energyfusion",
  "energysingu",
  "energygeo",
  "energyheavygeo",
}

--------------------------------------------------------------------------------
-- Locals
--------------------------------------------------------------------------------
local GetMyTeamID        = Spring.GetMyTeamID
local GetGameFrame       = Spring.GetGameFrame
local PlaySoundFile      = Spring.PlaySoundFile
local GetSpectatingState = Spring.GetSpectatingState

local myTeamID = nil

local watchedDefIDs = {}
for _, defName in ipairs(WATCHED_DEFS) do
  local def = UnitDefNames[defName]
  if def then watchedDefIDs[def.id] = true end
end

local lastSoundFrame    = -math.huge
local pendingAlertFrame = nil
local unitDamage        = {}

local function FeatureEnabled() return options.enableEconomyDamageAlert.value end
local function spec_ok()
  local _,_,isSpec,_,_,isReplay = GetSpectatingState()
  if not (isSpec or isReplay) then return true end
  return options.economyDamageAlertSpec.value
end

local function SafePlay(path, vol)
  if WG and WG.VoiceBus and WG.VoiceBus.play then
    WG.VoiceBus.play(path, { volume = vol, channel = "ui" })
  else
    PlaySoundFile(path, vol, nil, nil, nil, nil, nil, nil, "ui")
  end
end

--------------------------------------------------------------------------------
-- Engine hooks
--------------------------------------------------------------------------------
function widget:Initialize()
  myTeamID = GetMyTeamID()
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  if not FeatureEnabled() then return end
  if not spec_ok() then return end
  if unitTeam ~= myTeamID then return end
  if not watchedDefIDs[unitDefID] then return end
  if paralyzer then return end

  local f = GetGameFrame()
  if f < lastSoundFrame + COOLDOWN_FRAMES then return end
  if pendingAlertFrame then return end

  unitDamage[unitID] = (unitDamage[unitID] or 0) + damage

  if unitDamage[unitID] >= DAMAGE_THRESHOLD then
    pendingAlertFrame = f + DELAY_FRAMES
  end
end

function widget:GameFrame(n)
  if not FeatureEnabled() then return end
  if not spec_ok() then return end

  if pendingAlertFrame and n >= pendingAlertFrame then
    SafePlay(SOUND_FILE, SOUND_VOLUME)
    lastSoundFrame    = n
    pendingAlertFrame = nil
    unitDamage        = {}
  end

  if n == lastSoundFrame + COOLDOWN_FRAMES then
    unitDamage = {}
  end
end
