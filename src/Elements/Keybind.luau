local UserInputService = game:GetService("UserInputService")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Popup = require("../Components/Popup")
local Row = require("./Row")
local Signal = require("../Core/Signal")
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

local Keybind = {}

-- The key chip, usable on its own row or beside a Toggle. `onInput(pressed)`
-- runs when the bound key goes down and again when it comes up.
function Keybind.control(row, options, onInput)
	local scope, library, window = row.scope, row.library, row.window
	local key = options.Default
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

	local function draw()
		local name = if listening then "Press a key" elseif key then SHORT[key.Name] or key.Name else "None"
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

	function control:Get()
		return key
	end

	function control:Set(newKey)
		key = if typeof(newKey) == "EnumItem" then newKey else nil
		draw()
		self.Changed:Fire(key)
		window.KeybindsChanged:Fire()
		Env.call(row.handle.Title, options.ChangedCallback, key)
	end

	function control:Encode()
		return if key then key.Name else ""
	end

	-- An unknown or empty name loads as no key.
	function control:Decode(name)
		if type(name) ~= "string" or name == "" then
			return nil
		end
		local ok, item = pcall(function()
			return Enum.KeyCode[name]
		end)
		return if ok then item else nil
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
			stopListening()
			if input.KeyCode == Enum.KeyCode.Backspace then
				control:Set(nil)
			elseif input.KeyCode ~= Enum.KeyCode.Escape then
				control:Set(input.KeyCode)
			end
		elseif not processed and not library.listeningForKey and key and input.KeyCode == key and not row.handle:IsLocked() then
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
