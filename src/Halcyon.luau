-- Halcyon: a UI library for Roblox script hubs.
--
--   local Halcyon = loadstring(game:HttpGet(URL))()
--   local Window = Halcyon:CreateWindow({ Title = "My Hub" })
--   local Tab = Window:Tab({ Title = "Player", Icon = "user" })
--   Tab:Toggle({ Title = "Fly", Flag = "Fly", Callback = function(on) end })

local UserInputService = game:GetService("UserInputService")

local Assets = require("./Core/Assets")
local Config = require("./Core/Config")
local ConfigSection = require("./Components/ConfigSection")
local Create = require("./Core/Create")
local Dialog = require("./Components/Dialog")
local Drag = require("./Core/Drag")
local Env = require("./Core/Env")
local Hairline = require("./Core/Hairline")
local Hud = require("./Components/Hud")
local Icons = require("./Core/Icons")
local KeySystem = require("./Components/KeySystem")
local Motion = require("./Core/Motion")
local Notifications = require("./Components/Notifications")
local QuickBar = require("./Components/QuickBar")
local Sheet = require("./Components/Sheet")
local Palettes = require("./Themes/Palettes")
local Presets = require("./Themes/Presets")
local Schema = require("./Core/Schema")
local Scope = require("./Core/Scope")
local SettingsTab = require("./Components/SettingsTab")
local Signal = require("./Core/Signal")
local Strings = require("./Core/Strings")
local Styles = require("./Core/Styles")
local Switches = require("./Components/Switches")
local Theme = require("./Core/Theme")
local Tokens = require("./Core/Tokens")
local Window = require("./Components/Window")

for _, palette in Palettes do
	assert(Theme.add(palette))
end
Theme.set(Palettes[1].Name)

-- State shared by every window this copy of the library creates.
local library = {
	scope = Scope.new(),
	windows = {},
	-- Near the top of the int32 range, so a game's own screens never cover
	-- the window. The overlay sits 10 above.
	displayOrder = 2147483000,
	scale = 1,
	listeningForKey = false,
	touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
}
Tokens.touch = library.touch

function library.notify(options)
	return Notifications.push(library, options)
end

local Halcyon = {
	Version = "__VERSION__",
	ThemeChanged = Theme.Changed,
	Internal = {
		Assets = Assets,
		Config = Config,
		Create = Create,
		Drag = Drag,
		Env = Env,
		Hairline = Hairline,
		Icons = Icons,
		KeySystem = KeySystem,
		Motion = Motion,
		Notifications = Notifications,
		Personalise = require("./Components/Personalise"),
		Schema = Schema,
		Scope = Scope,
		Signal = Signal,
		Strings = Strings,
		Styles = Styles,
		Theme = Theme,
		Tokens = Tokens,
		library = library,
	},
}

library.version = Halcyon.Version

function Window:SettingsTab(options)
	return SettingsTab.build(self, options)
end

-- The config block (name, save, load, delete, load on start) on any tab
-- or section.
function Window:ConfigSection(target, options)
	return ConfigSection.build(self, target, options)
end

-- A panel that slides over the page from the right; see Sheet.luau.
function Window:Sheet(options)
	return Sheet.new(self, options)
end

-- A floating bar of chosen toggles and buttons; see QuickBar.luau.
function Window:QuickBar(options)
	return QuickBar.new(self, options)
end

function Window:Watermark(options)
	return Hud.watermark(self, options)
end

function Window:KeybindList(options)
	return Hud.keybindList(self, options)
end

function Window:SetAccent(color)
	Theme.setAccent(color)
end

local function folderFor(options)
	return Env.safeName(options.Folder or options.Title) or "Default"
end

-- The language the player chose in this hub's Settings tab, if any.
local function savedLanguage(folder, options)
	if options.SavePreferences == false then
		return nil
	end
	local content = Env.read(`Halcyon/{folder}/settings.json`)
	if not content then
		return nil
	end
	local ok, saved = Env.decode(content)
	return if ok and type(saved) == "table" and type(saved.language) == "string" then saved.language else nil
end

-- Creates the window. With a KeySystem this yields until a key is accepted
-- and returns nil if the player closes the prompt, so check the result.
function Halcyon:CreateWindow(options)
	options = options or {}
	if type(options) ~= "table" then
		error("CreateWindow expects a table of options", 2)
	end
	-- Debug = true warns about unknown option names and looks; it stays on
	-- for the session until a window sets it false.
	if options.Debug ~= nil then
		Schema.enabled = options.Debug == true
	end
	Schema.check(`CreateWindow "{options.Title or ""}"`, options, Schema.window)
	-- A preset fills in whatever the hub did not set itself.
	options = Presets.apply(options)
	local folder = folderFor(options)

	-- Running a hub twice is the usual way a player breaks it. Windows are
	-- registered by folder in the executor's shared table, so a second run
	-- unloads the first even though it loaded its own copy of the library.
	local registry = Env.globals()
	registry.HalcyonWindows = registry.HalcyonWindows or {}
	local previous = registry.HalcyonWindows[folder]
	-- A rebuild in the same session (a new look, a reloaded hub) keeps the
	-- access the player was already given instead of asking for the key again.
	local granted = if previous and previous.access and previous.access.Tiers then previous.access else nil
	if previous then
		pcall(previous.Unload, previous)
	end

	-- The language comes first: the key prompt is the first thing drawn. A
	-- language the player picked in Settings wins over the hub's choice.
	Strings.setLanguage(savedLanguage(folder, options) or options.Language or "en")
	if type(options.Strings) == "table" then
		Strings.set(options.Strings)
	end

	-- Radius, Density and TextSize apply to everything built from here on.
	Tokens.reset()
	Tokens.set(options)
	if options.Font then
		Create.setFamily(options.Font)
	end
	-- Drawn before the font arrives, text first shows in a stand-in face and
	-- then jumps to size; on later runs the font is cached and this is instant.
	Create.waitForFont(2)
	if options.IconPack then
		Icons.setDefault(options.IconPack)
	end
	if options.DisplayOrder then
		library.displayOrder = options.DisplayOrder
	end
	Notifications.configure(library, options.Notifications)
	-- AccentGradient = true or a Color3; SafeStatusColors = true.
	if options.AccentGradient ~= nil then
		Theme.setGradient(options.AccentGradient)
	end
	if options.SafeStatusColors ~= nil then
		Theme.setSafeStatus(options.SafeStatusColors == true)
	end

	local access
	if options.KeySystem and granted and options.KeySystem.Reprompt ~= true then
		access = granted
	elseif options.KeySystem then
		access = KeySystem.prompt(library, options.KeySystem, { folder = folder, title = options.Title or "Halcyon" })
		if not access then
			return nil
		end
	end

	local window = Window.new(library, options, access)
	table.insert(library.windows, window)
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
	Create.waitForFont(2)
	return KeySystem.prompt(library, options, { folder = folderFor(options), title = options.Title or "Halcyon" })
end

function Halcyon:Notify(options)
	return Notifications.push(library, options)
end

-- Sets what every later notice uses unless it says otherwise: Duration in
-- seconds, Position ("TopLeft" to "BottomRight"), Progress (the countdown
-- bar) and MaxVisible.
function Halcyon:SetNotificationDefaults(settings)
	Notifications.configure(library, settings)
end

function Halcyon:ClearNotifications()
	Notifications.clear(library)
end

function Halcyon:Dialog(options)
	return Dialog.open(library, options)
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

-- Adds a look for one kind of control ("Toggle", "Slider", "Section" and so
-- on), described with the same fields as a built-in look. With `base`, only
-- the fields given change: AddStyle("Toggle", "Wide", { trackWidth = 48 }, "Switch").
function Halcyon:AddStyle(kind, name, spec, base)
	if base ~= nil then
		return Styles.extend(kind, base, name, spec)
	end
	return Styles.register(kind, name, spec)
end

-- The names of a kind's looks; with no kind, the kinds that have looks.
function Halcyon:GetStyles(kind)
	if kind == nil then
		local kinds = {}
		for name in Styles.kinds do
			table.insert(kinds, name)
		end
		table.sort(kinds)
		return kinds
	end
	return Styles.names(kind)
end

function Halcyon:GetPresets()
	return Presets.names()
end

-- Every switch name that CreateWindow, Window:Set and Window:Get accept.
function Halcyon:GetSwitches()
	return Switches.names()
end

-- Registers a preset: a table of window options (Radius, Density, Styles,
-- SectionStyle, ButtonEffect and so on) that `Preset = name` fills in.
function Halcyon:AddPreset(name, preset)
	return Presets.register(name, preset)
end

-- An image the hub brings itself: a URL, a workspace file or an asset id.
-- Returns the id when it is ready; otherwise loads it and calls
-- `callback(id, problem)`. Needs getcustomasset for URLs and files.
function Halcyon:Image(source, callback)
	return Assets.resolve(source, callback)
end

-- Warnings for option names Halcyon doesn't know, misspelt looks and
-- themes. For building; leave it off in a released hub.
function Halcyon:SetDebug(enabled)
	Schema.enabled = enabled == true
end

-- Translation. Codes: "en", "pt-br", "es", "vi", "id", "ru", "tr", "fr",
-- "de", or "auto" for the player's Roblox language. Text is read when a part
-- is built, so set these before CreateWindow (or use its Language option).
function Halcyon:SetLanguage(code)
	return Strings.setLanguage(code)
end

function Halcyon:GetLanguage()
	return Strings.language
end

-- { { Code, Name } } for every built-in language.
function Halcyon:GetLanguages()
	return Strings.languages()
end

-- Replaces Halcyon's own wording, keyed by the English text:
-- Halcyon:SetStrings({ ["Unload the hub?"] = "Close everything?" })
function Halcyon:SetStrings(map)
	Strings.set(map)
end

-- Every built-in text used so far, English key -> what is shown.
function Halcyon:GetStrings()
	return Strings.list()
end

function Halcyon:GetExecutor()
	return Env.executor()
end

-- Unloads every window and removes everything the library put on screen.
function Halcyon:Unload()
	for _, window in table.clone(library.windows) do
		window:Unload()
	end
	library.scope:clean()
	library.scope = Scope.new()
	library.popup = nil
end

-- Start fetching the font as the library loads, so it has usually arrived
-- by the time the hub makes its window.
Create.preload()

return Halcyon
