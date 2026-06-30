function widget:GetInfo()
    return {
        name    = "Single Unit Selector",
        desc    = "Hold Mouse Back (button 4) then press a letter to select the nearest unit of that letter group. Each press cycles to the next nearest. Ctrl also issues a move order.",
        author  = "FrequentPilgrim",
        date    = "2025-06-13",
        license = "MIT",
        layer   = 0,
        enabled = true,
    }
end

local debugMode = false   -- set true for console feedback

------------------------------------------------------------
-- Locals
------------------------------------------------------------
local Spring = Spring
local gl     = gl
local GL     = GL
local CMD    = CMD
local math   = math

local MOUSE_BACK_BUTTON = 4
local mouseBackHeld     = false
local selectedUnitsThisCycle      = {}
local lastSelectedUnitPositions   = {}
local drawTimer = 0
local shiftHeld = false
local ctrlHeld  = false
local hasClearedSelectionThisCycle = false

-- Sparkle animation state
local sparklePhase = 0
local huePhase     = 0
local ARMS         = 12

-- Keycode mapping
local keycodeToLetter = {}
for i = 65, 90 do
    local ch = string.char(i)
    keycodeToLetter[Spring.GetKeyCode(ch:lower())] = ch
end

------------------------------------------------------------
-- Epic Menu Options
------------------------------------------------------------
options_order = options_order or {}
options       = options or {}

local OPT_PATH = "Settings/Misc/Single Unit Selector"

local function _append_order(key)
    for i = 1, #options_order do
        if options_order[i] == key then return end
    end
    options_order[#options_order + 1] = key
end

if not options.enabled then
    options.enabled = {
        name  = "Enable",
        type  = "bool",
        value = true,
        path  = OPT_PATH,
        desc  = "Enable or disable this widget.",
        OnChange = function(self)
            if self.value == false then
                mouseBackHeld = false
                selectedUnitsThisCycle = {}
                lastSelectedUnitPositions = {}
                drawTimer = 0
                hasClearedSelectionThisCycle = false
            end
        end,
    }
    _append_order("enabled")
end

if not options.sparkleIndicator then
    options.sparkleIndicator = {
        name  = "Show Mouse Sparkle (held Back)",
        type  = "bool",
        value = true,
        path  = OPT_PATH,
        desc  = "Draw a sparkling indicator under the cursor while holding the Back mouse button.",
    }
    _append_order("sparkleIndicator")
end

if not options.sparkleSize then
    options.sparkleSize = {
        name   = "Sparkle Size (px)",
        type   = "number",
        min    = 6,
        max    = 150,
        step   = 1,
        value  = 40,
        path   = OPT_PATH,
        desc   = "Radius in screen pixels of the sparkle indicator.",
    }
    _append_order("sparkleSize")
end

local function Enabled()
    return (options and options.enabled and options.enabled.value) ~= false
end

local function SparkleRadius()
    local r = (options.sparkleSize and options.sparkleSize.value) or 40
    return (r >= 1) and r or 1
end

------------------------------------------------------------
-- Config persistence
------------------------------------------------------------
function widget:GetConfigData()
    return {
        enabled          = (options.enabled and options.enabled.value) ~= false,
        sparkleIndicator = (options.sparkleIndicator and options.sparkleIndicator.value) == true,
        sparkleSize      = (options.sparkleSize and options.sparkleSize.value) or 40,
    }
end

function widget:SetConfigData(data)
    if type(data) ~= "table" then return end
    if options.enabled and data.enabled ~= nil then
        options.enabled.value = data.enabled and true or false
    end
    if options.sparkleIndicator and data.sparkleIndicator ~= nil then
        options.sparkleIndicator.value = data.sparkleIndicator and true or false
    end
    if options.sparkleSize and data.sparkleSize ~= nil then
        local v = tonumber(data.sparkleSize) or 40
        v = math.max(options.sparkleSize.min, math.min(options.sparkleSize.max, v))
        options.sparkleSize.value = v
    end
end

------------------------------------------------------------
-- Mouse handling
------------------------------------------------------------
function widget:MousePress(x, y, button)
    if not Enabled() then return false end
    if button == MOUSE_BACK_BUTTON then
        mouseBackHeld = true
        selectedUnitsThisCycle = {}
        hasClearedSelectionThisCycle = false
        return true
    else
        if mouseBackHeld then
            mouseBackHeld = false
            selectedUnitsThisCycle = {}
            hasClearedSelectionThisCycle = false
        end
    end
    return false
end

function widget:MouseRelease(x, y, button)
    if not Enabled() then return false end
    if button == MOUSE_BACK_BUTTON then
        mouseBackHeld = false
        selectedUnitsThisCycle = {}
        hasClearedSelectionThisCycle = false
        return true
    end
    return false
end

------------------------------------------------------------
-- Key handling
------------------------------------------------------------
function widget:KeyPress(key, mods, isRepeat)
    if not Enabled() then return false end
    if not mouseBackHeld then return false end

    local letter = keycodeToLetter[key]
    if not letter then return false end

    local groupTable = WG.LetterUnitTypeMultiAutoGroups
    if not groupTable then
        if debugMode then
            Spring.Echo("[SingleUnitSelector] WG.LetterUnitTypeMultiAutoGroups is missing.")
        end
        return false
    end

    local defNames = groupTable[letter]
    if not defNames then
        if debugMode then
            Spring.Echo("[SingleUnitSelector] No units assigned to letter group: " .. letter)
        end
        return true
    end

    shiftHeld = mods.shift
    ctrlHeld  = mods.ctrl

    local mx, my = Spring.GetMouseState()
    local t, pos = Spring.TraceScreenRay(mx, my, true)
    if t ~= "ground" or not pos then
        if debugMode then
            Spring.Echo("[SingleUnitSelector] Mouse not over ground.")
        end
        return true
    end

    local allUnits = Spring.GetAllUnits()
    local myTeam   = Spring.GetMyTeamID()
    local cx, cy, cz = pos[1], pos[2], pos[3]
    local candidates = {}

    for _, unitID in ipairs(allUnits) do
        if Spring.GetUnitTeam(unitID) == myTeam then
            local udid = Spring.GetUnitDefID(unitID)
            if udid then
                local defName = UnitDefs[udid].name
                if defNames[defName] then
                    if not selectedUnitsThisCycle[unitID]
                       and (not shiftHeld or not Spring.IsUnitSelected(unitID)) then
                        local isIdle = (#Spring.GetUnitCommands(unitID, 1) == 0)
                        if not ctrlHeld or isIdle then
                            local ux, uy, uz = Spring.GetUnitPosition(unitID)
                            local distSq = (ux - cx)^2 + (uz - cz)^2
                            candidates[#candidates + 1] = {
                                id   = unitID,
                                dist = distSq,
                                pos  = { ux, uy, uz }
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(a, b) return a.dist < b.dist end)

    local unitsToSelect         = {}
    local newlySelectedPositions = {}

    for i = 1, math.min(1, #candidates) do
        local candidate = candidates[i]
        unitsToSelect[#unitsToSelect + 1]           = candidate.id
        newlySelectedPositions[#newlySelectedPositions + 1] = candidate.pos
        selectedUnitsThisCycle[candidate.id]         = true

        if ctrlHeld then
            Spring.GiveOrderToUnit(candidate.id, CMD.MOVE, { cx, cy, cz }, {})
        end
    end

    if #unitsToSelect > 0 then
        if shiftHeld then
            Spring.SelectUnitArray(unitsToSelect, true)
        else
            if not hasClearedSelectionThisCycle then
                Spring.SelectUnitArray(unitsToSelect, false)
                hasClearedSelectionThisCycle = true
            else
                Spring.SelectUnitArray(unitsToSelect, true)
            end
        end

        lastSelectedUnitPositions = newlySelectedPositions
        drawTimer = 20
    else
        lastSelectedUnitPositions = {}
        drawTimer = 0
    end

    return true
end

------------------------------------------------------------
-- DrawWorld feedback lines
------------------------------------------------------------
function widget:DrawWorld()
    if not Enabled() then return end
    if drawTimer <= 0 or #lastSelectedUnitPositions == 0 then return end

    local mx, my = Spring.GetMouseState()
    local t, pos = Spring.TraceScreenRay(mx, my, true)
    if t == "ground" and pos then
        local cx, cy, cz = pos[1], pos[2], pos[3]
        local r, g, b = 0.6, 0.8, 1
        if shiftHeld then
            r, g, b = 0, 1, 0
        elseif ctrlHeld then
            r, g, b = 1, 0, 0
        end

        gl.Color(r, g, b, drawTimer / 20)
        gl.LineWidth(3)
        gl.BeginEnd(GL.LINES, function()
            for _, unitPos in ipairs(lastSelectedUnitPositions) do
                gl.Vertex(cx, cy + 10, cz)
                gl.Vertex(unitPos[1], unitPos[2] + 10, unitPos[3])
            end
        end)
        gl.LineWidth(1)
        gl.Color(1, 1, 1, 1)
    end
    drawTimer = drawTimer - 1
end

------------------------------------------------------------
-- Rainbow sparkle (screen-space)
------------------------------------------------------------
local function hsv2rgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if     i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else               return v, p, q end
end

function widget:Update(dt)
    if not Enabled() then return end
    if mouseBackHeld and options.sparkleIndicator and options.sparkleIndicator.value then
        sparklePhase = (sparklePhase + dt * 12.0) % (2 * math.pi)
        huePhase     = (huePhase + dt * 0.35) % 1.0
    end
end

function widget:DrawScreen()
    if not Enabled() then return end
    if not (mouseBackHeld and options.sparkleIndicator and options.sparkleIndicator.value) then return end

    local mx, my = Spring.GetMouseState()
    if not (mx and my) then return end

    local r     = SparkleRadius()
    local alpha = 0.6 + 0.35 * math.sin(sparklePhase * 3.5)

    gl.LineWidth(1.5)
    gl.BeginEnd(GL.LINES, function()
        for i = 0, ARMS - 1 do
            local ang = sparklePhase + i * (2 * math.pi / ARMS)
            local dx  = math.cos(ang)
            local dy  = math.sin(ang)

            local h = (huePhase + i / ARMS) % 1.0
            local rr, gg, bb = hsv2rgb(h, 1.0, 1.0)
            gl.Color(rr, gg, bb, alpha)

            gl.Vertex(mx - dx * (r * 0.45), my - dy * (r * 0.45))
            gl.Vertex(mx + dx * (r * 0.45), my + dy * (r * 0.45))
        end
    end)
    gl.LineWidth(1)
    gl.Color(1, 1, 1, 1)
end
