-- Halcyon example: every element, the key prompt, tiers, configs and themes.
--
-- Executor:  loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/example/Example.luau"))()
-- Studio:    put dist/Halcyon.luau in a ModuleScript named "Halcyon" under
--            ReplicatedStorage and this file in a LocalScript.
--
-- The Player and Camera tabs change real things on your own character and
-- camera, and put them back on unload. The Components tab only shows what
-- each control looks like; its callbacks write to the status line.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SOURCE = "https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/dist/Halcyon.luau"

local function loadLibrary()
	local module = ReplicatedStorage:FindFirstChild("Halcyon")
	if module then
		return require(module)
	end
	local compiled, problem = loadstring(game:HttpGet(SOURCE), "Halcyon")
	if not compiled then
		error("Halcyon did not compile: " .. tostring(problem), 0)
	end
	return compiled()
end

local Halcyon = loadLibrary()

local Window = Halcyon:CreateWindow({
	Title = "Halcyon",
	Subtitle = "Example hub",
	Version = "v1.0.0",
	Icon = "sparkles",
	Folder = "HalcyonExample",
	Theme = "Midnight",
	TabStyle = "Sidebar",
	Profile = { Avatar = "Headshot", ShowClock = true },
	KeySystem = {
		Title = "Halcyon example",
		Note = "Demo keys: HALCYON-FREE and HALCYON-PAID. Keyless needs none.",
		Tiers = {
			{ Name = "Keyless", NoKey = true, Description = "Try it with no key. Rows marked Free or Paid stay locked." },
			{
				Name = "Free",
				Keys = { "HALCYON-FREE" },
				Duration = 86400,
				Description = "In a real hub this key comes from your ad link. Lasts a day.",
				Link = "https://github.com/ScriptsForDays/Halcyon",
			},
			{ Name = "Paid", Keys = { "HALCYON-PAID" }, Description = "Unlocks every row.", Link = "https://github.com/ScriptsForDays/Halcyon" },
		},
	},
})
if not Window then
	return
end

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- What the example changed, so unload can put it back.
local original = { fieldOfView = camera.FieldOfView }
local movement = { enabled = false, speed = 32, infiniteJump = false }

local function humanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function applyWalkSpeed()
	local current = humanoid()
	if not current then
		return
	end
	if movement.enabled then
		original.walkSpeed = original.walkSpeed or current.WalkSpeed
		current.WalkSpeed = movement.speed
	elseif original.walkSpeed then
		current.WalkSpeed = original.walkSpeed
		original.walkSpeed = nil
	end
end

local connections = {
	player.CharacterAdded:Connect(function(character)
		-- A new character starts at the game's own speed again.
		original.walkSpeed = nil
		character:WaitForChild("Humanoid", 5)
		applyWalkSpeed()
	end),
	UserInputService.JumpRequest:Connect(function()
		local current = humanoid()
		if movement.infiniteJump and current then
			current:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end),
}

-- Player ----------------------------------------------------------------------

local Player = Window:Tab({ Title = "Player", Icon = "person-standing", Group = "Features" })
local Movement = Player:Section({ Title = "Movement", Icon = "footprints" })

Movement:Toggle({
	Title = "Custom walk speed",
	Description = "Applied again after every respawn",
	Flag = "WalkSpeedEnabled",
	Keybind = { Default = Enum.KeyCode.V, Flag = "WalkSpeedKey" },
	Callback = function(enabled)
		movement.enabled = enabled
		applyWalkSpeed()
	end,
})
Movement:Slider({
	Title = "Walk speed",
	Min = 16,
	Max = 120,
	Default = movement.speed,
	Suffix = " st/s",
	Flag = "WalkSpeed",
	Callback = function(speed)
		movement.speed = speed
		applyWalkSpeed()
	end,
})
Movement:Toggle({
	Title = "Infinite jump",
	Description = "Jump again while in the air",
	Flag = "InfiniteJump",
	Callback = function(enabled)
		movement.infiniteJump = enabled
	end,
})

local Character = Player:Section({ Title = "Character", Icon = "user", Side = "Right" })
Character:Button({
	Title = "Reset character",
	Description = "Asks first",
	Icon = "refresh-cw",
	Callback = function()
		Window:Dialog({
			Title = "Reset your character?",
			Content = "You respawn at the spawn point.",
			Buttons = {
				{ Title = "Stay" },
				{
					Title = "Reset",
					Variant = "Danger",
					Callback = function()
						local current = humanoid()
						if current then
							current.Health = 0
						end
					end,
				},
			},
		})
	end,
})
Character:Paragraph({
	Title = "Scope",
	Content = "These rows change your own character on your own client. A game's server can still correct them.",
	Icon = "info",
})

-- Camera ----------------------------------------------------------------------

local Camera = Window:Tab({ Title = "Camera", Icon = "camera", Group = "Features" })
local View = Camera:Section({ Title = "View", Icon = "eye" })
View:Slider({
	Title = "Field of view",
	Min = 40,
	Max = 120,
	Default = math.round(original.fieldOfView),
	Suffix = "°",
	Stacked = true,
	Flag = "FieldOfView",
	Callback = function(degrees)
		camera.FieldOfView = degrees
	end,
})
View:Button({
	Title = "Restore field of view",
	Icon = "refresh-cw",
	Callback = function()
		Window.Flags.FieldOfView:Set(math.round(original.fieldOfView))
	end,
})

-- Components --------------------------------------------------------------------

local Components = Window:Tab({ Title = "Components", Icon = "layout-grid", Group = "Library" })
local Status = Components:Paragraph({ Title = "Last change", Content = "Use any control below.", Icon = "activity" })
local function show(name)
	return function(...)
		local parts = {}
		for index = 1, select("#", ...) do
			local value = select(index, ...)
			parts[index] = if type(value) == "table" then table.concat(value, ", ") else tostring(value)
		end
		Status:Set(name .. ": " .. table.concat(parts, ", "))
	end
end

local Inputs = Components:Section({ Title = "Inputs", Icon = "sliders-horizontal" })
Inputs:Toggle({
	Title = "Switch",
	Description = "The default toggle",
	Badge = "New",
	Info = "Rows can carry a badge (New, Beta, Risky or your own) and this info icon for a longer explanation.",
	Callback = show("Switch"),
})
Inputs:Toggle({ Title = "Needs hookfunction", Description = "Locked when the executor lacks it", Requires = { "hookfunction" }, Callback = show("Needs hookfunction") })
Inputs:Toggle({ Title = "Checkbox", Style = "Checkbox", Callback = show("Checkbox") })
Inputs:Toggle({ Title = "Oval thumb", Thumb = "Oval", Default = true, Callback = show("Oval thumb") })
Inputs:Toggle({ Title = "Square thumb", Thumb = "Square", Callback = show("Square thumb") })
Inputs:Toggle({ Title = "Toggle with a colour", Color = { Default = Color3.fromRGB(91, 141, 239), Callback = show("Toggle colour") }, Callback = show("Toggle") })
Inputs:Slider({ Title = "Slider", Min = 0, Max = 100, Default = 40, Suffix = "%", Callback = show("Slider") })
Inputs:Slider({ Title = "Range slider", Min = 0, Max = 500, Step = 10, Range = true, Default = { 100, 300 }, Stacked = true, Callback = show("Range") })
Inputs:Segmented({
	Title = "Slider tooltip",
	Description = "The value bubble shown while a slider is dragged",
	Values = { "Rounded", "Sharp", "Pill", "Plain", "Off" },
	Stacked = true,
	Callback = function(style)
		Window:SetSliderTooltips(style ~= "Off", if style ~= "Off" then style else nil)
	end,
})
local outline = { enabled = true }
Inputs:Toggle({
	Title = "Toggle hover outline",
	Description = "The ring around a switch while its row is hovered",
	Default = true,
	Color = {
		Default = Color3.fromRGB(91, 141, 239),
		Callback = function(color)
			Window:SetToggleOutline(outline.enabled, color)
		end,
	},
	Callback = function(enabled)
		outline.enabled = enabled
		Window:SetToggleOutline(enabled)
	end,
})
Inputs:Stepper({ Title = "Stepper", Min = 1, Max = 10, Default = 3, Callback = show("Stepper") })
Inputs:Input({ Title = "Text input", Placeholder = "Type here", Callback = show("Input") })
Inputs:Input({ Title = "Number input", Numeric = true, Min = 0, Max = 999, Default = 50, Callback = show("Number") })
Inputs:Keybind({ Title = "Keybind", Description = "Backspace clears it", Default = Enum.KeyCode.E, Mode = "Toggle", Callback = show("Keybind") })
Inputs:ColorPicker({ Title = "Colour with alpha", Default = Color3.fromRGB(240, 82, 127), Alpha = true, Callback = show("Colour") })

local Choices = Components:Section({ Title = "Choices", Icon = "list", Side = "Right" })
Choices:Dropdown({ Title = "Dropdown", Values = { "Head", "Torso", "Left arm", "Right arm" }, Callback = show("Dropdown") })
Choices:Dropdown({ Title = "Multi dropdown", Values = { "Names", "Boxes", "Health", "Distance", "Tracers" }, Multi = true, Default = { "Names", "Boxes" }, Callback = show("Multi") })
Choices:Dropdown({
	Title = "Searchable dropdown",
	Searchable = true,
	Placeholder = "Pick a key",
	Values = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet" },
	Callback = show("Search dropdown"),
})
Choices:Segmented({ Title = "Segmented", Values = { "Low", "Medium", "High" }, Default = "Medium", Callback = show("Segmented") })

local Feedback = Components:Section({ Title = "Feedback", Icon = "bell", Side = "Right" })
local Bar = Feedback:Progress({ Title = "Progress", Value = 35 })
Feedback:Button({
	Title = "Advance progress",
	Callback = function()
		Bar:Set((Bar:Get() + 15) % 115)
	end,
})
Feedback:Segmented({
	Title = "Notice style",
	Values = { "Default", "Timer", "Compact", "Banner" },
	Stacked = true,
	Callback = function(style)
		Window:Notify({ Title = `A {string.lower(style)} notice`, Content = "Tap a notice to dismiss it.", Style = style, Duration = 6 })
	end,
})
Feedback:Button({
	Title = "Notify with progress",
	Description = "Fills over three seconds, then reports it finished",
	Icon = "download",
	Callback = function()
		local job = Window:Notify({ Title = "Downloading assets", Content = "0 of 10", Style = "Progress" })
		task.spawn(function()
			for done = 1, 10 do
				task.wait(0.3)
				job.SetProgress(done / 10)
				job.SetContent(`{done} of 10`)
			end
			job.Done("Assets downloaded")
		end)
	end,
})
Feedback:Button({
	Title = "Notify with a button",
	Description = "Stays for eight seconds and counts down",
	Icon = "bell",
	Callback = function()
		Window:Notify({
			Title = "Config saved",
			Content = "Your settings were written to disk.",
			Kind = "success",
			Duration = 8,
			Actions = { { Title = "Undo", Callback = show("Notice button") }, { Title = "Dismiss" } },
		})
	end,
})
Feedback:Button({ Title = "Filled button", Variant = "Filled", Callback = show("Filled button") })
Feedback:Button({ Title = "Outline button", Variant = "Outline", Callback = show("Outline button") })

local Content = Components:Section({ Title = "Content", Icon = "file-text" })
Content:Label("A label is one quiet line between controls.")
Content:Divider({ Title = "Divider" })
Content:Code({
	Title = "Loadstring",
	Code = 'local Halcyon = loadstring(game:HttpGet("' .. SOURCE .. '"))()\nlocal Window = Halcyon:CreateWindow({ Title = "My Hub" })',
})

local Tiers = Components:Section({ Title = "Tiers", Icon = "crown" })
Tiers:Paragraph({ Title = "Your tier", Content = "Signed in as " .. Window:GetTier() .. ". Rows above your tier show locked.", Icon = "badge-check" })
Tiers:Toggle({ Title = "Free key switch", Description = "Needs a Free key or better", Tier = "Free", Callback = show("Free key switch") })
Tiers:Toggle({ Title = "Paid switch", Description = "One row locked on its own", PaidOnly = true, Callback = show("Paid switch") })

local Vault = Components:Section({ Title = "Paid section", Icon = "gem", Side = "Right", PaidOnly = true, LockHint = "Enter HALCYON-PAID at the key prompt" })
Vault:Toggle({ Title = "Paid toggle", Callback = show("Paid toggle") })
Vault:Slider({ Title = "Paid slider", Min = 0, Max = 10, Default = 5, Callback = show("Paid slider") })

-- Layouts -----------------------------------------------------------------------

local Layouts = Window:Tab({ Title = "Layouts", Icon = "panel-left", Group = "Library" })
local Styles = Layouts:Section({ Title = "Navigation", Icon = "menu" })
Styles:Segmented({
	Title = "Tab style",
	Values = { "Sidebar", "Rail", "Top", "Dock" },
	Default = "Sidebar",
	Stacked = true,
	Callback = function(style)
		Window:SetTabStyle(style)
	end,
})
Styles:Segmented({
	Title = "Minimise to",
	Description = "What the minimise button leaves on screen",
	Values = { "Topbar", "Pill", "Chip" },
	Default = "Topbar",
	Stacked = true,
	Callback = function(style)
		Window:SetMinimizeStyle(style)
	end,
})
Layouts:Section({ Title = "Card section", Style = "Card", Side = "Right" }):Toggle({ Title = "Rows sit on one surface" })
Layouts:Section({ Title = "Outlined section", Style = "Outlined", Side = "Right" }):Toggle({ Title = "An outline and nothing else" })
Layouts:Section({ Title = "Flat section", Style = "Flat" }):Toggle({ Title = "Each row carries its own fill" })
Layouts:Section({ Title = "Glass section", Style = "Glass", Side = "Right" }):Toggle({ Title = "A see-through card" })
Layouts:Section({ Title = "Accent section", Style = "Accent", Badge = 2, Side = "Right" }):Toggle({ Title = "A stripe marks the group" })
Layouts:Section({ Title = "Header section", Style = "Header", Icon = "layers", IconColor = "accent" }):Toggle({ Title = "The title sits on a band" })
Layouts:Section({ Title = "Inset section", Style = "Inset", Description = "Sunk into the page, with a line that explains it." }):Toggle({ Title = "Rows on the page colour" })
Layouts:Section({ Title = "Collapsed section", Collapsed = true }):Label("Sections fold when their title is pressed.")

local Hud = Layouts:Section({ Title = "Overlays", Icon = "monitor" })
local overlays = {}
Hud:Toggle({
	Title = "Watermark",
	Description = "Title, executor, frame rate and time",
	Callback = function(enabled)
		if enabled then
			overlays.watermark = Window:Watermark({ Fields = { "Title", "Executor", "FPS", "Time" } })
		elseif overlays.watermark then
			overlays.watermark:Destroy()
			overlays.watermark = nil
		end
	end,
})
Hud:Toggle({
	Title = "Keybind list",
	Description = "Shows every bound key and which are active",
	Callback = function(enabled)
		if enabled then
			overlays.keybinds = Window:KeybindList()
		elseif overlays.keybinds then
			overlays.keybinds:Destroy()
			overlays.keybinds = nil
		end
	end,
})

-- Looks -----------------------------------------------------------------------
-- Every registered look side by side, each with the line that opts into it.

local Looks = Window:Tab({
	Title = "Looks",
	Icon = "palette",
	Group = "Library",
	Description = "Every look each control can take. Copy the line under a name to use it.",
})
Looks:Notice({ Title = "Tip", Content = 'Set Preset = "Glass" on CreateWindow to restyle the whole hub in one line.', Kind = "info", Dismissible = true })
local function opt(kind, name)
	return string.format('%s = "%s"', if kind == "Button" then "Variant" else "Style", name)
end

local ToggleLooks = Looks:Section({ Title = "Toggles", Icon = "toggle-left", Badge = #Halcyon:GetStyles("Toggle") })
for _, name in Halcyon:GetStyles("Toggle") do
	ToggleLooks:Toggle({ Title = name, Description = opt("Toggle", name), Style = name, Default = name == "Switch" })
end

local SliderLooks = Looks:Section({ Title = "Sliders", Icon = "sliders-horizontal", Side = "Right", Badge = #Halcyon:GetStyles("Slider") })
for _, name in Halcyon:GetStyles("Slider") do
	SliderLooks:Slider({ Title = name, Description = opt("Slider", name), Style = name, Min = 0, Max = 10, Default = 6, Stacked = true })
end
SliderLooks:Slider({ Title = "Percent", Description = 'Percent = true, Display = "Text"', Min = 0, Max = 200, Default = 120, Percent = true, Display = "Text" })
SliderLooks:Slider({ Title = "Fraction", Description = 'Prefix = "$", Display = "Fraction"', Min = 0, Max = 50, Default = 20, Prefix = "$", Display = "Fraction" })

local ButtonLooks = Looks:Section({ Title = "Buttons", Icon = "mouse-pointer-2" })
for _, name in Halcyon:GetStyles("Button") do
	ButtonLooks:Button({ Title = name, Description = if name == "Row" then opt("Button", name) else nil, Variant = name })
end
ButtonLooks:Button({ Title = "Hold to reset", Variant = "Danger", Hold = 1.2, Icon = "refresh-cw" })
ButtonLooks:Button({ Title = "Delete save", Variant = "Outline", Confirm = "Press again to delete", Icon = "trash-2" })
local fetch
fetch = ButtonLooks:Button({ Title = "Fetch data", Variant = "Soft", ShowDone = true, Icon = "download", Callback = function()
	fetch:SetLoading(true, "Fetching")
	task.wait(1.5)
	fetch:SetLoading(false)
end })
ButtonLooks:Buttons({ Buttons = { { Title = "Accept", Icon = "check" }, { Title = "Decline", Variant = "Ghost" } } })

local InputLooks = Looks:Section({ Title = "Inputs", Icon = "text-cursor-input", Side = "Right" })
for _, name in Halcyon:GetStyles("Input") do
	InputLooks:Input({ Title = name, Description = opt("Input", name), Style = name, Placeholder = "Type here", LeadingIcon = "search", Clearable = true })
end
InputLooks:Input({ Title = "Password", Description = "Password = true", Password = true, Default = "hunter2" })
InputLooks:Input({ Title = "Bio", Description = "MultiLine = true, Counter = true", MultiLine = true, MaxLength = 120, Counter = true, Lines = 3 })

local DropdownLooks = Looks:Section({ Title = "Dropdowns", Icon = "list" })
DropdownLooks:Dropdown({
	Title = "Box",
	Description = 'Style = "Box", rich options',
	Values = {
		{ Heading = "Melee" },
		{ Text = "Sword", Icon = "sword", Description = "Close range" },
		{ Text = "Hammer", Icon = "hammer", Description = "Slow, heavy" },
		{ Heading = "Ranged" },
		{ Text = "Bow", Icon = "crosshair" },
		{ Text = "Railgun", Icon = "zap", Disabled = true },
	},
})
DropdownLooks:Dropdown({ Title = "Minimal", Description = 'Style = "Minimal"', Style = "Minimal", Values = { "Low", "Medium", "High" } })
DropdownLooks:Dropdown({ Title = "Chips", Description = 'Style = "Chips", Multi = true', Style = "Chips", Multi = true, Values = { "Coins", "Gems", "Keys", "Eggs" }, Default = { "Coins", "Gems" } })
DropdownLooks:Dropdown({ Title = "Inline", Description = 'Style = "Inline"', Style = "Inline", Values = { "North", "South", "East", "West" } })
DropdownLooks:Dropdown({ Title = "Player", Description = "Players = true", Players = true, AllowNone = true, Placeholder = "Pick a player" })

local Pickers = Looks:Section({ Title = "Choices", Icon = "layout-grid", Side = "Right" })
Pickers:Radio({ Title = "Radio", Values = { "Safe", "Balanced", "Fast" }, Default = "Balanced" })
Pickers:Checklist({ Title = "Checklist", Values = { "Gold", "Gems", "Keys" }, SelectAll = true })
Pickers:Chips({ Title = "Chips", Values = { "PvP", "PvE", "Trading", "Events" }, Multi = true, Default = { "PvE" } })
Pickers:Tiles({
	Title = "Tiles",
	Items = {
		{ Title = "Lobby", Icon = "house", Description = "Spawn" },
		{ Title = "Arena", Icon = "swords", Description = "PvP" },
		{ Title = "Shop", Icon = "shopping-cart", Description = "Buy" },
	},
})
Pickers:Rating({ Title = "Rating", Default = 4 })

local Boxed = Looks:Section({ Title = "Tabs in a section", Icon = "layers", Tabs = { "Aim", "Visuals", "Misc" }, Side = "Right" })
Boxed:Toggle({ Title = "Silent aim" })
Boxed:Slider({ Title = "Field of view", Min = 10, Max = 180, Default = 90 })
Boxed:Tab("Visuals"):Toggle({ Title = "Player outlines" })
Boxed:Tab("Visuals"):ColorPicker({ Title = "Outline colour", Default = Color3.fromRGB(240, 82, 127) })
Boxed:Tab("Misc"):Label({ Title = "Each inner tab keeps its own rows.", Style = "Note" })

local Switched = Looks:Section({ Title = "Header switch", Icon = "power", Switch = { Default = true }, Side = "Right" })
local farmMode = Switched:Dropdown({ Title = "Mode", Values = { "Safe", "Fast" } })
Switched:Slider({ Title = "Fast speed", Min = 1, Max = 10, Default = 6 }):ShowWhen(farmMode, "Fast")
Switched:Label({ Title = "Pick Fast to reveal the speed row. The switch greys everything here." })

local Extras = Looks:Section({ Title = "More controls", Icon = "sparkles" })
Extras:Status({ Title = "Server", Status = "Online", Kind = "success", Pulse = true })
Extras:Countdown({ Title = "Boss spawns in", Seconds = 300, Done = "Spawned" })
Extras:DatePicker({ Title = "Event date", Time = true })
Extras:Keybind({ Title = "Dash", Default = Enum.KeyCode.Q, Style = "Keycap", ModePicker = true, Description = "Right-click the key to change its mode" })
Extras:Keybind({ Title = "Sprint", Default = Enum.KeyCode.LeftShift, Style = "Brackets" })
Extras:ColorPicker({ Title = "Tint", Palette = true, Default = Color3.fromRGB(91, 141, 239) })
Extras:Stepper({ Title = "Amount", Min = 0, Max = 99, Default = 5, Description = "Drag the number sideways" })
Extras:Accordion({ Title = "How do the looks work?", Content = 'Each control has a Style option. Set one look per control, or set Styles = { Toggle = "Slim" } on the window for all of them.' })
Extras:Label({ Title = "Info callouts explain a setting.", Style = "Info" })
Extras:Label({ Title = "Warnings flag something risky.", Style = "Warning" })
Extras:Label({ Title = "Success confirms it worked.", Style = "Success" })
Extras:Paragraph({ Title = "Paragraph with buttons", Content = "Text can carry <b>bold</b> and <i>italic</i> words.", Buttons = { { Title = "Docs" }, { Title = "Discord", Variant = "Outline" } } })
Extras:Table({
	Title = "Leaderboard",
	Columns = { "Player", { Title = "Kills", Align = "Right", Width = 0.25 }, { Title = "Level", Align = "Right", Width = 0.25 } },
	Rows = { { "Nova", 42, 18 }, { "Kite", 17, 31 }, { "Rook", 88, 12 }, { "Ash", 5, 40 } },
})

local Saves = Window:Tab({ Title = "Configs", Icon = "save", Group = "Library" })
Window:ConfigSection(Saves)
Window:SettingsTab({ Group = "Library", ScaleControl = "Slider" })
Components:SetBadge("New")

Window.OnUnload:Connect(function()
	for _, connection in connections do
		connection:Disconnect()
	end
	movement.enabled, movement.infiniteJump = false, false
	applyWalkSpeed()
	camera.FieldOfView = original.fieldOfView
end)

Window:LoadAutoload()
