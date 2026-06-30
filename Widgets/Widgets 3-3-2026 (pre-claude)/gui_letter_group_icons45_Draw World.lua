--------------------------------------------------------------------------------
-- Letter Group Icons (Filtered Letters + F6/F7 Toggle)
-- EPIC MENU: Settings / Misc / Letter Icons
-- Enable/Disable is controlled ONLY by the Epic Menu checkbox hotkey (default F7).
-- Local hotkeys retained: F6+Letter (per-letter), Ctrl+F7 (multi-letter display).
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Letter Group Icons (Filtered Letters + F6/F7 Toggle)",
		desc    = "Displays letter icons for unit groups A–Z. Toggle individual letters with F6+letter; Ctrl+F7 toggles multi-letter display.",
		author  = "FrequentPilgrim",
		date    = "2025-06-10",
		license = "GPL-v2",
		layer   = 0,
		enabled = true,
	}
end

------------------------------------------------------------
-- Local shortcuts
------------------------------------------------------------
local glText              = gl.Text
local glColor             = gl.Color
local glPushMatrix        = gl.PushMatrix
local glPopMatrix         = gl.PopMatrix
local glTranslate         = gl.Translate
local glBillboard         = gl.Billboard
local glDepthTest         = gl.DepthTest
local glDrawFuncAtUnit    = gl.DrawFuncAtUnit

local spGetMyTeamID       = Spring.GetMyTeamID
local spGetUnitTeam       = Spring.GetUnitTeam
local spGetUnitDefID      = Spring.GetUnitDefID
local spGetAllUnits       = Spring.GetAllUnits
local spIsUnitInView      = Spring.IsUnitInView
local spGetUnitPosition   = Spring.GetUnitPosition
local spWorldToScreen     = Spring.WorldToScreenCoords
local Echo                = Spring.Echo
local VFS                 = VFS

------------------------------------------------------------
-- Display config & state
------------------------------------------------------------
-- Existing default kept to avoid regressions.
local fontColor           = {1, 1, 0, 1}

-- NEW: Separate font sizes for world vs. screen draw (defaults are safe).
local fontSizeWorld       = 25        -- matches old behavior
local fontSizeScreen      = 25        -- independent size when in screen mode

-- NEW: Render space toggle; default false preserves DrawWorld behavior.
local renderScreen        = false     -- false = DrawWorld (default), true = DrawScreen

local holdF6              = false
local widgetEnabled       = true      -- MASTER GATE (toggled ONLY by Epic Menu option)
local showAllLetters      = false     -- Ctrl+F7 toggles this

local unitLetterMap       = {}
local letterGroups        = {}

local allowedLetters  = {}
for i = string.byte("A"), string.byte("Z") do
	allowedLetters[string.char(i)] = true
end

local activeLetters   = {}

-- Custom display order (QWERTY-ish)
local sortOrder = {}
do
	local customOrder = "qwertyasdfghzxcbijklmnopuv"
	for i = 1, #customOrder do
		sortOrder[string.sub(customOrder, i, i)] = i
	end
end

local function getSortedLetters(letters)
	local sorted = {}
	for _, letter in ipairs(letters) do
		sorted[#sorted + 1] = letter
	end
	table.sort(sorted, function(a, b)
		local oa = sortOrder[string.lower(a)] or (100 + string.byte(a))
		local ob = sortOrder[string.lower(b)] or (100 + string.byte(b))
		return oa < ob
	end)
	return sorted
end

------------------------------------------------------------
-- Unified toggle function (used by checkbox & its assignable hotkey)
------------------------------------------------------------
local function setLetterIconsEnabled(state)
	widgetEnabled = state and true or false
	if options and options.enabled then
		options.enabled.value = widgetEnabled
	end
	Echo("[Letter Group Icons] " .. (widgetEnabled and "Enabled" or "Disabled"))
end

------------------------------------------------------------
-- EPIC MENU INTEGRATION — checkbox with assignable hotkey
-- The right-side hotkey button defaults to F7 and can be rebound by the user.
------------------------------------------------------------
options_path  = options_path or 'Settings/Misc/Letter Icons'
options_order = options_order or { '__help', 'enabled' }
options       = options or {}

options['__help'] = {
	name = "Letter Icons",
	type = "label",
	desc = "F6+Letter toggles letter visibility • Ctrl+F7 toggles multi-letter display.",
}

options['enabled'] = {
	name   = "Enable Letter Icons [F7]",
	type   = "bool",
	value  = (widgetEnabled ~= false),
	-- Default assignable hotkey for this option row:
	hotkey = "f7",
	key    = "f7",
	OnChange = function(self)
		setLetterIconsEnabled(self.value)
	end
}

-- ===== BEGIN Options (pure additions) =====
-- 1) Toggle: Draw in Screen Space (default off to preserve DrawWorld behavior)
options['drawScreen'] = {
	name   = "Draw in Screen Space",
	desc   = "If enabled, draw letters in 2D screen space instead of 3D world space.",
	type   = "bool",
	value  = false,  -- default = world (no behavior change)
	OnChange = function(self)
		renderScreen = (self.value == true)
	end
}

-- 2) Separate text size sliders for world vs screen modes
options['fontSizeWorld'] = {
	name   = "World Font Size",
	desc   = "Text size when drawing in world space.",
	type   = "number",
	value  = fontSizeWorld,
	min    = 8, max = 96, step = 1,
	OnChange = function(self)
		fontSizeWorld = tonumber(self.value) or fontSizeWorld
	end
}

options['fontSizeScreen'] = {
	name   = "Screen Font Size",
	desc   = "Text size when drawing in screen space.",
	type   = "number",
	value  = fontSizeScreen,
	min    = 8, max = 96, step = 1,
	OnChange = function(self)
		fontSizeScreen = tonumber(self.value) or fontSizeScreen
	end
}

-- Keep the menu order tidy.
options_order = { '__help', 'enabled', 'drawScreen', 'fontSizeWorld', 'fontSizeScreen' }
-- ===== END Options =====

WG = WG or {}
WG.LetterIcons_SetEnabled = setLetterIconsEnabled

------------------------------------------------------------
-- Initialize / Shutdown
------------------------------------------------------------
function widget:Initialize()
	local data = VFS.Include("LuaUI/Config/ZK_Data.lua")
	if not data or not data["Letter UnitType Multi Auto Groups"] then
		Echo("[Letter Group Icons] Failed to load ZK_Data.lua")
		widgetHandler:RemoveWidget()
		return
	end

	letterGroups = data["Letter UnitType Multi Auto Groups"]

	-- Build unitLetterMap (supports array or set styles)
	for letter, unitTypes in pairs(letterGroups) do
		if allowedLetters[letter] and type(unitTypes) == "table" then
			for k, v in pairs(unitTypes) do
				local unitType
				if type(k) == "string" and v then
					unitType = k
				elseif type(v) == "string" then
					unitType = v
				end
				if unitType then
					unitLetterMap[unitType] = unitLetterMap[unitType] or {}
					unitLetterMap[unitType][#unitLetterMap[unitType] + 1] = letter
				end
			end
		end
	end

	-- Restore visibility + enabled state
	local savedData = Spring.GetConfigString("LetterGroupIcons_Visibility", "")
	local letterPart, enabledPart = savedData:match("^([A-Z]*):([01])$")

	if letterPart then
		for letter in letterPart:gmatch(".") do
			letter = string.upper(letter)
			if allowedLetters[letter] then
				activeLetters[letter] = true
			end
		end
		widgetEnabled = (enabledPart == "1")
	else
		for letter in pairs(allowedLetters) do
			activeLetters[letter] = true
		end
		widgetEnabled = true
	end

	-- Reflect the actual loaded state into the checkbox
	if options and options.enabled then
		options.enabled.value = (widgetEnabled ~= false)
	end

	-- NEW: mirror current menu values on load (safe defaults keep old behavior)
	if options.drawScreen then renderScreen = (options.drawScreen.value == true) end
	if options.fontSizeWorld and options.fontSizeWorld.value then
		fontSizeWorld = tonumber(options.fontSizeWorld.value) or fontSizeWorld
	end
	if options.fontSizeScreen and options.fontSizeScreen.value then
		fontSizeScreen = tonumber(options.fontSizeScreen.value) or fontSizeScreen
	end
end

function widget:Shutdown()
	-- Save visibility + enabled state (menu persists its own values)
	local saveStr = ""
	for letter in pairs(allowedLetters) do
		if activeLetters[letter] then
			saveStr = saveStr .. letter
		end
	end
	local enabledStr = widgetEnabled and "1" or "0"
	Spring.SetConfigString("LetterGroupIcons_Visibility", saveStr .. ":" .. enabledStr)
	if WG then WG.LetterIcons_SetEnabled = nil end
end

------------------------------------------------------------
-- Key handling
-- NOTE: There is NO plain-F7 handler here anymore.
--       The Epic Menu option's assignable hotkey (default F7) handles enabling.
------------------------------------------------------------
function widget:KeyPress(key, mods, isRepeat)
	if key == 287 and not isRepeat then -- F6
		holdF6 = true
		return true
	end

	-- Keep ONLY Ctrl+F7 locally for multi-letter mode.
	if key == 288 and not isRepeat and mods and mods.ctrl then -- Ctrl+F7
		showAllLetters = not showAllLetters
		Echo("[Letter Group Icons] Show All Letters: " .. tostring(showAllLetters))
		return true
	end

	if holdF6 and not isRepeat then
		local char = Spring.GetKeySymbol(key)
		char = string.upper(char or "")
		if allowedLetters[char] then
			activeLetters[char] = not activeLetters[char]
			Echo("[Letter Group Icons] Toggled letter '" .. char .. "' visibility: " .. tostring(activeLetters[char]))
			return true
		end
	end
end

function widget:KeyRelease(key)
	if key == 287 then -- F6
		holdF6 = false
	end
end

------------------------------------------------------------
-- Draw (WORLD)
------------------------------------------------------------
function widget:DrawWorld()
	if not widgetEnabled then return end
	-- NEW: if screen mode is active, skip world drawing
	if renderScreen then return end

	local myTeamID = spGetMyTeamID()
	glDepthTest(true)

	for _, unitID in ipairs(spGetAllUnits()) do
		if spIsUnitInView(unitID) and spGetUnitTeam(unitID) == myTeamID then
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID then
				local unitDef = UnitDefs[unitDefID]
				local letters = unitLetterMap[unitDef.name]
				if letters then
					local sorted = getSortedLetters(letters)
					local drawnCount = 0
					for _, letter in ipairs(sorted) do
						if activeLetters[letter] then
							local offsetX = 12 + (drawnCount * fontSizeWorld * 0.9)
							glDrawFuncAtUnit(unitID, false, function()
								glPushMatrix()
								glTranslate(offsetX, 18, -10)
								glBillboard()
								glColor(fontColor)
								glText(letter, 0, 0, fontSizeWorld, "oc")
								glColor(1, 1, 1, 1)
								glPopMatrix()
							end)
							drawnCount = drawnCount + 1
							if not showAllLetters then
								break
							end
						end
					end
				end
			end
		end
	end

	glDepthTest(false)
	glColor(1, 1, 1, 1)
end

------------------------------------------------------------
-- Draw (SCREEN) — NEW, gated by renderScreen
------------------------------------------------------------
function widget:DrawScreen()
	if not widgetEnabled then return end
	if not renderScreen then return end

	local myTeamID = spGetMyTeamID()

	for _, unitID in ipairs(spGetAllUnits()) do
		if spIsUnitInView(unitID) and spGetUnitTeam(unitID) == myTeamID then
			local unitDefID = spGetUnitDefID(unitID)
			if unitDefID then
				local unitDef = UnitDefs[unitDefID]
				local letters = unitLetterMap[unitDef.name]
				if letters then
					local ux, uy, uz = spGetUnitPosition(unitID)
					if ux then
						-- Nudge upward to approximate the same anchor as world draw.
						local sx, sy = spWorldToScreen(ux, (uy or 0) + 18, uz)
						if sx and sy then
							local sorted = getSortedLetters(letters)
							local drawnCount = 0
							for _, letter in ipairs(sorted) do
								if activeLetters[letter] then
									local offsetX = 12 + (drawnCount * fontSizeScreen * 0.9)
									glColor(fontColor)
									glText(letter, sx + offsetX, sy, fontSizeScreen, "oc")
									glColor(1, 1, 1, 1)
									drawnCount = drawnCount + 1
									if not showAllLetters then
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end
end
