function widget:GetInfo()
    return {
        name    = "Mouse Circle Unit Filter",
        desc    = "Selects nearby units around mouse while Forward button held, filters by gui_Letter_Auto_groups",
        author  = "FrequentPilgrim + ChatGPT",
        date    = "2025-06-13",
        license = "GNU GPL v2",
        layer   = 1,
        enabled = true
    }
end

-- === Config ===
local RADIUS = 450
local MOUSE_BUTTON = 5 -- Forward mouse button

-- === State ===
local selecting = false
local filteringActive = false
local cursorX, cursorY = 0, 0
local lastSelectedUnits = {}
local activeLetters = {}
local hasSelectedUnits = false
local shiftHeld = false
local ctrlHeld = false

-- === Key mapping: a-z to A-Z ===
local keycodeToLetter = {}
for i = 65, 90 do
    local ch = string.char(i)
    keycodeToLetter[Spring.GetKeyCode(ch:lower())] = ch
end

-- === Drawing helpers ===
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest

local function DrawWorldCircle(cx, cy, cz, radius, segments)
    segments = segments or 64
    local radStep = 2 * math.pi / segments
    glBeginEnd(GL.LINE_LOOP, function()
        for i = 0, segments - 1 do
            local a = i * radStep
            glVertex(cx + math.cos(a) * radius, cy + 1, cz + math.sin(a) * radius)
        end
    end)
end

-- === Helpers ===
local function GetUnitsInCircle(x, y)
    local type, coord = Spring.TraceScreenRay(x, y, true)
    if type ~= "ground" or not coord then return {}, nil, nil, nil end
    local gx, gy, gz = coord[1], coord[2], coord[3]
    return Spring.GetUnitsInCylinder(gx, gz, RADIUS, Spring.GetMyTeamID()), gx, gy, gz
end

-- === Mouse handling ===
function widget:MousePress(x, y, button)
    if button == MOUSE_BUTTON then
        local alt, ctrl, meta, shift = Spring.GetModKeyState()
        shiftHeld = shift
        ctrlHeld = ctrl

        selecting = true
        filteringActive = false
        cursorX, cursorY = x, y
        activeLetters = {}
        lastSelectedUnits = {}
        hasSelectedUnits = false

        if shiftHeld then
            local current = Spring.GetSelectedUnits()
            if current and #current > 0 then
                for _, id in ipairs(current) do
                    lastSelectedUnits[id] = true
                end
                hasSelectedUnits = true
            end
        else
            Spring.SelectUnitArray({}, false)  -- clear selection
        end

        return true
    elseif selecting then
        selecting = false
        filteringActive = false
    end
end

function widget:MouseRelease(_, _, button)
    if button == MOUSE_BUTTON then
        selecting = false
        filteringActive = false
        return true
    end
end

function widget:Update()
    if selecting and not filteringActive then
        local mx, my = Spring.GetMouseState()
        cursorX, cursorY = mx, my

        local newUnits, gx, gy, gz = GetUnitsInCircle(mx, my)
        local newlyAdded = {}

        for _, unitID in ipairs(newUnits) do
            local isIdle = true
            if ctrlHeld then
                -- Exclude buildings and only select idle units
                local udid = Spring.GetUnitDefID(unitID)
                if not udid then
                    isIdle = false
                else
                    local ud = UnitDefs[udid]
                    if ud.isBuilding then
                        isIdle = false
                    else
                        local cmdQueue = Spring.GetCommandQueue(unitID, 1)
                        isIdle = (cmdQueue == nil or #cmdQueue == 0)
                    end
                end
            end

            if isIdle and not lastSelectedUnits[unitID] then
                lastSelectedUnits[unitID] = true
                table.insert(newlyAdded, unitID)
            end
        end

        if #newlyAdded > 0 then
            local current = Spring.GetSelectedUnits()
            for _, id in ipairs(current) do
                lastSelectedUnits[id] = true
            end
            Spring.SelectUnitArray(current, false)
            Spring.SelectUnitArray(newlyAdded, true)
            hasSelectedUnits = true
        end
    end
end

function widget:KeyPress(key, mods, isRepeat)
    if not selecting then return false end

    local letter = keycodeToLetter[key]
    if not letter then return false end

    local groupTable = WG.LetterUnitTypeMultiAutoGroups
    if not groupTable then
        Spring.Echo("[MouseCircleFilter] Letter group table not available")
        return false
    end

    local defNameSet = groupTable[letter]
    if not defNameSet then
        Spring.Echo("[MouseCircleFilter] No group assigned to letter " .. letter)
        return true
    end

    activeLetters[letter] = true
    filteringActive = true

    local selected = {}
    for unitID in pairs(lastSelectedUnits) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid then
            local defName = UnitDefs[udid].name
            for activeLetter in pairs(activeLetters) do
                local defs = groupTable[activeLetter]
                if defs and defs[defName] then
                    table.insert(selected, unitID)
                    break
                end
            end
        end
    end

    Spring.SelectUnitArray(selected, false)
    local activeKeys = {}
    for k in pairs(activeLetters) do table.insert(activeKeys, k) end
    Spring.Echo(string.format("[MouseCircleFilter] Filtered to %d units in group(s): %s", #selected, table.concat(activeKeys, ", ")))

    return true
end

function widget:DrawWorld()
    if selecting then
        local units, gx, gy, gz = GetUnitsInCircle(cursorX, cursorY)
        if gx and gy and gz then
            if shiftHeld then
                glColor(0.2, 1, 0.2, 0.8) -- green for shift-held
            elseif ctrlHeld then
                glColor(1.0, 1.0, 0.2, 0.8) -- yellow for ctrl-held (idle-only, no buildings)
            else
                glColor(0.5, 0.8, 1, 0.8) -- light blue default
            end
            glLineWidth(4)
            glDepthTest(true)
            DrawWorldCircle(gx, gy, gz, RADIUS)
            glDepthTest(false)
            glColor(1, 1, 1, 1)
        end
    end
end
--------------------------------------------------------------------------------
-- CIRCLE FILTER OPTIONS (additive, no-regress)
-- Menu Path: Settings/Misc/Circle Filter
-- Paste this block at the BOTTOM of unit_circle_letter_filter34.lua
--------------------------------------------------------------------------------

options = options or {}
options_order = options_order or {}

local OPTIONS_PATH = "Settings/Misc/Circle Filter"

-- Preserve your current default radius without changing behavior
local DEFAULT_RADIUS = RADIUS or 450

-- Master enable/disable toggle (defaults ON to preserve current behavior)
if not options.circleFilterEnable then
  options.circleFilterEnable = {
    name  = "Enable Circle Filter",
    desc  = "Turn this widget's functionality on or off",
    type  = "bool",
    path  = OPTIONS_PATH,
    value = true,
  }
  options_order[#options_order + 1] = "circleFilterEnable"
end

-- Circle size slider (defaults to your existing RADIUS)
if not options.circleRadius then
  options.circleRadius = {
    name  = "Circle Radius",
    desc  = "Size of the selection circle (world units)",
    type  = "number",
    path  = OPTIONS_PATH,
    min   = 100,   -- adjust bounds if you like
    max   = 2000,
    step  = 10,
    value = DEFAULT_RADIUS,
  }
  options_order[#options_order + 1] = "circleRadius"
end

-- Helpers
local function CircleFilter_IsEnabled()
  return not options.circleFilterEnable or options.circleFilterEnable.value ~= false
end

local function CircleFilter_GetRadius()
  local v = options.circleRadius and options.circleRadius.value
  return (v and v > 0 and v) or DEFAULT_RADIUS
end

-- Explicit persistence (merges with your existing handlers if present)
local _GetConfigData = widget.GetConfigData
function widget:GetConfigData()
  local data = _GetConfigData and _GetConfigData(self) or {}
  data._circle_filter_opts = {
    enable = options.circleFilterEnable and options.circleFilterEnable.value or true,
    radius = options.circleRadius and options.circleRadius.value or DEFAULT_RADIUS,
  }
  return data
end

local _SetConfigData = widget.SetConfigData
function widget:SetConfigData(data)
  if _SetConfigData then _SetConfigData(self, data) end
  local d = data and data._circle_filter_opts
  if d then
    if options.circleFilterEnable and d.enable ~= nil then
      options.circleFilterEnable.value = d.enable
    end
    if options.circleRadius and d.radius then
      options.circleRadius.value = d.radius
    end
  end
end

--------------------------------------------------------------------------------
-- Callin Wrappers (gate behavior + keep RADIUS synced). No changes to your logic.
--------------------------------------------------------------------------------
local _MousePress   = widget.MousePress
local _MouseRelease = widget.MouseRelease
local _Update       = widget.Update
local _KeyPress     = widget.KeyPress
local _DrawWorld    = widget.DrawWorld

function widget:MousePress(...)
  if not CircleFilter_IsEnabled() then return false end
  if _MousePress then return _MousePress(self, ...) end
  return false
end

function widget:MouseRelease(...)
  if not CircleFilter_IsEnabled() then return false end
  if _MouseRelease then return _MouseRelease(self, ...) end
  return false
end

function widget:Update(...)
  -- Keep your internal RADIUS in sync with the slider (zero churn elsewhere)
  RADIUS = CircleFilter_GetRadius()

  if not CircleFilter_IsEnabled() then
    -- Graceful pause of the feature without altering player selection.
    -- (These locals exist in your base and are accessible here.)
    if selecting ~= nil then selecting = false end
    if filteringActive ~= nil then filteringActive = false end
    return
  end
  if _Update then return _Update(self, ...) end
end

function widget:KeyPress(...)
  if not CircleFilter_IsEnabled() then return false end
  if _KeyPress then return _KeyPress(self, ...) end
  return false
end

function widget:DrawWorld(...)
  if not CircleFilter_IsEnabled() then return end
  if _DrawWorld then return _DrawWorld(self, ...) end
end

--------------------------------------------------------------------------------
-- END CIRCLE FILTER OPTIONS
--------------------------------------------------------------------------------
