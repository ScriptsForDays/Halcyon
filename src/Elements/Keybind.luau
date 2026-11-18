local UserInputService = game:GetService("UserInputService")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Popup = require("../Components/Popup")
local Row = require("./Row")
local Signal = require("../Core/Signal")
local Strings = require("../Core/Strings")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

-- Key chip looks (kind "Keybind").
--   Chip      a boxed name
--   Keycap    a raised key with a deeper bottom edge
--   Brackets  the name in square brackets, no box
Styles.register("Keybind", "Chip", { box = true })
Styles.register("Keybind", "Keycap", { box = true, keycap = true })
Styles.register("Keybind", "Brackets", { brackets = true })

local MODES = { "Press", "Toggle", "Hold" }
local LONG_PRESS = 0.5

local SHORT = {
	LeftShift = "LShift",
	RightShift = "RShift",
	LeftControl = "LCtrl",
	RightControl = "RCtrl",
	LeftAlt = "LAlt",
	RightAlt = "RAlt",
}

-- Keys that only count as part of a combination when Modifiers is on.
local MODIFIERS = {
	Ctrl = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl },
	Shift = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift },
	Alt = { Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt },
}
local MODIFIER_ORDER = { "Ctrl", "Shift", "Alt" }

local function isModifier(keyCode)
	for _, keys in MODIFIERS do
		if table.find(keys, keyCode) then
			return true
		end
	end
	return false
end

local function heldModifiers()
	local held = {}
	for name, keys in MODIFIERS do
		held[name] = UserInputService:IsKeyDown(keys[1]) or UserInputService:IsKeyDown(keys[2])
	end
	return held
end

local function keyFromName(name)
	local ok, item = pcall(function()
		return Enum.KeyCode[name]
	end)
	return if ok then item else nil
end

local Keybind = {}

-- The key chip, usable on its own row or beside a Toggle. `onInput(pressed)`
-- runs when the bound key goes down and again when it comes up.
function Keybind.control(row, options, onInput)
	local scope, library, window = row.scope, row.library, row.window
	local key = if typeof(options.Default) == "EnumItem" then options.Default else nil
	-- With Modifiers, the Ctrl, Shift and Alt that must be held with the key.
	local withModifiers = options.Modifiers == true
	local combo = { Ctrl = false, Shift = false, Alt = false }
	local listening, held = false, false
	local control = { Changed = Signal.new(), Active = false, Mode = options.Mode or "Press" }
	scope:add(control.Changed)
	local look = Styles.pick("Keybind", options.Style, window)

	local chip = Create.new("TextButton", {
		Name = "Key",
		Size = UDim2.fromOffset(0, if look.keycap then row.reach - 2 else row.reach),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = if look.keycap then "bold" else "medium",
		BackgroundTransparency = if look.box then 0 else 1,
		Theme = { BackgroundColor3 = if look.keycap then "raised" else row.controlRole, TextColor3 = if look.keycap then "text" else "textMuted" },
		Parent = row.slot,
	})
	Create.padding(chip, if look.box then 8 else 2, 0)
	if look.box then
		Create.corner(6, chip)
		Create.stroke("stroke", chip)
	end
	if look.keycap then
		-- A darker lip under the key, as on a real keyboard.
		local lip = Create.new("Frame", {
			Name = "Lip",
			Size = UDim2.new(1, 16, 0, 4),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			ZIndex = 0,
			Theme = { BackgroundColor3 = "stroke" },
			Parent = chip,
		})
		Create.corner(6, lip)
	end

	-- The key as the player reads it: "Ctrl + Shift + F", "RShift".
	function control.Label()
		if not key then
			return nil
		end
		local parts = {}
		if withModifiers then
			for _, name in MODIFIER_ORDER do
				if combo[name] then
					table.insert(parts, name)
				end
			end
		end
		table.insert(parts, SHORT[key.Name] or key.Name)
		return table.concat(parts, " + ")
	end

	local function draw()
		local name = if listening then Strings.get("Press a key") elseif key then control.Label() else Strings.get("None")
		chip.Text = if look.brackets then "[ " .. name .. " ]" else name
		if listening then
			Theme.bind(chip, "TextColor3", "accent")
		else
			Theme.bind(chip, "TextColor3", if look.keycap then "text" else "textMuted")
		end
	end

	local function stopListening()
		listening = false
		draw()
		-- Cleared a moment later so the key that was just bound cannot also
		-- trigger another bind or the menu key in the same press.
		task.defer(function()
			library.listeningForKey = false
		end)
	end

	-- With Modifiers the value is { Key, Ctrl, Shift, Alt }; otherwise the
	-- KeyCode on its own.
	function control:Get()
		if withModifiers and key then
			return { Key = key, Ctrl = combo.Ctrl, Shift = combo.Shift, Alt = combo.Alt }
		end
		return key
	end

	-- Takes a KeyCode, nil, a { Key, Ctrl, Shift, Alt } table, or text such
	-- as "Ctrl+Shift+F".
	function control:Set(value)
		combo = { Ctrl = false, Shift = false, Alt = false }
		if type(value) == "string" then
			value = self:Decode(value)
		end
		if type(value) == "table" and typeof(value) ~= "EnumItem" then
			for _, name in MODIFIER_ORDER do
				combo[name] = withModifiers and value[name] == true
			end
			value = value.Key
		end
		key = if typeof(value) == "EnumItem" then value else nil
		draw()
		local current = self:Get()
		self.Changed:Fire(current)
		window.KeybindsChanged:Fire()
		Env.call(row.handle.Title, options.ChangedCallback, current)
	end

	function control:Encode()
		if not key then
			return ""
		end
		if not withModifiers then
			return key.Name
		end
		local parts = {}
		for _, name in MODIFIER_ORDER do
			if combo[name] then
				table.insert(parts, name)
			end
		end
		table.insert(parts, key.Name)
		return table.concat(parts, "+")
	end

	-- An unknown or empty name loads as no key.
	function control:Decode(text)
		if type(text) ~= "string" or text == "" then
			return nil
		end
		if not withModifiers then
			return keyFromName(text)
		end
		local parts = string.split(text, "+")
		local found = keyFromName(table.remove(parts))
		if not found then
			return nil
		end
		local value = { Key = found }
		for _, name in parts do
			if MODIFIERS[name] then
				value[name] = true
			end
		end
		return value
	end

	scope:connect(chip.Activated, function()
		if control.longPressed then
			control.longPressed = false
			return
		end
		if listening then
			stopListening()
		else
			listening, library.listeningForKey = true, true
			draw()
		end
	end)
	control.chip = chip

	scope:connect(UserInputService.InputBegan, function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if listening then
			-- Ctrl, Shift or Alt alone starts a combination; the key that
			-- follows finishes it.
			if withModifiers and isModifier(input.KeyCode) then
				return
			end
			stopListening()
			if input.KeyCode == Enum.KeyCode.Backspace then
				control:Set(nil)
			elseif input.KeyCode ~= Enum.KeyCode.Escape then
				local value = if withModifiers then heldModifiers() else {}
				value.Key = input.KeyCode
				control:Set(value)
			end
		elseif not processed and not library.listeningForKey and key and input.KeyCode == key and not row.handle:IsLocked() then
			if withModifiers then
				local now = heldModifiers()
				for _, name in MODIFIER_ORDER do
					if now[name] ~= combo[name] then
						return
					end
				end
			end
			held = true
			onInput(true)
		end
	end)

	scope:connect(UserInputService.InputEnded, function(input)
		if held and input.KeyCode == key then
			held = false
			onInput(false)
		end
	end)

	local listing = { handle = row.handle, control = control }
	table.insert(window.keybinds, listing)
	scope:add(function()
		if listening then
			library.listeningForKey = false
		end
		table.remove(window.keybinds, table.find(window.keybinds, listing))
		window.KeybindsChanged:Fire()
	end)

	-- A default combination may be given as { Key, Ctrl, Shift, Alt } or as
	-- text such as "Ctrl+F"; nothing is called while the row is made.
	local default = options.Default
	if type(default) == "string" then
		default = control:Decode(default)
	end
	if type(default) == "table" and typeof(default) ~= "EnumItem" then
		for _, name in MODIFIER_ORDER do
			combo[name] = withModifiers and default[name] == true
		end
		key = if typeof(default.Key) == "EnumItem" then default.Key else nil
	end
	draw()
	return control
end

-- Mode "Press" runs the Callback on each press, "Toggle" alternates true and
-- false, and "Hold" passes true while the key is down. With ModePicker, a
-- right-click (or a long press on touch) on the key lets the player choose
-- the mode; ModeChangedCallback hears the choice.
function Keybind.new(container, options)
	local row = Row.new(container, options)
	local handle = row.handle
	local mode = if table.find(MODES, options.Mode) then options.Mode else "Press"
	local control

	control = Keybind.control(row, {
		Default = options.Default,
		Mode = mode,
		Style = options.Style,
		Modifiers = options.Modifiers,
		ChangedCallback = options.ChangedCallback,
	}, function(pressed)
		if mode == "Hold" then
			control.Active = pressed
			Env.call(handle.Title, options.Callback, pressed)
		elseif pressed then
			if mode == "Toggle" then
				control.Active = not control.Active
			end
			Env.call(handle.Title, options.Callback, if mode == "Toggle" then control.Active else nil)
		end
		row.window.KeybindsChanged:Fire()
	end)

	row.scope:add(control.Changed:Connect(function(key)
		handle.Changed:Fire(key)
	end))

	function handle:GetMode()
		return mode
	end

	function handle:SetMode(newMode)
		if table.find(MODES, newMode) and newMode ~= mode then
			mode = newMode
			control.Mode = mode
			control.Active = false
			row.window.KeybindsChanged:Fire()
			Env.call(handle.Title .. " mode", options.ModeChangedCallback, mode)
		end
	end

	if options.ModePicker then
		local chip = control.chip
		local function pick()
			local popup = Popup.toggle(row.library, chip, { Width = 150 })
			if not popup then
				return
			end
			for index, name in MODES do
				local item = Create.new("TextButton", {
					Name = name,
					Size = UDim2.new(1, 0, 0, if row.library.touch then 40 else 30),
					Text = name,
					TextSize = 13,
					Weight = if name == mode then "bold" else "regular",
					LayoutOrder = index,
					BackgroundTransparency = if name == mode then 0.86 else 1,
					Theme = { BackgroundColor3 = "accent", TextColor3 = if name == mode then "accent" else "text" },
					Parent = popup.frame,
				})
				Create.corner(6, item)
				popup.scope:connect(item.Activated, function()
					handle:SetMode(name)
					popup.close()
				end)
			end
		end
		row.scope:connect(chip.MouseButton2Click, pick)
		-- Touch has no right button: holding the key opens the same menu.
		row.scope:connect(chip.InputBegan, function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local started = os.clock()
			control.pressStarted = started
			task.delay(LONG_PRESS, function()
				if control.pressStarted == started then
					control.longPressed = true
					pick()
				end
			end)
		end)
		row.scope:connect(chip.InputEnded, function()
			control.pressStarted = nil
		end)
	end

	function handle:Get()
		return control:Get()
	end

	function handle:Set(key)
		control:Set(key)
	end

	function handle:Encode()
		return control:Encode()
	end

	function handle:Decode(name)
		return control:Decode(name)
	end

	return handle
end

return Keybind
