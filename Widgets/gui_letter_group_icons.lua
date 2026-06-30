--------------------------------------------------------------------------------
-- Letter Group Icons (Filtered Letters + F6/F7 Toggle)
-- EPIC MENU: Settings / Misc / Letter Icons
-- Enable/Disable is controlled ONLY by the Epic Menu checkbox hotkey (default F7).
-- Local hotkeys retained: F6+Letter (per-letter), Ctrl+F7 (multi-letter display).
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name    = "Letter Group Icons",
		desc    = "Displays letter icons for unit groups A–Z. Toggle individual letters with F6+letter or via the Epic Menu; Ctrl+F7 toggles multi-letter display.",
		author  = "FrequentPilgrim",
		date    = "2025-06-10",
		license = "MIT",
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

local KEY_F6              = Spring.GetKeyCode("f6")
local KEY_F7              = Spring.GetKeyCode("f7")

------------------------------------------------------------
-- Display config & state
------------------------------------------------------------
local fontColor           = {1, 1, 0, 1}

local fontSizeWorld       = 25
local fontSizeScreen      = 25

local renderScreen        = false

local holdF6              = false
local widgetEnabled       = true
local showAllLetters      = false

local unitLetterMap       = {}

local allowedLetters  = {}
for i = string.byte("A"), string.byte("Z") do
	allowedLetters[string.char(i)] = true
end

local activeLetters   = {}

-- forward-declared; assigned below (after `options` exists). KeyPress (F6+letter)
-- and the per-letter Epic Menu checkboxes both route through this single
-- function so the two controls can never go out of sync with each other.
local setLetterActive

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
-- Unified toggle function
------------------------------------------------------------
local function setLetterIconsEnabled(state)
	widgetEnabled = state and true or false
	if options and options.enabled then
		options.enabled.value = widgetEnabled
	end
	Echo("[Letter Group Icons] " .. (widgetEnabled and "Enabled" or "Disabled"))
end

------------------------------------------------------------
-- EPIC MENU
------------------------------------------------------------
options_path  = options_path or 'Settings/Misc/Letter Icons'
options_order = { '__help', 'enabled', 'drawScreen', 'fontSizeWorld', 'fontSizeScreen' }
options       = options or {}

options['__help'] = {
	name = "Letter Icons",
	type = "label",
	desc = "F6+Letter toggles letter visibility (also available below as checkboxes) • Ctrl+F7 toggles multi-letter display.",
}

options['enabled'] = {
	name   = "Enable Letter Icons [F7]",
	type   = "bool",
	value  = (widgetEnabled ~= false),
	hotkey = "f7",
	key    = "f7",
	OnChange = function(self)
		setLetterIconsEnabled(self.value)
	end
}

options['drawScreen'] = {
	name   = "Draw in Screen Space",
	desc   = "If enabled, draw letters in 2D screen space instead of 3D world space.",
	type   = "bool",
	value  = false,
	OnChange = function(self)
		renderScreen = (self.value == true)
	end
}

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

------------------------------------------------------------
-- Per-letter visibility toggles
-- Lets you show/hide each letter's icons from the Epic Menu instead of
-- having to hold F6 and press the letter. Kept in sync both ways:
-- toggling a checkbox here updates activeLetters, and pressing F6+letter
-- updates the checkbox.
------------------------------------------------------------
setLetterActive = function(letter, state)
	state = state and true or false
	activeLetters[letter] = state
	local opt = options["letter_" .. letter]
	if opt and opt.value ~= state then
		opt.value = state
	end
end

options['__letters_help'] = {
	name = "Per-Letter Visibility",
	type = "label",
	desc = "Show or hide icons for each letter individually.",
}
options_order[#options_order + 1] = '__letters_help'

for byte = string.byte("A"), string.byte("Z") do
	local letter = string.char(byte)
	local key = "letter_" .. letter
	options[key] = {
		name  = "Show " .. letter,
		desc  = "Toggle visibility of letter " .. letter .. "'s icons (same as F6+" .. letter .. ").",
		type  = "bool",
		value = true,
		path  = options_path,
		OnChange = function(self)
			setLetterActive(letter, self.value)
		end,
	}
	options_order[#options_order + 1] = key
end

WG = WG or {}
WG.LetterIcons_SetEnabled = setLetterIconsEnabled

------------------------------------------------------------
-- Config persistence
------------------------------------------------------------
function widget:GetConfigData()
	return {
		enabled       = widgetEnabled,
		drawScreen    = (options.drawScreen and options.drawScreen.value) or false,
		fontSizeWorld = fontSizeWorld,
		fontSizeScreen = fontSizeScreen,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then return end
	if data.enabled ~= nil then
		widgetEnabled = data.enabled and true or false
		if options.enabled then options.enabled.value = widgetEnabled end
	end
	if data.drawScreen ~= nil then
		renderScreen = data.drawScreen and true or false
		if options.drawScreen then options.drawScreen.value = renderScreen end
	end
	if data.fontSizeWorld then
		fontSizeWorld = tonumber(data.fontSizeWorld) or fontSizeWorld
		if options.fontSizeWorld then options.fontSizeWorld.value = fontSizeWorld end
	end
	if data.fontSizeScreen then
		fontSizeScreen = tonumber(data.fontSizeScreen) or fontSizeScreen
		if options.fontSizeScreen then options.fontSizeScreen.value = fontSizeScreen end
	end
end

------------------------------------------------------------
-- Initialize / Shutdown
-- FIX: reads letter groups from WG (populated by gui_letter_auto_groups)
-- instead of hardcoding a path to ZK_Data.lua which was causing self-removal
-- on first run for any user without that specific config key.
------------------------------------------------------------
function widget:Initialize()
	-- Rebuild unitLetterMap from WG whenever it's available.
	-- Also called from Update when WG becomes populated mid-session.
	local function buildMap()
		local letterGroups = WG and WG.LetterUnitTypeMultiAutoGroups
		if not letterGroups then return false end

		unitLetterMap = {}
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
		return true
	end

	buildMap()  -- attempt on init; may be empty if MENU widget loads after us

	-- Restore per-letter visibility + enabled state from Spring config string
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

	if options and options.enabled then
		options.enabled.value = (widgetEnabled ~= false)
	end
	if options.drawScreen then renderScreen = (options.drawScreen.value == true) end
	if options.fontSizeWorld and options.fontSizeWorld.value then
		fontSizeWorld = tonumber(options.fontSizeWorld.value) or fontSizeWorld
	end
	if options.fontSizeScreen and options.fontSizeScreen.value then
		fontSizeScreen = tonumber(options.fontSizeScreen.value) or fontSizeScreen
	end

	-- Sync the per-letter menu checkboxes with the restored visibility state
	for letter in pairs(allowedLetters) do
		local opt = options["letter_" .. letter]
		if opt then
			opt.value = activeLetters[letter] and true or false
		end
	end

	-- Expose rebuild function so MENU widget can notify us after saving groups
	WG.LetterIcons_RebuildMap = buildMap
end

function widget:Shutdown()
	local saveStr = ""
	for letter in pairs(allowedLetters) do
		if activeLetters[letter] then
			saveStr = saveStr .. letter
		end
	end
	local enabledStr = widgetEnabled and "1" or "0"
	Spring.SetConfigString("LetterGroupIcons_Visibility", saveStr .. ":" .. enabledStr)
	if WG then
		WG.LetterIcons_SetEnabled  = nil
		WG.LetterIcons_RebuildMap  = nil
	end
end

------------------------------------------------------------
-- Key handling
------------------------------------------------------------
function widget:KeyPress(key, mods, isRepeat)
	if key == KEY_F6 and not isRepeat then
		holdF6 = true
		return true
	end

	if key == KEY_F7 and not isRepeat and mods and mods.ctrl then
		showAllLetters = not showAllLetters
		Echo("[Letter Group Icons] Show All Letters: " .. tostring(showAllLetters))
		return true
	end

	if holdF6 and not isRepeat then
		local char = Spring.GetKeySymbol(key)
		char = string.upper(char or "")
		if allowedLetters[char] then
			setLetterActive(char, not activeLetters[char])
			Echo("[Letter Group Icons] Toggled letter '" .. char .. "' visibility: " .. tostring(activeLetters[char]))
			return true
		end
	end
end

function widget:KeyRelease(key)
	if key == KEY_F6 then
		holdF6 = false
	end
end

------------------------------------------------------------
-- Draw (WORLD)
------------------------------------------------------------
function widget:DrawWorld()
	if not widgetEnabled then return end
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
-- Draw (SCREEN)
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
