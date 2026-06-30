function widget:GetInfo()
    return {
        name    = "Mouse Circle Unit Filter",
        desc    = "Hold Forward mouse button to draw a selection circle. Press a letter while held to filter to that letter group. Shift=add to selection, Ctrl=idle units only.",
        author  = "FrequentPilgrim",
        date    = "2025-06-13",
        license = "MIT",
        layer   = 1,
        enabled = true
    }
end

-- === Config ===
local debugMode    = false   -- set true to enable console feedback
local MOUSE_BUTTON = 5       -- Forward mouse button

-- === Options (Epic Menu) ===
options       = options or {}
options_order = options_order or {}

local OPTIONS_PATH   = "Settings/Misc/Circle Filter"
local DEFAULT_RADIUS = 450

options.circleFilterEnable = {
    name  = "Enable Circle Filter",
    desc  = "Turn this widget on or off.",
    type  = "bool",
    path  = OPTIONS_PATH,
    value = true,
}
options.circleRadius = {
    name  = "Circle Radius",
    desc  = "Size of the selection circle (world units).",
    type  = "number",
    path  = OPTIONS_PATH,
    min   = 100,
    max   = 2000,
    step  = 10,
    value = DEFAULT_RADIUS,
}
options_order[#options_order + 1] = "circleFilterEnable"
options_order[#options_order + 1] = "circleRadius"

-- === State ===
local RADIUS      = DEFAULT_RADIUS
local selecting   = false
local filteringActive = false
local cursorX, cursorY = 0, 0
local lastSelectedUnits = {}
local activeLetters = {}
local hasSelectedUnits = false
local shiftHeld   = false
local ctrlHeld    = false

-- === Key mapping ===
local keycodeToLetter = {}
for i = 65, 90 do
    local ch = string.char(i)
    keycodeToLetter[Spring.GetKeyCode(ch:lower())] = ch
end

-- === Drawing helpers ===
local glColor      = gl.Color
local glLineWidth  = gl.LineWidth
local glBeginEnd   = gl.BeginEnd
local glVertex     = gl.Vertex
local glDepthTest  = gl.DepthTest

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
local function IsEnabled()
    return not options.circleFilterEnable or options.circleFilterEnable.value ~= false
end

local function GetRadius()
    local v = options.circleRadius and options.circleRadius.value
    return (v and v > 0 and v) or DEFAULT_RADIUS
end

local function GetUnitsInCircle(x, y)
    local t, coord = Spring.TraceScreenRay(x, y, true)
    if t ~= "ground" or not coord then return {}, nil, nil, nil end
    local gx, gy, gz = coord[1], coord[2], coord[3]
    return Spring.GetUnitsInCylinder(gx, gz, RADIUS, Spring.GetMyTeamID()), gx, gy, gz
end

-- === Config persistence ===
function widget:GetConfigData()
    return {
        circleFilterEnable = options.circleFilterEnable and options.circleFilterEnable.value or true,
        circleRadius       = options.circleRadius and options.circleRadius.value or DEFAULT_RADIUS,
    }
end

function widget:SetConfigData(data)
    if type(data) ~= "table" then return end
    if data.circleFilterEnable ~= nil and options.circleFilterEnable then
        options.circleFilterEnable.value = data.circleFilterEnable and true or false
    end
    if data.circleRadius and options.circleRadius then
        local v = tonumber(data.circleRadius) or DEFAULT_RADIUS
        v = math.max(options.circleRadius.min, math.min(options.circleRadius.max, v))
        options.circleRadius.value = v
    end
end

-- === Mouse handling ===
function widget:MousePress(x, y, button)
    if not IsEnabled() then return false end
    if button == MOUSE_BUTTON then
        local _, ctrl, _, shift = Spring.GetModKeyState()
        shiftHeld = shift
        ctrlHeld  = ctrl

        selecting       = true
        filteringActive = false
        cursorX, cursorY = x, y
        activeLetters   = {}
        lastSelectedUnits = {}
        hasSelectedUnits  = false

        if shiftHeld then
            local current = Spring.GetSelectedUnits()
            if current and #current > 0 then
                for _, id in ipairs(current) do
                    lastSelectedUnits[id] = true
                end
                hasSelectedUnits = true
            end
        else
            Spring.SelectUnitArray({}, false)
        end

        return true
    elseif selecting then
        selecting       = false
        filteringActive = false
    end
end

function widget:MouseRelease(_, _, button)
    if not IsEnabled() then return false end
    if button == MOUSE_BUTTON then
        selecting       = false
        filteringActive = false
        return true
    end
end

function widget:Update()
    RADIUS = GetRadius()

    if not IsEnabled() then
        if selecting then
            selecting       = false
            filteringActive = false
        end
        return
    end

    if selecting and not filteringActive then
        local mx, my = Spring.GetMouseState()
        cursorX, cursorY = mx, my

        local newUnits, gx, gy, gz = GetUnitsInCircle(mx, my)
        local newlyAdded = {}

        for _, unitID in ipairs(newUnits) do
            local isIdle = true
            if ctrlHeld then
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
    if not IsEnabled() then return false end
    if not selecting then return false end

    local letter = keycodeToLetter[key]
    if not letter then return false end

    local groupTable = WG.LetterUnitTypeMultiAutoGroups
    if not groupTable then
        if debugMode then
            Spring.Echo("[CircleFilter] Letter group table not available")
        end
        return false
    end

    local defNameSet = groupTable[letter]
    if not defNameSet then
        if debugMode then
            Spring.Echo("[CircleFilter] No group assigned to letter " .. letter)
        end
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

    if debugMode then
        local activeKeys = {}
        for k in pairs(activeLetters) do table.insert(activeKeys, k) end
        Spring.Echo(string.format("[CircleFilter] Filtered to %d units in group(s): %s",
            #selected, table.concat(activeKeys, ", ")))
    end

    return true
end

function widget:DrawWorld()
    if not IsEnabled() then return end
    if not selecting then return end

    local units, gx, gy, gz = GetUnitsInCircle(cursorX, cursorY)
    if gx and gy and gz then
        if shiftHeld then
            glColor(0.2, 1, 0.2, 0.8)
        elseif ctrlHeld then
            glColor(1.0, 1.0, 0.2, 0.8)
        else
            glColor(0.5, 0.8, 1, 0.8)
        end
        glLineWidth(4)
        glDepthTest(true)
        DrawWorldCircle(gx, gy, gz, RADIUS)
        glDepthTest(false)
        glColor(1, 1, 1, 1)
    end
end
