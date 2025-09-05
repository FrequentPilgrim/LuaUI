function widget:GetInfo()
  return {
    name      = "Air Rearm Filter",
    desc      = "Prunes rearm-needed aircraft from selection; can also select all rearm-needed aircraft.",
    author    = "FrequentPilgim",
    date      = "2025-08-29",
    license   = "GPLv2+",
    version   = "1.0",
    layer     = 0,
    enabled   = true,
  }
end

options_path = "Settings/Misc/Air Rearm Filter"

options = {
  selectAllRearmNeeded = {
    name = "Select All Rearm-Needed Aircraft",
    type = "button",
    desc = "Clear selection, then select ALL of your aircraft that currently need to rearm/refuel (icon state).",
    OnChange = function() SelectAllRearmNeeded() end,
  },
  runNow = {
    name = "Deselect Rearm-Needed Aircraft",
    type = "button",
    desc = "Remove aircraft that show the rearm-needed/no-payload icon from your CURRENT selection.",
    -- FIX: respect Console Messages toggle (no forced verbosity)
    OnChange = function() DeselectRearmNeeded(false, false) end,
  },
  autoFilter = {
    name = "Auto-filter On Selection Change",
    type = "bool",
    value = false,
    desc = "When enabled, whenever your selection changes, rearm-needed aircraft are removed.",
    noHotkey = false,
  },
  verbose = {
    name = "Console Messages",
    type = "bool",
    value = false,
    desc = "Show a short console message when actions run.",
    noHotkey = true,
  },
  neverEmpty = {
    name = "Never Empty Selection",
    type = "bool",
    value = true,
    desc = "When deselecting from *current* selection: if every selected air needs rearm, keep the selection unchanged.",
    noHotkey = true,
  },
}

local spGetSelectedUnits   = Spring.GetSelectedUnits
local spGetTeamUnits       = Spring.GetTeamUnits
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetUnitDefID       = Spring.GetUnitDefID
local spGetUnitRulesParam  = Spring.GetUnitRulesParam
local spSelectUnitArray    = Spring.SelectUnitArray
local Echo                 = Spring.Echo

local function IsAir(udid)
  local ud = udid and UnitDefs[udid]
  return ud and ud.canFly
end

local REARM_RULE_KEYS = { "rearm", "wantPad", "padWait", "padWanted", "needsRefuel", "needsReload", "noammo" }

local function PlaneNeedsRearm(unitID)
  for i = 1, #REARM_RULE_KEYS do
    local v = spGetUnitRulesParam(unitID, REARM_RULE_KEYS[i])
    if v and v ~= 0 then return true end
  end
  return false
end

local function isVerbose()
  return options and options.verbose and options.verbose.value
end

function DeselectRearmNeeded(quiet, forceVerbose)
  local sel = spGetSelectedUnits()
  if not sel or #sel == 0 then return end

  local keep, removed = {}, 0
  for i = 1, #sel do
    local u = sel[i]
    local udid = spGetUnitDefID(u)
    if udid and IsAir(udid) and PlaneNeedsRearm(u) then
      removed = removed + 1
    else
      keep[#keep + 1] = u
    end
  end

  if removed > 0 then
    if options.neverEmpty and options.neverEmpty.value and (#keep == 0) then
      if (not quiet and isVerbose()) or forceVerbose then
        Echo("game_message: All selected aircraft are rearm-needed; leaving selection unchanged.")
      end
      return
    end
    spSelectUnitArray(keep, false)
    if (not quiet and isVerbose()) or forceVerbose then
      Echo(("game_message: Removed %d rearm-needed aircraft from selection."):format(removed))
    end
  else
    if (not quiet and isVerbose()) or forceVerbose then
      Echo("game_message: No rearm-needed aircraft in current selection.")
    end
  end
end

function SelectAllRearmNeeded()
  local teamID = spGetMyTeamID()
  if not teamID then return end

  local units = spGetTeamUnits(teamID)
  local pick = {}

  for i = 1, (units and #units or 0) do
    local u = units[i]
    local udid = spGetUnitDefID(u)
    if udid and IsAir(udid) and PlaneNeedsRearm(u) then
      pick[#pick + 1] = u
    end
  end

  spSelectUnitArray(pick, false)
  if isVerbose() then
    Echo(#pick > 0 and ("game_message: Selected %d rearm-needed aircraft."):format(#pick)
                 or "game_message: No rearm-needed aircraft to select.")
  end
end

function widget:Initialize()
  widgetHandler:AddAction("deselect_air_reload", function()
    DeselectRearmNeeded(false, false)
  end, nil, "t")

  widgetHandler:AddAction("toggle_air_rearm_autofilter", function()
    if options and options.autoFilter then
      options.autoFilter.value = not options.autoFilter.value
      if isVerbose() then
        Echo("game_message: Auto-filter " .. (options.autoFilter.value and "ENABLED" or "DISABLED") .. ".")
      end
    end
  end, nil, "t")
end

function widget:Shutdown()
  widgetHandler:RemoveAction("deselect_air_reload")
  widgetHandler:RemoveAction("toggle_air_rearm_autofilter")
end

function widget:SelectionChanged()
  if options and options.autoFilter and options.autoFilter.value then
    DeselectRearmNeeded(true, false)
  end
end
