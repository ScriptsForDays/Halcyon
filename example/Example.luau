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
		Note = "Free needs no key. To try the paid tier, enter HALCYON-PAID.",
		Tiers = {
			{ Name = "Free", NoKey = true, Description = "Everything except the rows marked Paid." },
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
Inputs:Toggle({ Title = "Switch", Description = "The default toggle", Callback = show("Switch") })
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
for _, kind in { "info", "success", "warning", "danger" } do
	Feedback:Button({
		Title = "Notify: " .. kind,
		Icon = "bell",
		Callback = function()
			Window:Notify({ Title = "A " .. kind .. " notice", Content = "Tap a notice to dismiss it.", Kind = kind })
		end,
	})
end
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

Window:SettingsTab({ Group = "Library" })

Window.OnUnload:Connect(function()
	for _, connection in connections do
		connection:Disconnect()
	end
	movement.enabled, movement.infiniteJump = false, false
	applyWalkSpeed()
	camera.FieldOfView = original.fieldOfView
end)

Window:LoadAutoload()
