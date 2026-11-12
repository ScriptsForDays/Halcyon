local UserInputService = game:GetService("UserInputService")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Row = require("./Row")
local Signal = require("../Core/Signal")

local SHORT = { LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl", LeftAlt = "LAlt", RightAlt = "RAlt" }

local Keybind = {}

-- The key chip, usable on its own row or beside a Toggle. `onInput(pressed)`
-- runs when the bound key goes down and again when it comes up.
function Keybind.control(row, options, onInput)
	local scope, library, window = row.scope, row.library, row.window
	local key = options.Default
	local listening, held = false, false
	local control = { Changed = Signal.new(), Active = false, Mode = options.Mode or "Press" }
	scope:add(control.Changed)

	local chip = Create.new("TextButton", {
		Name = "Key",
		Size = UDim2.fromOffset(0, row.reach),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = "medium",
		Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "textMuted" },
		Parent = row.slot,
	})
	Create.corner(6, chip)
	Create.padding(chip, 8, 0)
	Create.stroke("stroke", chip)

	local function draw()
		chip.Text = if listening then "Press a key" elseif key then SHORT[key.Name] or key.Name else "None"
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
		if listening then
			stopListening()
		else
			listening, library.listeningForKey = true, true
			draw()
		end
	end)

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
-- false, and "Hold" passes true while the key is down.
function Keybind.new(container, options)
	local row = Row.new(container, options)
	local handle = row.handle
	local mode = options.Mode or "Press"
	local control

	control = Keybind.control(row, {
		Default = options.Default,
		Mode = mode,
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
