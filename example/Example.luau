-- Halcyon example: every element, the key prompt, tiers, configs and themes.
--
-- Executor:  loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/example/Example.luau"))()
-- Studio:    put dist/Halcyon.luau in a ModuleScript named "Halcyon" under
--            ReplicatedStorage and this file in a LocalScript.
--
-- The Dashboard, Player and Camera tabs read and change real things on your
-- own client, and unloading puts them back. The Components tab only shows
-- what each control looks like; its callbacks write to the line at its top.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SOURCE = "https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/dist/Halcyon.luau"
local REPOSITORY = "https://github.com/ScriptsForDays/Halcyon"
local DISCORD = "https://discord.gg/example"

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

-- Releases for the Updates tab, newest first. The dashboard's banner opens
-- the newest one as a What's new card.
local UPDATES: { { [string]: any } } = {
	{
		Version = "2.3.1",
		Date = "21 Nov 2026",
		Title = "Your hub in the player's language",
		Summary = "Translate = true shows a hub's own text in the player's language, and longer words stay inside their boxes.",
		Entries = {
			{ Kind = "New", Text = "Translate = true translates a hub's tabs, rows, options and notices into the player's language." },
			{ Kind = "Fixed", Text = "Longer words stay inside log filters, chart legends, stat cards and buttons." },
			{ Kind = "Improved", Text = "Item names, tier names, section titles and input placeholders shrink a little before they are cut off." },
		},
	},
	{
		Version = "2.3.0",
		Date = "18 Nov 2026",
		Title = "Pages, favourites and moving backgrounds",
		Summary = "Sub-pages, pop-out panels, new notices and controls, and a resize grip that stays under the pointer.",
		Entries = {
			{ Kind = "Fixed", Text = "The resize grip keeps the window's corner under the pointer wherever the window sits." },
			{ Kind = "New", Text = "Sub-pages, favourites, tabs you can drag into order, and sections that pop out into their own panel." },
			{ Kind = "New", Text = "Gauges, knobs, charts, an inventory grid, saved places and a 3D preview." },
			{ Kind = "New", Text = "Notices that count down around their border, update in place and pile into a deck." },
			{ Kind = "New", Text = "Moving backgrounds, share codes for settings, undo and nine languages." },
			{ Kind = "Improved", Text = "Search marks and counts matches; Enter steps through them." },
		},
	},
	{
		Version = "2.2.0",
		Date = "13 Nov 2026",
		Title = "Switches and new parts",
		Summary = "Turn any part off with false, and give your logo more room.",
		Entries = {
			{ Kind = "New", Text = "Every built-in part turns on or off with true or false, and Window:Set flips them live." },
			{ Kind = "New", Text = "Four header styles, including a big logo above the sidebar." },
			{ Kind = "New", Text = "Lists, tags, player lists, stats, graphs, logs, banners, links and menus." },
			{ Kind = "New", Text = "Side sheets and a floating quick bar." },
			{ Kind = "Improved", Text = "Notices pause while hovered, swipe away, and keep a history behind a bell." },
			{ Kind = "Improved", Text = "Shorter labels in the settings tab." },
		},
	},
	{
		Version = "2.1.0",
		Date = "12 Nov 2026",
		Title = "Images and invites",
		Summary = "Bring your own pictures, and point players at your Discord.",
		Entries = {
			{ Kind = "New", Text = "Discord buttons on the key prompt and the profile card." },
			{ Kind = "New", Text = "Images from a URL or a workspace file, anywhere the UI takes one." },
			{ Kind = "New", Text = "An image in the top bar, in six shapes." },
			{ Kind = "New", Text = "This update log." },
		},
	},
	{
		Version = "2.0.0",
		Date = "12 Nov 2026",
		Title = "A look for everything",
		Entries = {
			{ Kind = "New", Text = "Named looks for every control, and five presets." },
			{ Kind = "New", Text = "Ctrl+K searches every tab and setting." },
			{ Kind = "Improved", Text = "Players can change font, corners and spacing." },
			{ Kind = "Fixed", Text = "Inline dropdowns no longer stack their layouts." },
		},
	},
	{
		Version = "1.0.0",
		Date = "1 Nov 2026",
		Title = "First release",
		Entries = {
			{ Kind = "New", Text = "Window, tabs, sections and fifteen controls." },
			{ Kind = "Security", Text = "Key checks run before any feature loads." },
		},
	},
}

-- 4:05, or 1:04:05 past an hour.
local function clockText(seconds)
	seconds = math.floor(seconds)
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- What each notice look says when the Looks tab shows it.
local NOTICE_SAMPLES = {
	Default = { Title = "Auto farm on", Content = "Collecting in the Forest.", Kind = "success" },
	Timer = { Title = "Boss spawns soon", Content = "Head to the arena.", Kind = "warning" },
	Compact = { Title = "Saved", Kind = "success" },
	Banner = { Title = "Server restarts in 5 minutes", Content = "Finish your run first.", Kind = "warning" },
	Progress = { Title = "Loading map data", Content = "Reading 12 areas", Kind = "info" },
	Accent = { Title = "Trade request", Content = "Kite wants to trade.", Kind = "info" },
	Glass = { Title = "Daily reward ready", Content = "Claim it in the shop.", Kind = "success" },
	Achievement = { Title = "Level 10 reached", Content = "The Arena is open to you.", Kind = "success" },
	Snackbar = { Title = "Config deleted", Kind = "info" },
	Island = { Title = "Connected", Content = "Joined a new server.", Kind = "success" },
}

-- The hub is built by `start` so the Looks tab can rebuild it in another
-- look. Each tab has its own builder, and they share one `hub` table: the
-- window, the log, what to put back on unload. `Window` is always the
-- current window, rebuilt or not.
local Window
local start

local function buildDashboard(hub)
	local Window, player = hub.window, hub.player
	local Dashboard = Window:Tab({ Title = "Dashboard", Icon = "gauge", Group = "Features" })

	local News = Dashboard:Section({ Title = "News", Icon = "flag" })
	News:Banner({
		Title = "Halcyon 2.3",
		Text = UPDATES[1].Summary,
		Button = {
			Title = "What's new",
			Callback = function()
				Window:Changelog({ Version = UPDATES[1].Version, Entries = UPDATES[1].Entries, Force = true })
			end,
		},
	})

	-- The one section with its own moving background: a light that follows
	-- the pointer. It can also float over the game while the hub is hidden.
	local Session = Dashboard:Section({
		Title = "Session",
		Icon = "clock",
		PopOut = true,
		Background = { Kind = "Glow", Intensity = 0.55 },
	})
	local figures = Session:Stats({
		Columns = 4,
		Items = {
			{ Title = "FPS", Value = 0, Key = "fps", Icon = "gauge" },
			{ Title = "Ping", Value = 0, Unit = "ms", Key = "ping", Icon = "wifi" },
			{ Title = "Memory", Value = 0, Unit = "MB", Key = "memory", Icon = "cpu" },
			{ Title = "Players", Value = #Players:GetPlayers(), Key = "players", Icon = "users" },
		},
	})
	local playtime = Session:Stat({ Title = "Time in game", Value = clockText(time()), Icon = "timer", Style = "Plain" })

	local Performance = Dashboard:Section({ Title = "Performance", Icon = "activity", Side = "Right" })
	local frameGauge = Performance:Gauge({
		Title = "Frame rate",
		Description = "Against 60 fps",
		Max = 60,
		Suffix = "",
		Size = 64,
		Thresholds = { { At = 0.5, Role = "warning" }, { At = 0.25, Role = "danger" } },
	})
	local frameGraph = Performance:Graph({ Title = "Frame rate history", Style = "Area", Suffix = " fps", Min = 0, Max = 30 })
	local pingGraph = Performance:Graph({ Title = "Ping", Style = "Bars", Suffix = " ms", Min = 0, Max = 30 })

	local Activity = Dashboard:Section({ Title = "Activity", Icon = "terminal", Side = "Right" })
	local log = Activity:Log({ Title = "Events", Height = 150, MaxLines = 100 })
	function hub.note(text: string, level: string?)
		log:Add(text, level)
	end

	local Server = Dashboard:Section({ Title = "Server", Icon = "users" })
	local watching
	-- Pressing Spectate again on the same player puts the camera back.
	local function spectate(target)
		if target == nil or target == watching then
			watching = nil
			hub.camera.CameraSubject = hub.humanoid()
			hub.note("Camera back on you")
			return
		end
		local character = target.Character
		local subject = character and character:FindFirstChildOfClass("Humanoid")
		if not subject then
			hub.note(target.DisplayName .. " has no character yet", "warn")
			return
		end
		watching = target
		hub.camera.CameraSubject = subject
		hub.note("Spectating " .. target.DisplayName)
	end
	function hub.stopSpectating()
		if watching then
			spectate(nil)
		end
	end
	Server:PlayerList({
		Title = "Players",
		Actions = { { Title = "Spectate", Icon = "eye", Callback = spectate } },
	})

	local Links = Dashboard:Section({ Title = "Links", Icon = "link", Side = "Right" })
	Links:Link({ Title = "Source code", Url = REPOSITORY, Icon = "code" })
	Links:Link({ Title = "Discord", Url = DISCORD, Icon = "message-circle" })

	-- Counts frames for a second at a time, then updates every figure once.
	local frames, since = 0, os.clock()
	table.insert(hub.connections, RunService.Heartbeat:Connect(function()
		frames += 1
		local now = os.clock()
		if now - since < 1 then
			return
		end
		local fps = math.round(frames / (now - since))
		local ping = math.round(player:GetNetworkPing() * 1000)
		frames, since = 0, now
		figures:Set("fps", fps)
		figures:Set("ping", ping)
		figures:Set("memory", math.round(Stats:GetTotalMemoryUsageMb()))
		frameGraph:Push(fps)
		frameGauge:Set(math.min(fps, 60))
		pingGraph:Push(ping)
		playtime:Set(clockText(time()))
	end))
	table.insert(hub.connections, Players.PlayerAdded:Connect(function(joined)
		figures:Set("players", #Players:GetPlayers())
		hub.note(joined.DisplayName .. " joined")
	end))
	-- PlayerRemoving fires while the player is still in the list.
	table.insert(hub.connections, Players.PlayerRemoving:Connect(function(leaving)
		figures:Set("players", #Players:GetPlayers() - 1)
		hub.note(leaving.DisplayName .. " left")
	end))

	return Dashboard
end

local function buildPlayer(hub)
	local Window, player = hub.window, hub.player
	local movement = { enabled = false, speed = 32, infiniteJump = false }
	hub.movement = movement

	local function applyWalkSpeed()
		local current = hub.humanoid()
		if not current then
			return
		end
		if movement.enabled then
			hub.original.walkSpeed = hub.original.walkSpeed or current.WalkSpeed
			current.WalkSpeed = movement.speed
		elseif hub.original.walkSpeed then
			current.WalkSpeed = hub.original.walkSpeed
			hub.original.walkSpeed = nil
		end
	end
	hub.applyWalkSpeed = applyWalkSpeed

	table.insert(hub.connections, player.CharacterAdded:Connect(function(character)
		-- A new character starts at the game's own speed again.
		hub.original.walkSpeed = nil
		character:WaitForChild("Humanoid", 5)
		applyWalkSpeed()
	end))
	table.insert(hub.connections, UserInputService.JumpRequest:Connect(function()
		local current = hub.humanoid()
		if movement.infiniteJump and current then
			current:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end))

	local Player = Window:Tab({ Title = "Player", Icon = "person-standing", Group = "Features" })
	local Movement = Player:Section({ Title = "Movement", Icon = "footprints" })
	Movement:Toggle({
		Title = "Custom walk speed",
		Description = "Kept after respawning",
		Flag = "WalkSpeedEnabled",
		Keybind = { Default = Enum.KeyCode.V, Flag = "WalkSpeedKey" },
		Callback = function(enabled)
			movement.enabled = enabled
			applyWalkSpeed()
			hub.note(if enabled then "Walk speed on" else "Walk speed off")
		end,
	})
	local speed
	speed = Movement:Slider({
		Title = "Walk speed",
		Min = 16,
		Max = 120,
		Default = movement.speed,
		Suffix = " st/s",
		Flag = "WalkSpeed",
		-- Starts in the Favourites tab; players star more from any row's menu.
		Favourite = true,
		Menu = {
			{ Title = "Back to 32", Icon = "refresh-cw", Callback = function()
				speed:Set(32)
			end },
		},
		Callback = function(value)
			movement.speed = value
			applyWalkSpeed()
		end,
	})
	Movement:Toggle({
		Title = "Infinite jump",
		Description = "Jump again in mid-air",
		Flag = "InfiniteJump",
		Favourite = true,
		Callback = function(enabled)
			movement.infiniteJump = enabled
			hub.note(if enabled then "Infinite jump on" else "Infinite jump off")
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
							local current = hub.humanoid()
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
		Title = "Only on your screen",
		Content = "These change your own character for you alone. The game's server can still undo them.",
		Icon = "info",
	})
	Character:Viewport({ Title = "Your character", Character = true, Height = 170, Spin = 25 })

	-- Places are saved with the config, so they come back next time.
	local Places = Player:Section({ Title = "Places", Icon = "map-pin" })
	Places:Waypoints({
		Title = "Saved places",
		Description = "Stand somewhere, name it, save it",
		Flag = "Places",
		Callback = function(list)
			hub.note(`{#list} saved places`)
		end,
	})
end

local function buildCamera(hub)
	local Window, camera = hub.window, hub.camera
	local Camera = Window:Tab({ Title = "Camera", Icon = "camera", Group = "Features" })
	local View = Camera:Section({ Title = "View", Icon = "eye" })
	View:Slider({
		Title = "Field of view",
		Min = 40,
		Max = 120,
		Default = math.round(hub.original.fieldOfView),
		Suffix = "°",
		Stacked = true,
		Flag = "FieldOfView",
		Favourite = true,
		Callback = function(degrees)
			camera.FieldOfView = degrees
		end,
	})
	View:Button({
		Title = "Reset field of view",
		Icon = "refresh-cw",
		Callback = function()
			Window.Flags.FieldOfView:Set(math.round(hub.original.fieldOfView))
		end,
	})
end

local function buildComponents(hub)
	local Window = hub.window
	local Components = Window:Tab({ Title = "Components", Icon = "layout-grid", Group = "Library" })
	local Status = Components:Paragraph({ Title = "Last change", Content = "Nothing yet", Icon = "activity" })
	local function show(name)
		return function(...)
			local count = select("#", ...)
			if count == 0 then
				Status:Set(name)
				return
			end
			local parts = {}
			for index = 1, count do
				local value = select(index, ...)
				parts[index] = if type(value) == "table" then table.concat(value, ", ") else tostring(value)
			end
			Status:Set(name .. ": " .. table.concat(parts, ", "))
		end
	end

	local Inputs = Components:Section({ Title = "Inputs", Icon = "sliders-horizontal" })
	Inputs:Toggle({
		Title = "Switch",
		Badge = "New",
		Info = "Saved with your config, so it stays on next time.",
		Callback = show("Switch"),
	})
	Inputs:Toggle({ Title = "Silent aim", Requires = { "hookfunction" }, Callback = show("Silent aim") })
	Inputs:Toggle({ Title = "Checkbox", Style = "Checkbox", Callback = show("Checkbox") })
	Inputs:Toggle({ Title = "Oval thumb", Thumb = "Oval", Default = true, Callback = show("Oval thumb") })
	Inputs:Toggle({ Title = "Square thumb", Thumb = "Square", Callback = show("Square thumb") })
	Inputs:Toggle({ Title = "With a colour", Color = { Default = Color3.fromRGB(91, 141, 239), Callback = show("Toggle colour") }, Callback = show("Toggle") })
	local percent
	percent = Inputs:Slider({
		Title = "Slider",
		Description = "Right-click or hold for a menu",
		Min = 0,
		Max = 100,
		Default = 40,
		Suffix = "%",
		Menu = {
			{ Title = "Reset", Icon = "refresh-cw", Callback = function()
				percent:Set(40)
			end },
			{ Title = "Max", Icon = "arrow-up", Callback = function()
				percent:Set(100)
			end },
		},
		Callback = show("Slider"),
	})
	Inputs:Slider({ Title = "Range slider", Min = 0, Max = 500, Step = 10, Range = true, Default = { 100, 300 }, Stacked = true, Callback = show("Range") })
	Inputs:Segmented({
		Title = "Slider tooltip",
		Values = { "Rounded", "Sharp", "Pill", "Plain", "Off" },
		Stacked = true,
		Callback = function(style)
			Window:SetSliderTooltips(style ~= "Off", if style ~= "Off" then style else nil)
		end,
	})
	local outline = { enabled = true }
	Inputs:Toggle({
		Title = "Hover ring",
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
		Placeholder = "Pick a letter",
		Values = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet" },
		Callback = show("Searchable"),
	})
	Choices:Segmented({ Title = "Segmented", Values = { "Low", "Medium", "High" }, Default = "Medium", Callback = show("Segmented") })

	if not hub.pause() then
		return
	end
	local Lists = Components:Section({ Title = "Lists", Icon = "list", Badge = "New" })
	Lists:List({ Title = "Route", Values = { "Forest", "Mines", "Docks", "Volcano" }, Default = "Mines", Callback = show("Route") })
	Lists:List({
		Title = "Ores",
		Multi = true,
		Values = {
			{ Text = "Iron", Icon = "hammer", Description = "Common" },
			{ Text = "Gold", Icon = "coins", Description = "Rare" },
			{ Text = "Ruby", Icon = "gem", Description = "Very rare" },
		},
		Default = { "Gold" },
		Callback = show("Ores"),
	})
	Lists:List({ Title = "Priority", Description = "Drag to reorder", Values = { "Boss", "Chest", "Mob", "Quest" }, Reorder = true, Callback = show("Priority") })
	local names = {}
	for _, other in Players:GetPlayers() do
		table.insert(names, other.Name)
	end
	Lists:Tags({ Title = "Whitelist", Placeholder = "Add a name", Suggestions = names, Max = 10, Callback = show("Whitelist") })

	local Panels = Components:Section({ Title = "Menus and panels", Icon = "layers", Side = "Right", Badge = "New" })
	Panels:MenuButton({
		Title = "Config",
		Items = {
			{ Title = "Rename", Icon = "text-cursor-input", Callback = show("Rename") },
			{ Title = "Duplicate", Icon = "copy", Callback = show("Duplicate") },
			{ Divider = true },
			{ Title = "Delete", Icon = "trash-2", Danger = true, Callback = show("Delete") },
		},
	})
	local pair = Panels:Group({ Columns = 2 })
	pair:Toggle({ Title = "Auto farm", Callback = show("Auto farm") })
	pair:Toggle({ Title = "Auto sell", Callback = show("Auto sell") })
	local sheet = Window:Sheet({ Title = "Farm options" })
	sheet:Slider({ Title = "Radius", Min = 10, Max = 200, Default = 60, Suffix = " st", Callback = show("Radius") })
	sheet:Dropdown({ Title = "Target", Values = { "Nearest", "Strongest", "Weakest" }, Default = "Nearest", Callback = show("Target") })
	sheet:Toggle({ Title = "Skip bosses", Callback = show("Skip bosses") })
	Panels:Button({
		Title = "Farm options",
		Icon = "sliders-horizontal",
		Callback = function()
			sheet:Open()
		end,
	})
	local quick
	Panels:Toggle({
		Title = "Quick bar",
		Description = "Stays when the hub is hidden",
		Callback = function(on)
			if on and not quick then
				quick = Window:QuickBar({
					Items = {
						"WalkSpeedEnabled",
						"InfiniteJump",
						{ Title = "Reset field of view", Icon = "refresh-cw", Callback = function()
							Window.Flags.FieldOfView:Set(math.round(hub.original.fieldOfView))
						end },
					},
				})
			elseif not on and quick then
				quick:Destroy()
				quick = nil
			end
		end,
	})

	local Feedback = Components:Section({ Title = "Feedback", Icon = "bell", Side = "Right" })
	local Bar = Feedback:Progress({ Title = "Progress", Value = 35 })
	Feedback:Button({
		Title = "Add 15%",
		Callback = function()
			Bar:Set((Bar:Get() + 15) % 115)
		end,
	})
	Feedback:Segmented({
		Title = "Notice style",
		Values = { "Default", "Timer", "Compact", "Banner" },
		Stacked = true,
		Callback = function(style)
			Window:Notify({ Title = "Config saved", Content = "Saved as Main.", Style = style, Duration = 6 })
		end,
	})
	Feedback:Button({
		Title = "Notify with progress",
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
		Icon = "bell",
		Callback = function()
			Window:Notify({
				Title = "Config deleted",
				Content = "Main was removed.",
				Kind = "warning",
				Duration = 8,
				Actions = { { Title = "Undo", Callback = show("Undo") }, { Title = "Dismiss" } },
			})
		end,
	})
	Feedback:Button({ Title = "Filled button", Variant = "Filled", Callback = show("Filled button") })
	Feedback:Button({ Title = "Outline button", Variant = "Outline", Callback = show("Outline button") })

	-- Controls added in 2.3, with sample data.
	local Added = Components:Section({ Title = "New in 2.3", Icon = "sparkles", Badge = "New", Description = "Sample data; nothing here changes the game." })
	Added:Toggle({ Title = "Legit aim", Exclusive = "aim mode", Callback = show("Legit aim") })
	Added:Toggle({ Title = "Rage aim", Exclusive = "aim mode", Confirm = "Other players may report this.", Callback = show("Rage aim") })
	Added:Keybind({ Title = "Panic key", Modifiers = true, Default = "Ctrl+P", Callback = show("Panic key") })
	Added:Button({ Title = "Rejoin", Icon = "refresh-cw", Keybind = Enum.KeyCode.J, Callback = show("Rejoin") })
	Added:Input({
		Title = "Target name",
		Placeholder = "At least 3 letters",
		Validate = function(text)
			if #text > 0 and #text < 3 then
				return false, "Use at least 3 letters."
			end
			return true
		end,
		Callback = show("Target name"),
	})
	Added:Knob({ Title = "Volume", Max = 10, Default = 6, Callback = show("Volume") })
	Added:Chart({
		Title = "Loot",
		Type = "Donut",
		Height = 110,
		Items = { { Name = "Coins", Value = 640 }, { Name = "Gems", Value = 120 }, { Name = "Eggs", Value = 40 } },
	})
	Added:Chart({
		Title = "Coins per minute",
		Type = "Bars",
		Labels = { "1", "2", "3", "4", "5" },
		Series = { { Name = "Coins", Values = { 12, 30, 22, 41, 38 } }, { Name = "Gems", Values = { 2, 4, 3, 9, 6 } } },
	})
	Added:ItemGrid({
		Title = "Eggs",
		Sort = "Rarity",
		Items = {
			{ Title = "Basic egg", Rarity = "Common", Count = 12, Icon = "package", Value = "basic" },
			{ Title = "Forest egg", Rarity = "Uncommon", Count = 4, Icon = "leaf", Value = "forest" },
			{ Title = "Ocean egg", Rarity = "Rare", Count = 2, Icon = "droplet", Value = "ocean" },
			{ Title = "Shadow egg", Rarity = "Epic", Count = 1, Icon = "ghost", Value = "shadow" },
			{ Title = "Golden egg", Rarity = "Legendary", Count = 1, Icon = "crown", Value = "golden" },
		},
		Callback = show("Egg"),
	})
	local Tuning = Added:Page({ Title = "Prediction", Description = "A sub-page: its own sections, a breadcrumb, Escape to go back." })
	Tuning:Section({ Title = "Lead" }):Slider({ Title = "Lead time", Min = 0, Max = 1, Step = 0.05, Default = 0.2, Callback = show("Lead time") })
	Added:Button({
		Title = "Show the new notices",
		Icon = "bell",
		Callback = function()
			Window:Notify({ Title = "Config saved", Content = "Saved as Main.", Kind = "success", Countdown = "Edge", Duration = 6 })
			Window:Notify({ Title = "Boss spawns soon", Content = "Head to the arena.", Kind = "warning", Countdown = "Ring", Duration = 6 })
			Window:Notify({ Id = "example-status", Title = "Farming", Content = "Updates in place", Duration = 6 })
		end,
	})

	local Content = Components:Section({ Title = "Content", Icon = "file-text", Side = "Right" })
	Content:Label("Last updated 13 Nov 2026")
	Content:Divider({ Title = "Advanced" })
	Content:Code({
		Title = "Loadstring",
		Code = 'local Halcyon = loadstring(game:HttpGet("' .. SOURCE .. '"))()\nlocal Window = Halcyon:CreateWindow({ Title = "My Hub" })',
	})

	local Tiers = Components:Section({ Title = "Tiers", Icon = "crown", Side = "Right" })
	Tiers:Paragraph({ Title = "Your tier", Content = Window:GetTier(), Icon = "badge-check" })
	Tiers:Toggle({ Title = "Free feature", Tier = "Free", Callback = show("Free feature") })
	Tiers:Toggle({ Title = "Paid feature", PaidOnly = true, Callback = show("Paid feature") })

	local Vault = Components:Section({ Title = "Paid section", Icon = "gem", Side = "Right", PaidOnly = true, LockHint = "Enter HALCYON-PAID at the key prompt" })
	Vault:Toggle({ Title = "Paid toggle", Callback = show("Paid toggle") })
	Vault:Slider({ Title = "Paid slider", Min = 0, Max = 10, Default = 5, Callback = show("Paid slider") })
end

-- Switches the Layouts tab flips live with Window:Set, and their labels.
local LIVE_SWITCHES = {
	{ "Search", "Search box" },
	{ "Profile", "Profile card" },
	{ "ShowVersion", "Version tag" },
	{ "Minimize", "Minimise button" },
	{ "Close", "Close button" },
	{ "Resize", "Resize grip" },
	{ "Drag", "Dragging" },
	{ "Shadow", "Shadow" },
	{ "Tooltips", "Tooltips" },
	{ "Animations", "Animations" },
	{ "Blur", "Background blur" },
	{ "NotificationCenter", "Notice bell" },
	{ "Watermark", "Watermark" },
	{ "KeybindList", "Keybind list" },
}

local function buildLayouts(hub)
	local Window = hub.window
	local Layouts = Window:Tab({ Title = "Layouts", Icon = "panel-left", Group = "Library" })
	local Navigation = Layouts:Section({ Title = "Navigation", Icon = "menu" })
	Navigation:Segmented({
		Title = "Tab style",
		Values = { "Sidebar", "Rail", "Top", "Dock" },
		Default = "Sidebar",
		Stacked = true,
		Callback = function(style)
			Window:SetTabStyle(style)
		end,
	})
	Navigation:Segmented({
		Title = "Minimise to",
		Values = { "Topbar", "Pill", "Chip" },
		Default = "Topbar",
		Stacked = true,
		Callback = function(style)
			Window:SetMinimizeStyle(style)
		end,
	})

	local Live = Layouts:Section({ Title = "Window switches", Icon = "toggle-left" })
	for _, entry in LIVE_SWITCHES do
		local name, title = entry[1], entry[2]
		Live:Toggle({
			Title = title,
			Description = name,
			Default = Window:Get(name) == true,
			Callback = function(on)
				Window:Set(name, on)
			end,
		})
	end

	-- Every section look, down the right-hand column.
	Layouts:Section({ Title = "Card section", Style = "Card", Side = "Right" }):Toggle({ Title = "Auto farm" })
	Layouts:Section({ Title = "Outlined section", Style = "Outlined", Side = "Right" }):Toggle({ Title = "Auto sell" })
	Layouts:Section({ Title = "Flat section", Style = "Flat", Side = "Right" }):Toggle({ Title = "Auto rebirth" })
	Layouts:Section({ Title = "Glass section", Style = "Glass", Side = "Right" }):Toggle({ Title = "Night vision" })
	Layouts:Section({ Title = "Accent section", Style = "Accent", Badge = 2, Side = "Right" }):Toggle({ Title = "Auto quest" })
	Layouts:Section({ Title = "Header section", Style = "Header", Icon = "layers", IconColor = "accent", Side = "Right" }):Toggle({ Title = "Player outlines" })
	Layouts:Section({ Title = "Inset section", Style = "Inset", Description = "Only works in the lobby.", Side = "Right" }):Toggle({ Title = "Auto queue" })
	local Panel = Layouts:Section({ Title = "Panel section", Style = "Panel", Side = "Right" })
	Panel:Toggle({ Title = "Auto collect" })
	Panel:Slider({ Title = "Range", Min = 5, Max = 50, Default = 20, Suffix = " st" })
	Layouts:Section({ Title = "Folded section", Collapsed = true, Side = "Right" }):Toggle({ Title = "Auto claim rewards" })
end

local function buildLooks(hub, look)
	local Window = hub.window
	local Looks = Window:Tab({ Title = "Looks", Icon = "palette", Group = "Library" })

	-- The window-wide choices, which need a rebuild to show.
	local chosen = table.clone(look)
	local Trial = Looks:Section({ Title = "Try a look", Icon = "palette" })
	local function picker(title, kind, key)
		local names = Halcyon:GetStyles(kind)
		Trial:Dropdown({
			Title = title,
			Description = key,
			Values = names,
			-- What the window is using now, whether picked here or set by a preset.
			Default = chosen[key] or Window.styles[kind] or names[1],
			Callback = function(name)
				chosen[key] = name
			end,
		})
	end
	local presets = Halcyon:GetPresets()
	Trial:Dropdown({
		Title = "Preset",
		Description = "Preset",
		Values = presets,
		Default = chosen.Preset or presets[1],
		Callback = function(name)
			chosen.Preset = name
		end,
	})
	picker("Window", "Window", "WindowStyle")
	picker("Open animation", "Open", "OpenAnimation")
	picker("Tab marker", "TabIndicator", "TabIndicator")
	picker("Window buttons", "Controls", "TopbarControls")
	picker("Top-bar image", "TopbarImage", "TopbarImageStyle")
	picker("Header", "Header", "HeaderStyle")
	for _, key in { "Logo", "Icon", "TopbarImage", "Background" } do
		Trial:Toggle({
			Title = if key == "TopbarImage" then "Top-bar image" elseif key == "Background" then "Moving background" else key,
			Description = key .. " = false",
			Default = chosen[key] ~= false,
			Callback = function(on)
				chosen[key] = if on then nil else false
			end,
		})
	end
	Trial:Buttons({
		Buttons = {
			{
				Title = "Rebuild hub",
				Icon = "refresh-cw",
				Callback = function()
					task.defer(start, chosen)
				end,
			},
			{
				Title = "Reset to default",
				Variant = "Ghost",
				Callback = function()
					task.defer(start, {})
				end,
			},
		},
	})
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

	if not hub.pause() then
		return
	end
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

	if not hub.pause() then
		return
	end
	local NoticeLooks = Looks:Section({ Title = "Notices", Icon = "bell", Badge = #Halcyon:GetStyles("Notification") })
	for _, name in Halcyon:GetStyles("Notification") do
		local sample = NOTICE_SAMPLES[name] or { Title = name .. " notice", Kind = "info" }
		NoticeLooks:Button({
			Title = name,
			Description = 'Style = "' .. name .. '"',
			Callback = function()
				local notice = Window:Notify({
					Title = sample.Title,
					Content = sample.Content,
					Kind = sample.Kind,
					Style = name,
					Duration = 5,
					Actions = if name == "Snackbar" then { { Title = "Undo" } } else nil,
				})
				if name == "Progress" then
					task.spawn(function()
						for step = 1, 10 do
							task.wait(0.25)
							notice.SetProgress(step / 10)
						end
						notice.Done("Map data loaded")
					end)
				end
			end,
		})
	end
	NoticeLooks:Button({ Title = "Open the command palette", Variant = "Soft", Icon = "search", Spotlight = { Title = "New", Text = "Ctrl+K jumps to any setting.", Id = "palette" }, Callback = function()
		Window:OpenPalette()
	end })

	local Panels = Looks:Section({ Title = "Panels", Icon = "layers", Side = "Right" })
	Panels:Button({
		Title = "Loading screen",
		Description = "Window:Loading()",
		Callback = function()
			local loader = Window:Loading({ Title = "Setting up", Text = "Finding the map" })
			-- A real hub reports its own steps; these stand in for them.
			for step, label in { "Finding the map", "Reading the shop", "Building the menu" } do
				loader.SetProgress(step / 3, label)
				task.wait(0.6)
			end
			loader.Done()
		end,
	})
	Panels:Button({
		Title = "What's new",
		Description = "Window:Changelog()",
		Callback = function()
			Window:Changelog({
				Force = true,
				Entries = {
					{ Kind = "New", Text = "Auto farm works in the Volcano." },
					{ Kind = "Improved", Text = "Teleports wait for the map to load." },
					{ Kind = "Fixed", Text = "Walk speed no longer resets on respawn." },
				},
			})
		end,
	})
	Panels:Button({
		Title = "Lock screen",
		Description = "Window:Lock()",
		Callback = function()
			Window:Lock({
				Title = "Down for maintenance",
				Text = "The game updated. The hub is being patched.",
				Button = { Title = "Unlock", Callback = function()
					Window:Unlock()
				end },
			})
		end,
	})
	Panels:Button({
		Title = "Confirm with a countdown",
		Description = "Delay = 3",
		Callback = function()
			Window:Dialog({
				Title = "Reset every setting?",
				Content = "Your saved configs stay; only this session's choices reset.",
				Dismissible = true,
				Buttons = { { Title = "Cancel", Variant = "Ghost" }, { Title = "Reset", Variant = "Danger", Delay = 3 } },
			})
		end,
	})

	if not hub.pause() then
		return
	end
	local Boxed = Looks:Section({ Title = "Tabs in a section", Icon = "layers", Tabs = { "Aim", "Visuals", "Idle" }, Side = "Right" })
	Boxed:Toggle({ Title = "Silent aim" })
	Boxed:Slider({ Title = "Field of view", Min = 10, Max = 180, Default = 90 })
	Boxed:Tab("Visuals"):Toggle({ Title = "Player outlines" })
	Boxed:Tab("Visuals"):ColorPicker({ Title = "Outline colour", Default = Color3.fromRGB(240, 82, 127) })
	Boxed:Tab("Idle"):Toggle({ Title = "Anti-AFK" })

	local Switched = Looks:Section({ Title = "Header switch", Icon = "power", Switch = { Default = true }, Side = "Right" })
	local farmMode = Switched:Dropdown({ Title = "Mode", Values = { "Safe", "Fast" } })
	Switched:Slider({ Title = "Fast speed", Min = 1, Max = 10, Default = 6 }):ShowWhen(farmMode, "Fast")

	local Extras = Looks:Section({ Title = "More controls", Icon = "layout-grid" })
	Extras:Status({ Title = "Server", Status = "Online", Kind = "success", Pulse = true })
	Extras:Countdown({ Title = "Boss spawns in", Seconds = 300, Done = "Spawned" })
	Extras:DatePicker({ Title = "Event date", Time = true })
	Extras:Keybind({ Title = "Dash", Default = Enum.KeyCode.Q, Style = "Keycap", ModePicker = true, Description = "Right-click to change the mode" })
	Extras:Keybind({ Title = "Sprint", Default = Enum.KeyCode.LeftShift, Style = "Brackets" })
	Extras:ColorPicker({ Title = "Tint", Palette = true, Default = Color3.fromRGB(91, 141, 239) })
	Extras:Stepper({ Title = "Amount", Min = 0, Max = 99, Default = 5, Description = "Drag to change" })
	Extras:Accordion({ Title = "Setting a look", Content = 'Give one control a Style, or set Styles = { Toggle = "Slim" } on CreateWindow to change them all.' })
	Extras:Label({ Title = "Works best in a private server.", Style = "Info" })
	Extras:Label({ Title = "Fast mode can get you kicked.", Style = "Warning" })
	Extras:Label({ Title = "Connected to the key server.", Style = "Success" })
	Extras:Paragraph({ Title = "Patch 4.2", Content = "<b>Faster</b> farming in the Mines and <i>fewer</i> disconnects.", Buttons = { { Title = "Docs" }, { Title = "Discord", Variant = "Outline" } } })
	Extras:Table({
		Title = "Leaderboard",
		Columns = { "Player", { Title = "Kills", Align = "Right", Width = 0.25 }, { Title = "Level", Align = "Right", Width = 0.25 } },
		Rows = { { "Nova", 42, 18 }, { "Kite", 17, 31 }, { "Rook", 88, 12 }, { "Ash", 5, 40 } },
	})
end

function start(look)
	look = look or {}
	Window = Halcyon:CreateWindow({
		-- What the Looks tab picked; nil keeps Halcyon's defaults.
		Preset = look.Preset,
		WindowStyle = look.WindowStyle,
		OpenAnimation = look.OpenAnimation,
		TabIndicator = look.TabIndicator,
		TopbarControls = look.TopbarControls,
		TopbarImageStyle = look.TopbarImageStyle or "Rounded",
		HeaderStyle = look.HeaderStyle,
		-- false hides them; nil keeps the defaults below.
		Logo = if look.Logo == false then false else nil,
		Icon = if look.Icon == false then false else "layers",
		-- Any image works here: an asset id, a workspace file or a URL. URLs
		-- and files need an executor with getcustomasset; Studio shows the
		-- fallback icon instead.
		TopbarImage = if look.TopbarImage == false then false else "https://i.insider.com/602ee9ced3ad27001837f2ac?width=700",
		Title = "Halcyon",
		Subtitle = "Example hub",
		Version = "v2.3.1",
		Folder = "HalcyonExample",
		-- Pick a language in Settings and this hub's own text follows it.
		Translate = true,
		-- A slow aurora behind everything; the Looks tab can turn it off.
		Background = if look.Background == false then nil else { Kind = "Aurora", Sheen = true },
		-- A Favourites tab; players star rows from a row's right-click or
		-- long-press menu.
		Favourites = true,
		TabReorder = true,
		Notifications = { Countdown = "Edge" },
		-- package.json on GitHub carries the newest version number.
		UpdateCheck = { Url = "https://raw.githubusercontent.com/ScriptsForDays/Halcyon/main/package.json", Current = "2.3.1" },
		Theme = "Midnight",
		TabStyle = "Sidebar",
		CommandPalette = true,
		NotificationCenter = true,
		Profile = { Avatar = "Headshot", ShowClock = true, Discord = DISCORD },
		UpdateLog = { Title = "Updates", Group = "Library", Popup = false, Updates = UPDATES },
		KeySystem = {
			Title = "Halcyon example",
			Discord = DISCORD,
			Note = "Demo keys: HALCYON-FREE and HALCYON-PAID. Keyless needs none.",
			Tiers = {
				{ Name = "Keyless", NoKey = true, Description = "No key. Free and Paid rows stay locked." },
				{ Name = "Free", Keys = { "HALCYON-FREE" }, Duration = 86400, Description = "Lasts a day.", Link = REPOSITORY },
				{ Name = "Paid", Keys = { "HALCYON-PAID" }, Description = "Unlocks every row.", Link = REPOSITORY },
			},
		},
	})
	if not Window then
		return
	end

	local player = Players.LocalPlayer
	local hub = {
		window = Window,
		player = player,
		camera = Workspace.CurrentCamera,
		connections = {},
		note = function(_text: string, _level: string?) end,
	}
	-- What the example changed, so unload can put it back.
	hub.original = { fieldOfView = hub.camera.FieldOfView }
	-- Lets a big tab finish over a few frames; false once the hub is gone.
	function hub.pause()
		task.wait()
		return not hub.closed
	end
	function hub.humanoid()
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	-- Unloading puts back whatever the tabs built so far had changed.
	Window.OnUnload:Connect(function()
		hub.closed = true
		for _, connection in hub.connections do
			connection:Disconnect()
		end
		if hub.stopSpectating then
			hub.stopSpectating()
		end
		if hub.movement then
			hub.movement.enabled, hub.movement.infiniteJump = false, false
			hub.applyWalkSpeed()
		end
		hub.camera.FieldOfView = hub.original.fieldOfView
	end)

	local Dashboard = buildDashboard(hub)
	Dashboard:SetBadge("New")

	-- The first tab draws straight away and the rest follow a frame apart,
	-- so opening the hub never stalls on one long frame. A rebuild or an
	-- unload in the meantime stops the rest.
	local window = hub.window
	local steps = {
		function()
			buildPlayer(hub)
			buildCamera(hub)
		end,
		function()
			buildComponents(hub)
		end,
		function()
			buildLayouts(hub)
		end,
		function()
			buildLooks(hub, look)
		end,
		function()
			window:ConfigSection(window:Tab({ Title = "Configs", Icon = "save", Group = "Library" }))
			local Settings = window:SettingsTab({ Group = "Library", ScaleControl = "Slider", Personalise = true, ThemeBuilder = true })
			Settings:About({
				Description = "An example hub built with Halcyon.",
				Credits = { { Name = "Halcyon", Role = "UI library" } },
				Links = { { Title = "Source", Url = REPOSITORY } },
			})
		end,
	}
	for _, step in steps do
		task.wait()
		if hub.closed then
			return
		end
		step()
	end

	hub.note(`Loaded on the {window:GetTier()} tier`, "success")
	Window:LoadAutoload()
end

start()
