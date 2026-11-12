-- Halcyon: a UI library for Roblox script hubs.
--
--   local Halcyon = loadstring(game:HttpGet(URL))()
--   local Window = Halcyon:CreateWindow({ Title = "My Hub" })
--   local Tab = Window:Tab({ Title = "Player", Icon = "user" })
--   Tab:Toggle({ Title = "Fly", Flag = "Fly", Callback = function(on) end })

local UserInputService = game:GetService("UserInputService")

local Config = require("./Core/Config")
local Create = require("./Core/Create")
local Dialog = require("./Components/Dialog")
local Drag = require("./Core/Drag")
local Env = require("./Core/Env")
local Extras = require("./Components/Extras")
local Icons = require("./Core/Icons")
local KeySystem = require("./Components/KeySystem")
local Motion = require("./Core/Motion")
local Notifications = require("./Components/Notifications")
local Palettes = require("./Themes/Palettes")
local Scope = require("./Core/Scope")
local SettingsTab = require("./Components/SettingsTab")
local Signal = require("./Core/Signal")
local Theme = require("./Core/Theme")
local Window = require("./Components/Window")

for _, palette in Palettes do
	assert(Theme.add(palette))
end
Theme.set(Palettes[1].Name)

-- State shared by every window this copy of the library creates.
local kit = {
	scope = Scope.new(),
	windows = {},
	displayOrder = 100,
	scale = 1,
	capturing = false,
	touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
}

function kit.notify(options)
	return Notifications.push(kit, options)
end

local Halcyon = {
	Version = "__VERSION__",
	ThemeChanged = Theme.Changed,
	Internal = {
		Config = Config,
		Create = Create,
		Drag = Drag,
		Env = Env,
		Icons = Icons,
		KeySystem = KeySystem,
		Motion = Motion,
		Scope = Scope,
		Signal = Signal,
		Theme = Theme,
		kit = kit,
	},
}

function Window:SettingsTab(options)
	return SettingsTab.build(self, options)
end

function Window:Watermark(options)
	return Extras.watermark(self, options)
end

function Window:KeybindList(options)
	return Extras.keybindList(self, options)
end

function Window:SetAccent(color)
	Theme.setAccent(color)
end

local function folderFor(options)
	return Env.safeName(options.Folder or options.Title) or "Default"
end

-- Creates the window. With a KeySystem this yields until a key is accepted
-- and returns nil if the player closes the prompt, so check the result.
function Halcyon:CreateWindow(options)
	options = options or {}
	if type(options) ~= "table" then
		error("CreateWindow expects a table of options", 2)
	end
	local folder = folderFor(options)

	-- Running a hub twice is the usual way a player breaks it. Windows are
	-- registered by folder in the executor's shared table, so a second run
	-- unloads the first even though it loaded its own copy of the library.
	local registry = Env.shared()
	registry.HalcyonWindows = registry.HalcyonWindows or {}
	local previous = registry.HalcyonWindows[folder]
	if previous then
		pcall(previous.Unload, previous)
	end

	if options.Font then
		Create.setFamily(options.Font)
	end
	if options.IconPack then
		Icons.setDefault(options.IconPack)
	end
	if options.DisplayOrder then
		kit.displayOrder = options.DisplayOrder
	end
	Notifications.configure(kit, options.Notifications)

	local access
	if options.KeySystem then
		access = KeySystem.prompt(kit, options.KeySystem, { folder = folder, title = options.Title or "Halcyon" })
		if not access then
			return nil
		end
	end

	local window = Window.new(kit, options, access)
	table.insert(kit.windows, window)
	registry.HalcyonWindows[folder] = window
	window.onUnloaded = function()
		if registry.HalcyonWindows[folder] == window then
			registry.HalcyonWindows[folder] = nil
		end
	end
	return window
end

-- Runs the key prompt without creating a window. Yields; returns the access
-- table ({ Tier, Rank, Tiers, Key, Saved, Data }) or nil when closed.
function Halcyon:Authenticate(options)
	return KeySystem.prompt(kit, options, { folder = folderFor(options), title = options.Title or "Halcyon" })
end

function Halcyon:Notify(options)
	return Notifications.push(kit, options)
end

-- Sets what every later notice uses unless it says otherwise: Duration in
-- seconds, Position ("TopLeft" to "BottomRight"), Progress (the countdown
-- bar) and MaxVisible.
function Halcyon:SetNotificationDefaults(settings)
	Notifications.configure(kit, settings)
end

function Halcyon:Dialog(options)
	return Dialog.open(kit, options)
end

function Halcyon:SetTheme(name)
	return Theme.set(name)
end

function Halcyon:GetTheme()
	return Theme.current.Name
end

function Halcyon:GetThemes()
	return Theme.names()
end

-- Registers a palette; see docs/themes.md. Returns ok and a message.
function Halcyon:AddTheme(palette)
	return Theme.add(palette)
end

function Halcyon:SetAccent(color)
	return Theme.setAccent(color)
end

function Halcyon:AddIconPack(name, icons)
	return Icons.addPack(name, icons)
end

function Halcyon:SetIconPack(name)
	return Icons.setDefault(name)
end

function Halcyon:SetFont(font)
	return Create.setFamily(font)
end

function Halcyon:GetExecutor()
	return Env.executor()
end

-- Unloads every window and removes everything the library put on screen.
function Halcyon:Unload()
	for _, window in table.clone(kit.windows) do
		window:Unload()
	end
	kit.scope:clean()
	kit.scope = Scope.new()
	kit.popup = nil
end

return Halcyon
