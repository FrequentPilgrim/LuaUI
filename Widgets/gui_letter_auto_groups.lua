function widget:GetInfo()
    return {
        name      = "Letter UnitType Auto Groups",
        desc      = "Assign unit types to letter groups (A-Z). Meta+Letter = select, Shift+Meta+Letter = add to selection, Ctrl+Meta+Letter = filter selection, Backspace+Meta+Letter = clear group.",
        author    = "FrequentPilgrim",
        date      = "2025-06-01",
        license   = "MIT",
        layer     = 0,
        enabled   = true
    }
end

--------------------------------------------------------------------------------
-- Epic Menu
-- FIX: moved enable toggle to options table keyed by string, not positional
-- array index. The old options[1].value gate broke silently after the label
-- was inserted at position 1 via table.insert(options, 1, labelOpt).
--------------------------------------------------------------------------------
options = options or {}
options_order = options_order or {}

options["enableAutoGroups"] = {
    key    = "enableAutoGroups",
    name   = "Enable Letter UnitType Auto Groups",
    desc   = "Toggle letter-based auto group assignment and selection.",
    type   = "bool",
    value  = true,
    scope  = "widget",
    path   = "Settings/Misc/Letter Groups",
}

-- ── state ──────────────────────────────────────────────────────────────────
local assignedGroups = {}   -- letter -> { [unitDefName] = true, ... }
local keycodeToLetter = {}
local backspaceKey   = Spring.GetKeyCode("backspace")
local backspaceDown  = false

for i = 65, 90 do
    local ch = string.char(i)
    keycodeToLetter[Spring.GetKeyCode(ch:lower())] = ch
end

-- ── helpers ─────────────────────────────────────────────────────────────────
local function IsEnabled()
    return options.enableAutoGroups and options.enableAutoGroups.value
end

local function ShowMessage(msg)
    Spring.Echo("[LetterGroups] " .. msg)
end

local function PlayerToast(msg)
    Spring.Echo("game_message: " .. msg)
end

-- Notify the icons widget to rebuild its map after group changes
local function NotifyIconsWidget()
    if WG and WG.LetterIcons_RebuildMap then
        WG.LetterIcons_RebuildMap()
    end
end

-- ── group operations ─────────────────────────────────────────────────────────
local function AssignLetterGroup(letter)
    local selUnits = Spring.GetSelectedUnits()
    if #selUnits == 0 then
        ShowMessage("No units selected to assign to group " .. letter)
        PlayerToast("No units selected for group " .. letter)
        return
    end

    assignedGroups[letter] = assignedGroups[letter] or {}
    local addedCount = 0
    for _, unitID in ipairs(selUnits) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid then
            local defName = UnitDefs[udid].name
            if defName and not assignedGroups[letter][defName] then
                assignedGroups[letter][defName] = true
                addedCount = addedCount + 1
            end
        end
    end

    WG.LetterUnitTypeMultiAutoGroups = assignedGroups
    NotifyIconsWidget()

    if addedCount > 0 then
        ShowMessage("Added " .. addedCount .. " unit type(s) to group " .. letter)
    else
        ShowMessage("No new unit types added to group " .. letter)
    end
end

local function ClearLetterGroup(letter)
    if assignedGroups[letter] then
        assignedGroups[letter] = nil
        WG.LetterUnitTypeMultiAutoGroups = assignedGroups
        NotifyIconsWidget()
        ShowMessage("Cleared group " .. letter)
        PlayerToast("Cleared group " .. letter)
    else
        ShowMessage("Group " .. letter .. " is not assigned")
        PlayerToast("Group " .. letter .. " is not assigned")
    end
end

local function GetUnitsInGroup(letter)
    local defNameSet = assignedGroups[letter]
    if not defNameSet then return {} end

    local myTeam = Spring.GetMyTeamID()
    local units  = Spring.GetTeamUnits(myTeam)
    local result = {}
    for _, unitID in ipairs(units) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid then
            local defName = UnitDefs[udid].name
            if defNameSet[defName] then
                table.insert(result, unitID)
            end
        end
    end
    return result
end

local function SelectLetterGroup(letter)
    local toSelect = GetUnitsInGroup(letter)
    if #toSelect == 0 then
        ShowMessage("No alive units in group " .. letter)
        return
    end
    Spring.SelectUnitArray(toSelect, false)
    ShowMessage("Selected " .. #toSelect .. " units from group " .. letter)
end

local function AddToSelection(letter)
    local toSelect = GetUnitsInGroup(letter)
    if #toSelect == 0 then
        ShowMessage("No units to add from group " .. letter)
        return
    end
    Spring.SelectUnitArray(toSelect, true)
    ShowMessage("Added " .. #toSelect .. " units from group " .. letter)
end

local function FilterSelection(letter)
    local current = Spring.GetSelectedUnits()
    if #current == 0 then return end

    local defNameSet = assignedGroups[letter]
    if not defNameSet then
        ShowMessage("Group " .. letter .. " not assigned")
        return
    end

    local filtered = {}
    for _, unitID in ipairs(current) do
        local udid = Spring.GetUnitDefID(unitID)
        if udid then
            local defName = UnitDefs[udid].name
            if defNameSet[defName] then
                table.insert(filtered, unitID)
            end
        end
    end

    Spring.SelectUnitArray(filtered, false)
    ShowMessage("Filtered selection to " .. #filtered .. " units in group " .. letter)
end

-- ── input ────────────────────────────────────────────────────────────────────
function widget:KeyPress(key, mods, isRepeat)
    if not IsEnabled() then return false end

    if key == backspaceKey then
        backspaceDown = true
        return false   -- don't consume; let other widgets see it
    end

    local letter = keycodeToLetter[key]
    if not letter or not mods.meta then return false end

    if backspaceDown then
        ClearLetterGroup(letter)
        return true
    elseif mods.alt then
        AssignLetterGroup(letter)
        return true
    elseif mods.shift then
        AddToSelection(letter)
        return true
    elseif mods.ctrl then
        FilterSelection(letter)
        return true
    else
        SelectLetterGroup(letter)
        return true
    end
end

function widget:KeyRelease(key)
    if key == backspaceKey then
        backspaceDown = false
    end
end

-- ── persistence ──────────────────────────────────────────────────────────────
function widget:GetConfigData()
    local saved = { enableAutoGroups = IsEnabled() }
    for letter, defSet in pairs(assignedGroups) do
        saved[letter] = {}
        for defName in pairs(defSet) do
            table.insert(saved[letter], defName)
        end
    end
    return saved
end

function widget:SetConfigData(data)
    if type(data) ~= "table" then return end

    if data.enableAutoGroups ~= nil and options.enableAutoGroups then
        options.enableAutoGroups.value = data.enableAutoGroups and true or false
    end

    assignedGroups = {}
    for letter, defList in pairs(data) do
        if type(letter) == "string" and #letter == 1
           and letter >= "A" and letter <= "Z"
           and type(defList) == "table" then
            assignedGroups[letter] = {}
            for _, defName in ipairs(defList) do
                assignedGroups[letter][defName] = true
            end
        end
    end

    WG.LetterUnitTypeMultiAutoGroups = assignedGroups
    Spring.Echo("[LetterGroups] Loaded saved groups")
end

function widget:Initialize()
    WG.LetterUnitTypeMultiAutoGroups = assignedGroups
end

-- ── Epic Menu buttons (A-Z assign / clear) ───────────────────────────────────
do
    local function _append(opt)
        options[opt.key] = opt
        options_order[#options_order + 1] = opt.key
    end

    -- Populate options_order with the enable toggle first
    local found = false
    for _, k in ipairs(options_order) do
        if k == "enableAutoGroups" then found = true; break end
    end
    if not found then
        table.insert(options_order, 1, "enableAutoGroups")
    end

    _append({ key = "lbl_usage", type = "text", path = "Settings/Misc/Letter Groups",
              name = "Meta+Letter = select  |  Shift = add  |  Ctrl = filter  |  Backspace+Meta+Letter = clear",
              value = "" })

    _append({ key = "lbl_assign", type = "text", path = "Settings/Misc/Letter Groups",
              name = "Quick Assign (uses current selection's unit types)", value = "" })

    for byte = string.byte("A"), string.byte("Z") do
        local letter = string.char(byte)
        _append({
            key      = "assign_" .. letter,
            name     = "Assign → " .. letter,
            desc     = "Assign current selection's unit types to group " .. letter,
            type     = "button",
            noHotkey = true,
            scope    = "widget",
            path     = "Settings/Misc/Letter Groups",
            OnChange = function() AssignLetterGroup(letter) end,
        })
    end

    _append({ key = "lbl_clear", type = "text", path = "Settings/Misc/Letter Groups",
              name = "Quick Clear", value = "" })

    for byte = string.byte("A"), string.byte("Z") do
        local letter = string.char(byte)
        _append({
            key      = "clear_" .. letter,
            name     = "Clear → " .. letter,
            desc     = "Clear all unit types from group " .. letter,
            type     = "button",
            noHotkey = true,
            scope    = "widget",
            path     = "Settings/Misc/Letter Groups",
            OnChange = function() ClearLetterGroup(letter) end,
        })
    end
end
