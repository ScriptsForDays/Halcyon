-- The window: top bar, navigation in one of four styles, pages, search, the
-- menu key, preferences and unload. Everything it creates is owned by its
-- scope, so Unload is one clean().

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CommandPalette = require("./CommandPalette")
local Assets = require("../Core/Assets")
local Config = require("../Core/Config")
local Create = require("../Core/Create")
local Dialog = require("./Dialog")
local Drag = require("../Core/Drag")
local Env = require("../Core/Env")
local Hairline = require("../Core/Hairline")
local Header = require("./Header")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Notifications = require("./Notifications")
local Panels = require("./Panels")
local Personalise = require("./Personalise")
local Popup = require("./Popup")
local Profile = require("./Profile")
local Registry = require("../Elements/Registry")
local Signal = require("../Core/Signal")
local Resize = require("../Core/Resize")
local Strings = require("../Core/Strings")
local Styles = require("../Core/Styles")
local Switches = require("./Switches")
local Tab = require("./Tab")
local UpdateLog = require("./UpdateLog")
local Theme = require("../Core/Theme")
local Schema = require("../Core/Schema")
local Favourites = require("./Favourites")
local TabOrder = require("./TabOrder")
local SearchFocus = require("./SearchFocus")
local Background = require("../Core/Background")
local Services = require("./Services")

-- Below this window width the side navigation becomes a strip of tabs.
local NARROW = 560
-- Two columns of sections need at least this much page width.
local COLUMNS = 520
local LANES = { Sidebar = 196, Rail = 60 }
local STRIPS = { Top = 46, Dock = 58 }
-- Where a minimised window goes: its own top bar, a pill carrying its
-- title, or the round open button.
local MINIMIZE = { Topbar = true, Pill = true, Chip = true }
for _, name in { "Sidebar", "Rail", "Top", "Dock" } do
	Styles.register("Navigation", name, { lane = LANES[name], strip = STRIPS[name] })
end
for _, name in { "Topbar", "Pill", "Chip" } do
	Styles.register("Minimize", name, {})
end

-- The window's surface (kind "Window").
--   transparency  how much of the game shows through the window
--   sheen         a soft light across the top, for glass
--   gradient      the background runs into a hint of the accent
--   image         the hub's BackgroundImage fills the window
Styles.register("Window", "Solid", {})
Styles.register("Window", "Glass", { transparency = 0.14, sheen = true, edge = "text", edgeTransparency = 0.82 })
Styles.register("Window", "Gradient", { gradient = true })
Styles.register("Window", "Image", { image = true })

-- How the window appears and leaves (kind "Open"): scale grows from this
-- size, offset slides from this many pixels away, unroll opens down from
-- the top bar. Rise is the default because it only moves the window: a
-- scaling open redraws every label at each step, so text looks like it
-- starts small and grows.
Styles.register("Open", "Rise", { offset = Vector2.new(0, 14) })
Styles.register("Open", "Pop", { scale = 0.96 })
Styles.register("Open", "Zoom", { scale = 0.86, timing = "spring" })
Styles.register("Open", "Drop", { offset = Vector2.new(0, -18) })
Styles.register("Open", "Slide", { offset = Vector2.new(-28, 0) })
Styles.register("Open", "Unroll", { unroll = true })
Styles.register("Open", "None", {})

-- How a newly opened tab's page arrives (kind "PageTransition").
Styles.register("PageTransition", "Rise", { offset = Vector2.new(0, 8) })
Styles.register("PageTransition", "Slide", { offset = Vector2.new(16, 0) })
Styles.register("PageTransition", "None", {})

-- The minimise and close buttons (kind "Controls"): icons on the right, or
-- three coloured dots on the left.
Styles.register("Controls", "Default", {})
Styles.register("Controls", "Mac", { dots = true })

-- The picture before the title (kind "TopbarImage"): corner is its radius
-- (-1 round), ring adds an accent outline, dot a small status dot.
Styles.register("TopbarImage", "Circle", { corner = -1 })
Styles.register("TopbarImage", "Rounded", { corner = 8 })
Styles.register("TopbarImage", "Square", { corner = 3 })
Styles.register("TopbarImage", "Squircle", { corner = 11, size = 30 })
Styles.register("TopbarImage", "Ring", { corner = -1, ring = true })
Styles.register("TopbarImage", "Badge", { corner = 8, dot = true })

-- Snapping pulls a dragged window to a screen edge or the centre line
-- within this many pixels.
local SNAP = 18
-- A blurred rounded square, the same image asset WindUI stretches around
-- its window. It is sliced 99 px in from each edge.
local SHADOW_IMAGE = "rbxassetid://8992230677"
local SHADOW_SPREAD = 50
local MIN_SIZE = Vector2.new(420, 300)
-- The group key for tabs the player pinned to the top of the navigation.
local PINNED = "Pinned (Halcyon)"
local DEFAULT_SIZE = Vector2.new(740, 500)
local PREFERENCES_VERSION = 1

local Window = {}
Window.__index = Window

local function readPreferences(path)
	local content = Env.read(path)
	if not content then
		return {}
	end
	local ok, saved = Env.decode(content)
	if not ok or type(saved) ~= "table" or saved.version ~= PREFERENCES_VERSION then
		return {}
	end
	return saved
end

local function keyFromName(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local ok, key = pcall(function()
		return Enum.KeyCode[name]
	end)
	return if ok then key else nil
end

local function centred(instance)
	instance.AnchorPoint = Vector2.new(0.5, 0.5)
	instance.Position = UDim2.fromScale(0.5, 0.5)
	return instance
end

function Window.new(library, options, access)
	-- A copy with the plainer switch names filled in; the hub's table is left alone.
	options = Switches.normalize(options)
	local self = setmetatable({}, Window)
	self.library, self.options = library, options
	self.scope = library.scope:child()
	self.folder = Env.safeName(options.Folder or options.Title) or "Default"
	self.config = Config.new(self.folder, Config.gameKey(options.Configs))
	-- Callback failures, newest last; see Window:recordError.
	self.Errors, self.ErrorsChanged = {}, Signal.new()
	self.showErrors = options.ShowErrors ~= false
	self.preferencesPath = `Halcyon/{self.folder}/settings.json`
	self.Flags, self.tabs, self.keybinds, self.gated = {}, {}, {}, {}
	-- Pages made with Tab:Page; they search like tabs but stay out of the
	-- navigation, which marks the tab they belong to instead.
	self.subPages = {}
	-- Fires (section, open) when a section moves into its own panel or back.
	self.SectionPopped = Signal.new()
	-- Fires (latest, notes) when UpdateCheck finds a newer version.
	self.UpdateAvailable = Signal.new()
	self.OnUnload, self.KeybindsChanged, self.TabChanged, self.Tick = Signal.new(), Signal.new(), Signal.new(), Signal.new()
	-- Fires (action, name) after a config is saved, loaded, deleted or set to autoload.
	self.ConfigChanged = Signal.new()
	self.query = ""
	self.Visible = true
	self.Title, self.Subtitle, self.Icon = options.Title or "Halcyon", options.Subtitle, options.Icon
	-- The default look for each kind of control, from Styles and the older
	-- single options; an element's own Style wins over it.
	self.styles = Styles.defaults(options)
	-- The header look decides the top bar's height (see Header.luau).
	self.header = Styles.pick("Header", nil, self)
	self.topbarHeight = self.header.height or 48
	self.sectionStyle = options.SectionStyle
	-- The value bubble over a slider's knob while it is dragged.
	self.sliderTooltips = options.SliderTooltips ~= false
	self.sliderTooltipStyle = options.SliderTooltipStyle or "Rounded"
	-- The ring drawn around a toggle's switch while its row is hovered. With
	-- no colour given it uses the theme's accent.
	self.toggleOutline = options.ToggleOutline ~= false
	self.toggleOutlineColor = options.ToggleOutlineColor
	self.toggleThumb = options.ToggleThumb or "Circle"
	-- The light that crosses locked rows and sections every few seconds.
	self.lockShimmer = options.LockShimmer ~= false
	-- The finish on filled, outline and danger buttons: "Sweep", "Ripple",
	-- "Lift", "Glow" or "None".
	self.buttonEffect = options.ButtonEffect or "Sweep"

	if not access and type(options.Tiers) == "table" then
		local rank = table.find(options.Tiers, options.Tier) or 1
		access = {
			Tiers = table.clone(options.Tiers),
			Tier = options.Tiers[rank],
			Rank = rank,
			PaidRank = table.find(options.Tiers, options.PaidTier or "Paid"),
		}
	elseif not access then
		-- No key system: the window is Keyless, which ranks below every tier.
		access = { Tiers = {}, Tier = "Keyless", Rank = 0, Keyless = true }
	end
	self.access = access
	-- The wording on a locked row's badge. "{tier}" becomes the tier's name.
	self.lockText = options.LockText or Strings.get("Requires {tier}")
	self.paidLockText = options.PaidLockText or Strings.get("Paid only")
	-- The second line on a locked section's overlay.
	self.lockHint = options.LockHint
	self.paidLockHint = options.PaidLockHint or Strings.get("Unlock with a paid key")
	self.lockedSections = {}

	-- Saved preferences win over the script's defaults: they are the player's choice.
	local saved = if options.SavePreferences == false then {} else readPreferences(self.preferencesPath)
	-- Only a language the player picked is saved; the hub's own choice is
	-- applied again on every run.
	self.languagePicked = if type(saved.language) == "string" then saved.language else nil
	-- Popped-out panels by section: where they sit and whether they were out.
	self.popOutState = if type(saved.popOuts) == "table" then saved.popOuts else {}
	-- The player's own look: themes they made, then what applies at build
	-- time; the rest is restored once the window exists.
	self.personal, self.customThemes = {}, {}
	Personalise.loadThemes(self, saved.themes)
	Personalise.restore(self, saved.personal, true)
	local function style(name)
		return if LANES[name] or STRIPS[name] then name else nil
	end
	self.tabStyle = style(saved.tabStyle) or style(options.TabStyle) or "Sidebar"
	self.scale = math.clamp(tonumber(saved.scale) or tonumber(options.Scale) or 1, 0.75, 1.25)
	self.toggleKey = keyFromName(saved.toggleKey) or options.ToggleKey or Enum.KeyCode.RightShift
	self.minimizeStyle = if MINIMIZE[saved.minimizeStyle] then saved.minimizeStyle elseif MINIMIZE[options.MinimizeStyle] then options.MinimizeStyle else "Topbar"
	self.collapsedGroups = {}
	for _, name in if type(saved.collapsedGroups) == "table" then saved.collapsedGroups else options.CollapsedGroups or {} do
		if type(name) == "string" then
			self.collapsedGroups[name] = true
		end
	end
	self.profile = Profile.settings(options.Profile)
	if type(saved.anonymous) == "boolean" then
		self.profile.Anonymous = saved.anonymous
	end
	-- The player's own look: restored early for what applies at build time,
	-- and again once the window exists.
	-- The newest update-log release the player has opened.
	self.updateSeen = if type(saved.updateSeen) == "string" then saved.updateSeen else nil
	-- The last version whose "What's new" card the player saw.
	self.changelogSeen = if type(saved.changelog) == "string" then saved.changelog else nil
	-- Spotlights the player already dismissed.
	self.seenSpotlights = {}
	for _, id in if type(saved.seen) == "table" then saved.seen else {} do
		if type(id) == "string" then
			self.seenSpotlights[id] = true
		end
	end
	if type(saved.reducedMotion) == "boolean" then
		Motion.reduced = saved.reducedMotion
	end
	if type(options.Theme) == "table" then
		local added, message = Theme.add(options.Theme)
		if added then
			Theme.set(options.Theme.Name)
		else
			warn("[Halcyon] " .. message)
		end
	elseif options.Theme then
		Theme.set(options.Theme)
	end
	if type(saved.theme) == "string" then
		Theme.set(saved.theme)
	end

	local size = options.Size
	self.size = if typeof(size) == "Vector2" then size elseif typeof(size) == "UDim2" then Vector2.new(size.X.Offset, size.Y.Offset) else DEFAULT_SIZE
	-- Where the player last left the window and how big they made it.
	local function point(value)
		return if type(value) == "table" and type(value.x) == "number" and type(value.y) == "number" then Vector2.new(value.x, value.y) else nil
	end
	self.size = point(saved.size) or self.size
	self.placed = point(saved.position)
	library.scale = self.scale
	Hairline.setScale(self.scale)

	self.gui = Create.new("ScreenGui", { Name = "Halcyon", DisplayOrder = library.displayOrder, Parent = Mount.parent() })
	self.scope:add(self.gui)
	-- Active, so a press on the window never reaches the game underneath.
	self.root = centred(Create.new("Frame", {
		Name = "Window",
		Active = true,
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "background" },
		Parent = self.gui,
	}))
	Create.corner(12, self.root)
	Create.stroke("stroke", self.root)
	self.uiScale = Create.new("UIScale", { Scale = self.scale, Parent = self.root })
	-- layout() already fits the window to the screen; this floor and ceiling
	-- hold even when something sets its size directly.
	Create.new("UISizeConstraint", { MinSize = Vector2.new(240, 48), MaxSize = Vector2.new(1600, 1000), Parent = self.root })
	if options.Shadow ~= false then
		self:buildShadow()
	end
	self:buildSurface()

	self:buildTopbar()
	self.body = Create.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, self.topbarHeight),
		Size = UDim2.new(1, 0, 1, -self.topbarHeight),
		ClipsDescendants = true,
		Parent = self.root,
	})
	self.pages = Create.new("Frame", { Name = "Pages", Parent = self.body })
	self.empty = centred(Create.new("TextLabel", {
		Name = "Empty",
		Text = "",
		Size = UDim2.new(1, -32, 0, 40),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Theme = { TextColor3 = "textMuted" },
		Parent = self.pages,
	}))

	self.openButton = Create.new("TextButton", {
		Name = "Open",
		Text = "",
		Size = UDim2.fromOffset(48, 48),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Visible = false,
		Theme = { BackgroundColor3 = "surface" },
		Parent = self.gui,
	})
	Create.corner(-1, self.openButton)
	Create.stroke("stroke", self.openButton)
	centred(Create.icon(self.Icon or "menu", 22, "accent", self.openButton))
	Drag.move(self.scope, self.openButton, self.openButton, {
		onTap = function()
			self:restore()
		end,
	})

	self.pill = Create.new("TextButton", {
		Name = "Pill",
		Text = "",
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Visible = false,
		Theme = { BackgroundColor3 = "surface" },
		Parent = self.gui,
	})
	Create.corner(-1, self.pill)
	Create.stroke("stroke", self.pill)
	Create.padding(self.pill, 16, 0)
	Create.list(self.pill, "Horizontal", 8)
	Create.icon(self.Icon or "menu", 16, "accent", self.pill)
	self.pillLabel = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = self.Title,
		TextSize = 13,
		Weight = "bold",
		LayoutOrder = 1,
		Theme = { TextColor3 = "text" },
		Parent = self.pill,
	})
	Create.icon("maximize-2", 14, "textMuted", self.pill).LayoutOrder = 2
	Drag.move(self.scope, self.pill, self.pill, {
		onTap = function()
			self:restore()
		end,
	})

	if not library.touch and options.Resizable ~= false then
		self:buildGrip()
	end

	self.scope:connect(UserInputService.InputBegan, function(input, processed)
		if not processed and not library.listeningForKey and self.toggleKey and input.KeyCode == self.toggleKey then
			self:menuKey()
		end
	end)
	self.scope:connect(self.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:layout()
	end)
	self.scope:add(Theme.Changed:Connect(function()
		self:savePreferences()
	end))

	if options.CommandPalette then
		self.paletteBound = true
		CommandPalette.bind(self)
	end
	Personalise.restore(self, saved.personal, false)
	-- The update log is built once the hub's own tabs exist, so it comes
	-- after them in the navigation.
	local updates = UpdateLog.settings(options.UpdateLog)
	if updates then
		self.pendingUpdates = {}
		task.defer(function()
			if self.scope.cleaned then
				return
			end
			local log = UpdateLog.build(self, updates)
			for _, update in self.pendingUpdates do
				log.add(update)
			end
			self.pendingUpdates = nil
		end)
	end
	if options.FocusRing ~= false then
		self:buildFocusRing()
	end
	Switches.build(self)
	if options.TabReorder then
		TabOrder.setup(self, saved.tabOrder)
	end
	Services.watchUpdates(self, options.UpdateCheck)
	self:layout()
	-- After the first layout, which picks the navigation the tab goes in.
	if options.Favourites then
		Favourites.setup(self, saved.favourites)
	end
	self:pop(true)
	return self
end

-- Turns one of the window's switches on or off while the hub runs:
-- Window:Set("Search", false), Window:Set("Watermark", { Fields = {...} }).
-- Returns false for a name it doesn't know.
function Window:Set(name, value)
	return Switches.set(self, name, value)
end

-- The current state of a switch, or nil for a name it doesn't know.
function Window:Get(name)
	return Switches.get(self, name)
end

-- An accent ring that marks the control a gamepad (or the keyboard's UI
-- navigation) has selected, in place of Roblox's default box. With a
-- gamepad, ButtonSelect shows the window and puts the selection on its
-- first tab.
function Window:buildFocusRing()
	local ring = Create.new("Frame", { Name = "FocusRing", Size = UDim2.new(1, 6, 1, 6), Position = UDim2.fromOffset(-3, -3), BackgroundTransparency = 1 })
	Create.corner(10, ring)
	Create.new("UIStroke", { Thickness = 2, Theme = { Color = "focus" }, Parent = ring })
	self.scope:add(ring)
	local function mark(instance)
		if instance:IsA("GuiButton") or instance:IsA("TextBox") then
			instance.SelectionImageObject = ring
		end
	end
	for _, instance in self.gui:GetDescendants() do
		mark(instance)
	end
	self.scope:connect(self.gui.DescendantAdded, mark)
	self.scope:connect(UserInputService.InputBegan, function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.ButtonSelect then
			return
		end
		self:Toggle()
		if self.Visible and self.selected and self.selected.button then
			GuiService.SelectedObject = self.selected.button
		end
	end)
end

-- The player's own look, changed live and saved: "Font", "TextSize",
-- "Radius", "Density", "Transparency", "NoticePosition", "AccentGradient"
-- or "SafeStatus". Returns true when the value was accepted.
function Window:SetPersonal(key, value)
	return Personalise.set(self, key, value)
end

function Window:PersonaliseSection(tab, options)
	return Personalise.section(self, tab, options)
end

function Window:ThemeBuilder(tab, options)
	return Personalise.builder(self, tab, options)
end

-- A loading screen over the window that moves only when the hub reports
-- progress. Returns { SetProgress(fraction, text), Done() }.
function Window:Loading(options)
	return Panels.loading(self, options)
end

-- A "What's new" card shown once per version. See Panels.changelog.
function Window:Changelog(options)
	return Panels.changelog(self, options)
end

function Window:About(tab, options)
	return Panels.about(self, tab, options)
end

-- Adds a release to the update log: { Version, Date, Title, Summary,
-- Image, Pinned, Entries = { { Kind = "New" | "Improved" | "Fixed" |
-- "Removed" | "Security", Text } } }. Needs UpdateLog on the window.
function Window:AddUpdate(update)
	if self.updateLog then
		self.updateLog.add(update)
	elseif self.pendingUpdates then
		table.insert(self.pendingUpdates, update)
	else
		warn("[Halcyon] AddUpdate needs UpdateLog = true on CreateWindow.")
	end
end

-- Blocks the window with a message until Unlock.
function Window:Lock(options)
	return Panels.lock(self, options)
end

function Window:Unlock()
	return Panels.unlock(self)
end

-- Opens the search over every tab and row; see CommandPalette.luau.
function Window:OpenPalette()
	return CommandPalette.open(self)
end

-- A soft drop shadow under the window: one nine-slice image, stretched
-- around the window's edges. `Shadow = false` leaves it out;
-- `ShadowTransparency` and `ShadowImage` adjust it.
function Window:buildShadow()
	local root, scope, options = self.root, self.scope, self.options
	local shadow = Create.new("Frame", { Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 0, Parent = self.gui })
	scope:add(shadow)
	local scale = Create.new("UIScale", { Scale = self.scale, Parent = shadow })
	Create.new("ImageLabel", {
		Name = "Image",
		Size = UDim2.new(1, SHADOW_SPREAD * 2, 1, SHADOW_SPREAD * 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		Image = options.ShadowImage or SHADOW_IMAGE,
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = math.clamp(tonumber(options.ShadowTransparency) or 0.5, 0, 1),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(99, 99, 99, 99),
		Parent = shadow,
	})

	-- The window clips its contents, so the shadow is a sibling that copies
	-- its place, size, scale and visibility whenever one of them changes.
	local function follow()
		shadow.Size = root.Size
		shadow.Position = root.Position
		shadow.Visible = root.Visible and not self.shadowOff
		scale.Scale = self.uiScale.Scale
	end
	for _, property in { "Size", "Position", "Visible" } do
		scope:connect(root:GetPropertyChangedSignal(property), follow)
	end
	scope:connect(self.uiScale:GetPropertyChangedSignal("Scale"), follow)
	follow()
	self.shadow = shadow
end

-- The window's surface: solid, glass, a gradient or the hub's image, and
-- how see-through it is. Transparency (0 to 0.6) overrides the look's own.
function Window:buildSurface()
	local look = Styles.pick("Window", nil, self)
	local root, options = self.root, self.options
	self.surfaceLook = look
	if look.edge then
		local stroke = root:FindFirstChildOfClass("UIStroke")
		Theme.bind(stroke, "Color", look.edge)
		stroke.Transparency = look.edgeTransparency or 0
	end
	if look.sheen then
		Create.new("Frame", {
			Name = "Sheen",
			Size = UDim2.new(1, 0, 0, 140),
			ZIndex = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.94,
			Parent = root,
		}, {
			Create.new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
	end
	if look.gradient then
		local gradient = Create.new("UIGradient", { Rotation = 35, Parent = root })
		local function tint()
			local base = Theme.color("background")
			gradient.Color = ColorSequence.new(base:Lerp(Theme.color("accent"), 0.1), base)
		end
		tint()
		-- The gradient multiplies a white fill, so the window's own colour is white.
		Theme.unbind(root, "BackgroundColor3")
		root.BackgroundColor3 = Color3.new(1, 1, 1)
		self.scope:connect(Theme.Changed, tint)
	end
	if look.image or options.BackgroundImage then
		local image = Create.new("ImageLabel", {
			Name = "Backdrop",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			ScaleType = Enum.ScaleType.Crop,
			-- The page colour lies over the picture so text stays readable.
			ImageTransparency = math.clamp(tonumber(options.BackgroundImageTransparency) or 0.75, 0, 1),
			Parent = root,
		})
		Create.corner(12, image)
		Icons.apply(image, options.BackgroundImage)
		self.backdrop = image
	end
	self:SetTransparency(tonumber(options.Transparency) or look.transparency or 0)
	if options.Background then
		self:SetBackground(options.Background)
	end
end

-- A moving background behind the window's content (see Core/Background);
-- nil or false removes it.
function Window:SetBackground(spec)
	if self.movingBackground then
		self.movingBackground.Destroy()
		self.movingBackground = nil
	end
	-- How much of the background shows through solid section cards.
	local seeThrough = if type(spec) == "table" and tonumber(spec.SeeThrough) then tonumber(spec.SeeThrough) else 0.35
	self.cardSeeThrough = if spec then math.clamp(seeThrough, 0, 0.6) else 0
	local places = table.clone(self.tabs)
	for _, page in self.subPages do
		table.insert(places, page)
	end
	for _, place in places do
		for _, section in place.sections do
			section:applySeeThrough()
		end
	end
	local controller = Background.new(self.root, spec, {
		Intensity = 0.75,
		Radius = 12,
		Vignette = true,
		Scale = function()
			return self.scale
		end,
	})
	if not controller then
		return
	end
	self.movingBackground = controller
	-- Paused while the window is hidden.
	local connection = self.root:GetPropertyChangedSignal("Visible"):Connect(function()
		controller.SetVisible(self.root.Visible)
	end)
	local destroy = controller.Destroy
	function controller.Destroy()
		connection:Disconnect()
		destroy()
	end
	self.scope:add(controller.Destroy)
end

-- How much of the game shows through the window, 0 (solid) to 0.6.
function Window:SetTransparency(value)
	self.transparency = math.clamp(tonumber(value) or 0, 0, 0.6)
	self.root.BackgroundTransparency = self.transparency
	return self.transparency
end

-- The window grows, slides or unrolls into place as it appears, in the
-- window's Open look. A newer show or hide cancels an older one's ending.
-- `firstOpen` is set when the window has just been made: the hub builds its
-- tabs right after, and laying a big hub out can take one long frame. So the
-- window takes its starting pose once the build is done, and moves once that
-- frame has been drawn; a tween started earlier would be over before anyone
-- saw it.
function Window:pop(firstOpen)
	if not self.root.Visible then
		return
	end
	self.motionGeneration = (self.motionGeneration or 0) + 1
	local generation = self.motionGeneration
	local look = Styles.pick("Open", nil, self)
	if Motion.reduced then
		return
	end
	local timing = look.timing or "base"
	local function start()
		local rest = { position = self.root.Position, size = self.root.Size }
		if look.scale then
			self.uiScale.Scale = self.scale * look.scale
		end
		if look.offset then
			self.root.Position = rest.position + UDim2.fromOffset(look.offset.X, look.offset.Y)
		end
		local unroll = look.unroll and not self.minimized
		if unroll then
			self.root.Size = UDim2.fromOffset(rest.size.X.Offset, self.topbarHeight)
		end
		local function move()
			if look.scale then
				Motion.tween(self.uiScale, timing, { Scale = self.scale })
			end
			if look.offset then
				Motion.tween(self.root, timing, { Position = rest.position })
			end
			if unroll then
				Motion.tween(self.root, "slow", { Size = rest.size })
			end
		end
		local function settle()
			self.uiScale.Scale = self.scale
			self.root.Position, self.root.Size = rest.position, rest.size
		end
		return move, settle
	end
	if not firstOpen then
		local move = start()
		move()
		return
	end
	task.defer(function()
		if generation ~= self.motionGeneration or self.scope.cleaned or not self.root.Visible then
			return
		end
		local move, settle = start()
		RunService.RenderStepped:Wait()
		RunService.Heartbeat:Wait()
		if self.scope.cleaned then
			return
		end
		-- Hidden or shown again in the meantime: arrive without the motion.
		if generation ~= self.motionGeneration then
			settle()
		else
			move()
		end
	end)
end

-- The reverse of pop, then `done` once the window may be hidden.
function Window:unpop(done)
	self.motionGeneration = (self.motionGeneration or 0) + 1
	local generation = self.motionGeneration
	local look = Styles.pick("Open", nil, self)
	-- Leaving is animated only when the hub chose an Open look; the default
	-- hides at once, as it always has.
	if Motion.reduced or not self.styles.Open or not self.root.Visible or not (look.scale or look.offset or look.unroll) then
		done()
		return
	end
	if look.scale then
		Motion.tween(self.uiScale, "fast", { Scale = self.scale * look.scale })
	end
	local rest = self.root.Position
	if look.offset then
		Motion.tween(self.root, "fast", { Position = rest + UDim2.fromOffset(look.offset.X, look.offset.Y) })
	end
	if look.unroll then
		Motion.tween(self.root, "fast", { Size = UDim2.fromOffset(self.root.Size.X.Offset, self.topbarHeight) })
	end
	task.delay(0.13, function()
		if generation ~= self.motionGeneration or self.scope.cleaned then
			return
		end
		done()
		-- Back to rest, unseen, so the next show starts from the right place.
		self.uiScale.Scale = self.scale
		self:layout()
	end)
end

function Window:buildTopbar()
	local scope = self.scope
	local header = self.header
	local topbar = Create.new("Frame", { Name = "Topbar", Size = UDim2.new(1, 0, 0, self.topbarHeight), ZIndex = 3, Parent = self.root })
	self.topbar = topbar
	self.topbarSeam = Hairline.new("X", "stroke", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = topbar })

	local brand = Create.new("Frame", { Name = "Brand", Size = UDim2.fromScale(1, 1), Parent = topbar })
	self.brand = brand
	local inset = Create.padding(brand, 16, 0)
	Create.list(brand, "Horizontal", if header.image then 12 else 10)
	local heading
	if header.wordmark then
		Header.wordmark(self, brand)
		heading = brand
	else
		local picture = self.options.TopbarImage
		if picture == true then
			picture = self.Icon
		end
		if picture then
			self:buildTopbarImage(brand, picture)
		elseif self.Icon then
			Create.icon(self.Icon, header.icon or 20, "accent", brand)
		end
		local titles = Create.new("Frame", { Name = "Titles", Size = UDim2.fromScale(0, 1), LayoutOrder = 1, Parent = brand }, {
			Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		Create.list(titles, "Vertical", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
		heading = Create.new("Frame", { Name = "Heading", Size = UDim2.new(1, 0, 0, (header.title or 14) + 4), ClipsDescendants = true, Parent = titles })
		Create.list(heading, "Horizontal", 8)
		-- A long title gives way to the version tag and ends in an ellipsis
		-- rather than being cut off mid-letter.
		self.titleLabel = Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = self.Title,
			TextSize = header.title or 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Weight = "bold",
			Theme = { TextColor3 = "text" },
			Parent = heading,
		}, {
			Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink }),
		})
		self.subtitleLabel = Create.new("TextLabel", {
			Name = "Subtitle",
			Size = UDim2.new(1, 0, 0, (header.subtitle or 12) + 3),
			Text = self.Subtitle or "",
			TextSize = header.subtitle or 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
			Visible = self.Subtitle ~= nil,
			Theme = { TextColor3 = "textMuted" },
			Parent = titles,
		})
	end
	-- The version tag beside the title: shown when the hub gives a Version
	-- and has not set ShowVersion to false.
	self.versionTag = Create.new("TextLabel", {
		Name = "Version",
		Size = if header.wordmark then UDim2.fromOffset(0, 20) else UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tostring(self.options.Version or ""),
		TextSize = 12,
		Weight = "medium",
		LayoutOrder = 1,
		BackgroundTransparency = 0.85,
		Visible = self.options.Version ~= nil and self.options.ShowVersion ~= false,
		Theme = { BackgroundColor3 = "accent", TextColor3 = "accent" },
		Parent = heading,
	})
	Create.corner(5, self.versionTag)
	Create.padding(self.versionTag, 6, 0)
	-- Kept apart from the sidebar header's own labels, which come and go.
	self.topbarTitle, self.topbarSubtitle = self.titleLabel, self.subtitleLabel

	local actions = Create.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = topbar,
	})
	Create.list(actions, "Horizontal", 2, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
	-- The title gives up exactly the room the actions take, so neither overlaps.
	scope:connect(actions:GetPropertyChangedSignal("AbsoluteSize"), function()
		inset.PaddingRight = UDim.new(0, actions.AbsoluteSize.X / self.scale + 14)
	end)

	local search, box = Header.searchBox(self, scope, actions, UDim2.fromOffset(170, 30))
	self.searchFrame, self.searchBox = search, box
	self.topbarSearch, self.topbarBox = search, box
	search.Visible = self.options.Search ~= false
	scope:connect(box.Focused, function()
		self:fitTopbarSearch()
	end)
	scope:connect(box.FocusLost, function()
		self:fitTopbarSearch()
	end)

	self.chipHolder = Create.new("Frame", {
		Name = "Profile",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = actions,
	})
	Create.list(self.chipHolder, "Horizontal", 0)

	local function action(icon, order, callback)
		local button = Create.new("TextButton", { Name = icon, Text = "", Size = UDim2.new(0, if self.library.touch then 44 else 40, 1, 0), LayoutOrder = order, Parent = actions })
		local glyph = centred(Create.icon(icon, 16, "textMuted", button))
		scope:connect(button.MouseEnter, function()
			Theme.bind(glyph, "ImageColor3", "text")
		end)
		scope:connect(button.MouseLeave, function()
			Theme.bind(glyph, "ImageColor3", "textMuted")
		end)
		scope:connect(button.Activated, callback)
		return glyph
	end
	self.topbarActions, self.topbarAction = actions, action
	if self.options.SidebarToggle then
		-- Folds the sidebar to its icon rail and back.
		action("panel-left", 1.5, function()
			self:SetTabStyle(if self.tabStyle == "Sidebar" then "Rail" else "Sidebar")
		end)
	end
	if Styles.pick("Controls", nil, self).dots then
		self.dots = self:buildDots(brand)
	else
		-- Both are always made, so Window:Set can bring back one the hub hid.
		self.minimizeGlyph = action("minus", 2, function()
			self:Minimize(not self.minimized)
		end)
		self.minimizeButton = self.minimizeGlyph.Parent
		self.minimizeButton.Visible = self.options.Minimizable ~= false
		self.closeButton = action("x", 3, function()
			self:Hide()
		end).Parent
		self.closeButton.Visible = self.options.Close ~= false
	end

	Drag.move(scope, topbar, self.root, self:dragOptions())
end

-- How the top bar (or the sidebar's logo) drags the window: not while the
-- hub has locked it, and snapped and saved where it is let go.
function Window:dragOptions()
	return {
		enabled = function()
			return not self.dragLocked
		end,
		onMoved = function()
			local corner = self.root.AbsolutePosition - self.gui.AbsolutePosition
			self.placed = self:snap(Vector2.new(math.round(corner.X), math.round(corner.Y)))
			self:layout()
			self:savePreferences()
		end,
	}
end

-- Where minimising goes. With the sidebar header there is no top bar to
-- fold up to, so "Topbar" docks to the pill instead.
function Window:minimizeMode()
	if self.sidebarHeader and self.minimizeStyle == "Topbar" then
		return "Pill"
	end
	return self.minimizeStyle
end

-- The hub's own picture before its title, in one of the TopbarImage looks.
-- Any image source works: an icon name, an asset id, a URL or a file.
function Window:buildTopbarImage(brand, source)
	local look = Styles.pick("TopbarImage", self.options.TopbarImageStyle, self)
	local size = self.header.image or look.size or 28
	local holder = Create.new("Frame", { Name = "TopbarImage", Size = UDim2.fromOffset(size, size), Parent = brand })
	local image = Create.new("ImageLabel", {
		Name = "Image",
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Crop,
		Theme = { BackgroundColor3 = "raised" },
		Parent = holder,
	})
	Create.corner(look.corner or -1, image)
	-- An icon name is tinted like the old icon; a picture keeps its colours.
	if Assets.kind(source) == nil and type(source) == "string" then
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		Theme.bind(image, "ImageColor3", "accent")
	end
	Icons.apply(image, source)
	if look.ring then
		Create.new("UIStroke", { Thickness = 2, Theme = { Color = "accent" }, Parent = image })
	end
	if look.dot then
		local dot = Create.new("Frame", {
			Name = "Dot",
			Size = UDim2.fromOffset(9, 9),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -1, 1, -1),
			ZIndex = 2,
			Theme = { BackgroundColor3 = "success" },
			Parent = holder,
		})
		Create.corner(-1, dot)
		Create.new("UIStroke", { Thickness = 2, Theme = { Color = "background" }, Parent = dot })
	end
	self.topbarImage = image
	return image
end

-- Close, minimise and a size switch as three coloured dots on the left of
-- the top bar. Each shows its glyph while the pointer is over the group.
function Window:buildDots(brand)
	local scope = self.scope
	local size = if self.library.touch then 18 else 13
	local group = Create.new("Frame", { Name = "Dots", Size = UDim2.fromOffset(size * 3 + 16, size), LayoutOrder = -1, Parent = brand })
	Create.list(group, "Horizontal", 8)
	local glyphs = {}
	local function dot(role, icon, order, callback)
		local button = Create.new("TextButton", { Name = icon, Text = "", Size = UDim2.fromOffset(size, size), LayoutOrder = order, Theme = { BackgroundColor3 = role }, Parent = group })
		Create.corner(-1, button)
		local glyph = centred(Create.icon(icon, size - 5, "background", button))
		glyph.ImageTransparency = 1
		table.insert(glyphs, glyph)
		scope:connect(button.Activated, callback)
		return glyph
	end
	self.closeButton = dot("danger", "x", 1, function()
		self:Hide()
	end).Parent
	self.closeButton.Visible = self.options.Close ~= false
	self.minimizeGlyph = dot("warning", "minus", 2, function()
		self:Minimize(not self.minimized)
	end)
	self.minimizeButton = self.minimizeGlyph.Parent
	self.minimizeButton.Visible = self.options.Minimizable ~= false
	-- The third dot switches between the hub's size and a larger one.
	dot("success", "maximize-2", 3, function()
		local large = Vector2.new(1100, 700)
		if self.size.X >= large.X and self.size.Y >= large.Y and self.smallSize then
			self.size, self.smallSize = self.smallSize, nil
		else
			self.smallSize, self.size = self.size, large
		end
		self:layout()
		self:savePreferences()
	end)
	scope:connect(group.MouseEnter, function()
		for _, glyph in glyphs do
			Motion.tween(glyph, "fast", { ImageTransparency = 0.2 })
		end
	end)
	scope:connect(group.MouseLeave, function()
		for _, glyph in glyphs do
			Motion.tween(glyph, "fast", { ImageTransparency = 1 })
		end
	end)
	return group
end

-- With Snap on, a window dropped near a screen edge or the centre line
-- lines up with it.
function Window:snap(corner)
	if not self.options.Snap then
		return corner
	end
	local view = self.gui.AbsoluteSize
	local shown = self.root.AbsoluteSize
	local margin = 8
	local x, y = corner.X, corner.Y
	if math.abs(x - margin) < SNAP then
		x = margin
	elseif math.abs(x + shown.X - (view.X - margin)) < SNAP then
		x = view.X - margin - shown.X
	elseif math.abs(x + shown.X / 2 - view.X / 2) < SNAP then
		x = view.X / 2 - shown.X / 2
	end
	if math.abs(y - margin) < SNAP then
		y = margin
	elseif math.abs(y + shown.Y - (view.Y - margin)) < SNAP then
		y = view.Y - margin - shown.Y
	end
	return Vector2.new(math.round(x), math.round(y))
end

-- Adds a button to the top bar, left of the window's own. Options: Icon,
-- Callback. Returns { Destroy }.
function Window:AddTopbarButton(options)
	options = options or {}
	self.extraButtons = (self.extraButtons or 0) + 1
	local glyph = self.topbarAction(options.Icon or "circle", 1 + self.extraButtons / 100, function()
		Env.call("Top bar button", options.Callback)
	end)
	local button = glyph.Parent
	return {
		Destroy = function()
			button:Destroy()
		end,
	}
end

-- Greys every control in the window at once, and turns them back on; rows
-- the hub disabled itself stay disabled.
function Window:SetEnabled(enabled)
	self.disabledAll = enabled == false
	local places = table.clone(self.tabs)
	for _, page in self.subPages do
		table.insert(places, page)
	end
	for _, tab in places do
		for _, entry in tab.entries do
			if entry.handle.SetBlocked then
				entry.handle:SetBlocked(Registry.blocked(self, entry.section))
			end
		end
	end
end

-- A corner grip for mouse users. A press pins the window's top-left corner
-- where it is on screen, so the bottom-right corner moves one for one with
-- the pointer, and the size stops at the screen edge instead of running
-- ahead of what is shown.
function Window:buildGrip()
	local grip = Create.new("TextButton", {
		Name = "Resize",
		Text = "",
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		ZIndex = 10,
		Parent = self.root,
	})
	self.grip = grip
	for _, offset in { Vector2.new(12, 12), Vector2.new(7, 12), Vector2.new(12, 7) } do
		Create.new("Frame", {
			Size = UDim2.fromOffset(2, 2),
			Position = UDim2.fromOffset(offset.X, offset.Y),
			Theme = { BackgroundColor3 = "textMuted" },
			Parent = grip,
		})
	end
	Resize.grip(self.scope, grip, function()
		if self.minimized then
			return nil
		end
		local root, scale = self.root, self.scale
		local shown = Vector2.new(root.Size.X.Offset, root.Size.Y.Offset)
		local corner = Vector2.new(root.Position.X.Offset, root.Position.Y.Offset) - shown * scale / 2
		self.placed = Vector2.new(math.round(corner.X), math.round(corner.Y))
		local room = self.gui.AbsoluteSize - self.placed - Vector2.new(8, 8)
		return { size = shown, scale = scale, min = MIN_SIZE, max = room / scale }
	end, function(size)
		self.size = size
		self:layout()
	end, function()
		self:savePreferences()
	end)
end

-- Fits the window to the screen and picks the navigation and column layout
-- for the width it ended up with. Runs on every viewport or setting change.
function Window:layout()
	local view, scale = self.gui.AbsoluteSize, self.scale
	local width = math.floor(math.max(math.min(self.size.X, (view.X - 16) / scale), 240))
	local height = math.floor(math.max(math.min(self.size.Y, (view.Y - 16) / scale), 200))
	local folded = self.minimized and self:minimizeMode() == "Topbar"
	self.root.Size = UDim2.fromOffset(width, if folded then self.topbarHeight else height)
	self.body.Visible = not folded
	-- Folded to its top bar, the window's bottom edge is the seam's line; the
	-- seam would show past the rounded corners.
	self.topbarSeam.Visible = not folded and not self.sidebarHeader
	if self.grip then
		self.grip.Visible = not folded and self.options.Resizable ~= false
	end

	local narrow = width < NARROW
	local style = self.tabStyle
	if narrow and self:lane(style) then
		style = "Top"
	end
	if style ~= self.activeStyle then
		self.activeStyle = style
		self:buildNav()
	end
	self.narrowTopbar = narrow
	self:fitTopbarSearch()
	-- The dock fills the bottom strip, so the grip sits above it instead of
	-- over the last tab's label.
	if self.grip then
		self.grip.Position = UDim2.new(1, -2, 1, -2 - (if style == "Dock" then STRIPS.Dock else 0))
	end

	self.wide = width - (self:lane(style) or 0) >= COLUMNS
	for _, tab in self.tabs do
		tab:reflow(self.wide)
	end
	for _, page in self.subPages do
		page:reflow(self.wide)
	end

	-- The top-left corner sits on a whole pixel, wherever the window goes:
	-- centred at first, then where the player dragged it, kept on screen.
	local shown = Vector2.new(width * scale, height * scale)
	local corner = self.placed or (view - shown) / 2
	corner = Vector2.new(
		math.round(math.clamp(corner.X, 0, math.max(view.X - shown.X, 0))),
		math.round(math.clamp(corner.Y, 0, math.max(view.Y - shown.Y, 0)))
	)
	self.root.Position = UDim2.fromOffset(corner.X + shown.X / 2, corner.Y + shown.Y / 2)
end

-- On a narrow window the top-bar search folds to its magnifier, so the
-- title keeps its room. It opens while it has focus or holds a query.
function Window:fitTopbarSearch()
	local search, box = self.topbarSearch, self.topbarBox
	local folded = self.narrowTopbar and not box:IsFocused() and box.Text == ""
	search.Size = UDim2.fromOffset(if folded then 34 elseif self.narrowTopbar then 150 else 170, 30)
	-- Folded, the box covers the whole button so a press anywhere on it focuses it.
	box.Position = UDim2.fromOffset(if folded then 0 else 32, 0)
	box.Size = if folded then UDim2.fromScale(1, 1) else UDim2.new(1, -38, 1, 0)
	box.PlaceholderText = if folded then "" else Strings.get("Search")
end

-- The width of a side navigation style, or nil for the strips. The hub's
-- SidebarWidth sets the sidebar's.
function Window:lane(style)
	if style == "Sidebar" and tonumber(self.options.SidebarWidth) then
		return math.clamp(math.floor(self.options.SidebarWidth), 150, 280)
	end
	return LANES[style]
end

-- Rebuilds the tab buttons for the active style. The pages, the selected tab
-- and every element value stay as they are; only the navigation is redrawn.
function Window:buildNav()
	if self.navScope then
		self.scope:release(self.navScope)
	end
	Popup.close(self.library)
	local scope = self.scope:child()
	self.navScope = scope
	local style = self.activeStyle
	local lane, strip = self:lane(style), STRIPS[style]
	-- The sidebar header needs the full sidebar to carry the logo.
	local sidebarHeader = self.header.sidebar == true and style == "Sidebar"
	Header.apply(self, sidebarHeader)
	local top = if sidebarHeader then Header.STRIP else 0

	local host = Create.new("Frame", { Name = "Navigation", Parent = self.body })
	scope:add(host)
	self.navHost = host
	local seam = Hairline.new(if lane then "Y" else "X", "stroke", { ZIndex = 2, Parent = host })
	local list

	if lane then
		host.Size = UDim2.new(0, lane, 1, 0)
		seam.AnchorPoint = Vector2.new(1, 0)
		seam.Position = UDim2.fromScale(1, 0)
		self.pages.Position = UDim2.fromOffset(lane, top)
		self.pages.Size = UDim2.new(1, -lane, 1, -top)

		local column = Create.new("Frame", { Name = "Column", Size = UDim2.new(1, -1, 1, 0), Parent = host })
		Create.list(column, "Vertical", 0)
		if sidebarHeader then
			Header.sidebarTop(self, scope, column)
		end
		list = Create.new("ScrollingFrame", { Name = "Tabs", Size = UDim2.fromScale(1, 0), ScrollBarThickness = 0, Parent = column }, {
			Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		Create.padding(list, 8)
		Create.list(list, "Vertical", 2)
		if self.profile.Enabled then
			Hairline.new("X", "stroke", { LayoutOrder = 1, Parent = column })
			local footer = Create.new("Frame", {
				Name = "Footer",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = column,
			})
			Create.list(footer, "Vertical", 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
			if style == "Sidebar" then
				Profile.card(self, scope, footer)
			else
				Profile.chip(self, scope, footer)
			end
		end
	else
		host.Size = UDim2.new(1, 0, 0, strip)
		list = Create.new("ScrollingFrame", {
			Name = "Tabs",
			Size = UDim2.new(1, 0, 1, -1),
			ScrollBarThickness = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			Parent = host,
		})
		if style == "Top" then
			seam.AnchorPoint = Vector2.new(0, 1)
			seam.Position = UDim2.fromScale(0, 1)
			self.pages.Position = UDim2.fromOffset(0, strip)
			Create.padding(list, 8, 0)
			Create.list(list, "Horizontal", 4)
		else
			host.AnchorPoint = Vector2.new(0, 1)
			host.Position = UDim2.fromScale(0, 1)
			list.Position = UDim2.fromOffset(0, 1)
			self.pages.Position = UDim2.fromOffset(0, 0)
			Create.padding(list, 6, 4)
			Create.list(list, "Horizontal", 2, { HorizontalFlex = Enum.UIFlexAlignment.Fill })
		end
		self.pages.Size = UDim2.new(1, 0, 1, -strip)
	end

	local order, group = 0, nil
	for _, tab in self:navOrder() do
		if tab.Hidden then
			tab.button = nil
			continue
		end
		local heading = self:navGroup(tab)
		if style == "Sidebar" and heading and heading ~= group and heading ~= PINNED then
			order += 1
			self:buildGroupHeading(list, scope, heading, order)
		end
		group = heading
		order += 1
		tab:buildButton(style, list, scope, order)
		if style == "Sidebar" and heading and self.collapsedGroups[heading] then
			tab.button.Visible = false
		end
		if self.tabOrder then
			TabOrder.attach(self, tab, scope, self:lane(style) ~= nil)
		end
	end

	self.chipHolder:ClearAllChildren()
	Create.list(self.chipHolder, "Horizontal", 0)
	if self.profile.Enabled and not lane then
		Profile.chip(self, scope, self.chipHolder)
	end
	self:paintTabs()
end

-- The heading above a group of tabs in the sidebar. Unless the hub turned
-- `CollapsibleGroups` off, pressing it folds the group away; the choice is
-- saved with the other interface preferences.
function Window:buildGroupHeading(parent, scope, name, order)
	local collapsible = self.options.CollapsibleGroups ~= false
	local heading = Create.new(if collapsible then "TextButton" else "Frame", {
		Name = "Group",
		Size = UDim2.new(1, 0, 0, if collapsible and self.library.touch then 40 else 28),
		LayoutOrder = order,
		Parent = parent,
	})
	local label = Create.new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Text = name,
		TextSize = 12,
		Weight = "medium",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "textMuted" },
		Parent = heading,
	})
	if not collapsible then
		return
	end

	local arrow = Create.icon("chevron-down", 14, "textMuted", heading)
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = UDim2.new(1, -10, 0.5, 0)
	arrow.Rotation = if self.collapsedGroups[name] then -90 else 0
	scope:connect(heading.MouseEnter, function()
		Theme.bind(label, "TextColor3", "text")
		Theme.bind(arrow, "ImageColor3", "text")
	end)
	scope:connect(heading.MouseLeave, function()
		Theme.bind(label, "TextColor3", "textMuted")
		Theme.bind(arrow, "ImageColor3", "textMuted")
	end)
	scope:connect(heading.Activated, function()
		self:SetGroupCollapsed(name, not self.collapsedGroups[name])
	end)
end

function Window:SetGroupCollapsed(name, collapsed)
	self.collapsedGroups[name] = if collapsed then true else nil
	self:buildNav()
	self:savePreferences()
end

-- The tabs in the order the navigation lists them: as they were made, but
-- kept together under their sidebar heading, and the update log last in its
-- group. A hub that builds its tabs a frame apart gets its update log made
-- at the first pause, early, and it still belongs at the end.
-- The sidebar heading a tab sits under: its Group, or the pinned tabs'
-- own place at the top, which shows no heading.
function Window:navGroup(tab)
	if TabOrder.isPinned(self, tab) then
		return PINNED
	end
	return tab.Group
end

function Window:navOrder()
	local rank, made = {}, {}
	for index, tab in self.tabs do
		-- A place the player dragged the tab to wins over the order it was made in.
		local placed = TabOrder.position(self, tab)
		made[tab] = if placed then placed else 1000 + index
		local key = self:navGroup(tab) or ""
		if rank[key] == nil and not tab.trailing then
			rank[key] = if TabOrder.isPinned(self, tab) then -1 else index
		end
	end
	local ordered = table.clone(self.tabs)
	table.sort(ordered, function(a, b)
		local first, second = rank[self:navGroup(a) or ""] or math.huge, rank[self:navGroup(b) or ""] or math.huge
		if first ~= second then
			return first < second
		end
		if (a.trailing == true) ~= (b.trailing == true) then
			return b.trailing == true
		end
		return made[a] < made[b]
	end)
	return ordered
end

function Window:paintTabs()
	local open = self.selected
	local root = open and (open.rootTab or open)
	local found = {}
	for _, page in self.subPages do
		found[page.rootTab] = (found[page.rootTab] or 0) + page.matches
	end
	for _, tab in self.tabs do
		tab:paint(tab == root, self.query ~= "" and tab.matches + (found[tab] or 0) == 0)
	end
end

function Window:Tab(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	if type(options) ~= "table" or type(options.Title) ~= "string" then
		error("Tab needs a Title", 2)
	end
	Schema.check(`Tab "{options.Title}"`, options, Schema.tab)
	local tab = Tab.new(self, options)
	table.insert(self.tabs, tab)
	tab:reflow(self.wide)
	self:buildNav()
	-- The Favourites tab leads the list, but a hub opens on its own first tab.
	if not tab.Hidden and not self.makingFavourites and (not self.selected or self.selected.Hidden) then
		self:SelectTab(tab)
	end
	-- ShowWhen given when the tab is made; Visible was read by Tab.new.
	if options.ShowWhen ~= nil then
		local source, expected = Registry.condition(options.ShowWhen)
		Registry.follow(tab, source, expected, true)
	end
	return tab
end

-- A tab was shown or hidden: redraw the navigation, and leave a hidden tab
-- for the first one still shown.
function Window:tabShownChanged(tab)
	self:buildNav()
	if tab.Hidden and self.selected == tab then
		for _, other in self.tabs do
			if not other.Hidden then
				self:SelectTab(other)
				break
			end
		end
	elseif not tab.Hidden and (not self.selected or self.selected.Hidden) then
		self:SelectTab(tab)
	end
	self:applySearch()
end

function Window:SelectTab(tab)
	if self.selected == tab or tab.Hidden then
		return
	end
	Popup.close(self.library)
	if self.selected then
		self.selected.page.Visible = false
	end
	self.selected = tab
	tab.page.Visible = true
	local arrive = Styles.pick("PageTransition", nil, self)
	if arrive.offset and not Motion.reduced then
		tab.page.Position = UDim2.fromOffset(arrive.offset.X, arrive.offset.Y)
		Motion.tween(tab.page, "base", { Position = UDim2.fromOffset(0, 0) })
	else
		tab.page.Position = UDim2.fromOffset(0, 0)
	end
	self:paintTabs()
	self.TabChanged:Fire(tab)
end

-- Filters every tab by the query. If the open tab has no match and another
-- does, that one is opened, so a search never ends on an empty page.
function Window:applySearch(query)
	if query ~= nil then
		self.query = string.lower(string.match(query, "^%s*(.-)%s*$"))
	end
	local first
	for _, tab in self.tabs do
		if tab:filter(self.query) > 0 and not first and not tab.Hidden then
			first = tab
		end
	end
	for _, page in self.subPages do
		if page:filter(self.query) > 0 and not first and not page.rootTab.Hidden then
			first = page
		end
	end
	if self.query ~= "" and first and self.selected and self.selected.matches == 0 then
		self:SelectTab(first)
	end
	self.empty.Visible = self.query ~= "" and first == nil
	self:updateMatchCounter()
	self.empty.Text = Strings.get('Nothing matches "{query}".', { query = self.query })
	if self.selected then
		self.selected.page.Visible = not self.empty.Visible
	end
	self:paintTabs()
end

function Window:Search(query)
	self.searchBox.Text = query or ""
end

-- Every row the search matches, tab by tab in navigation order, pages after
-- the tab they belong to.
function Window:searchMatches()
	local matches = {}
	local function collect(tab)
		for _, entry in tab.entries do
			if entry.handle.searchMatched then
				table.insert(matches, { tab = tab, handle = entry.handle })
			end
		end
	end
	for _, tab in self:navOrder() do
		if not tab.Hidden then
			collect(tab)
			for _, page in self.subPages do
				if page.rootTab == tab then
					collect(page)
				end
			end
		end
	end
	return matches
end

-- Moves to the next (step 1) or previous (step -1) matching row: opens its
-- tab or page, scrolls it into view and lights it up.
function Window:JumpToMatch(step)
	local matches = self:searchMatches()
	if #matches == 0 then
		return nil
	end
	local index = self.matchIndex
	index = if index then (index - 1 + (step or 1)) % #matches + 1 else (if (step or 1) < 0 then #matches else 1)
	self.matchIndex = index
	local found = matches[index]
	self:SelectTab(found.tab)
	SearchFocus.reveal(self, found.tab, found.handle)
	self:updateMatchCounter(#matches)
	return found.handle
end

function Window:updateMatchCounter(total)
	local counter = self.searchCounter
	if not counter then
		return
	end
	total = total or #self:searchMatches()
	counter.Visible = self.query ~= "" and total > 0
	counter.Text = if self.matchIndex then Strings.get("{index} of {total}", { index = self.matchIndex, total = total }) else tostring(total)
end

-- Flags ---------------------------------------------------------------------

function Window:checkFlag(flag)
	if flag == nil then
		return nil
	elseif type(flag) ~= "string" or flag == "" then
		return "A Flag must be a non-empty string"
	end
	local owner = self.Flags[flag]
	return if owner then `Flag "{flag}" is already used by "{owner.Title or flag}"` else nil
end

function Window:claimFlag(flag, handle, scope)
	if flag == nil then
		return
	end
	handle.Flag = flag
	self.Flags[flag] = handle
	self.config.flags[flag] = handle
	local owner = scope or handle.scope
	owner:add(function()
		if self.Flags[flag] == handle then
			self.Flags[flag] = nil
			self.config.flags[flag] = nil
		end
	end)
end

-- Tiers ---------------------------------------------------------------------

function Window:HasTier(name)
	local access = self.access
	if name == nil then
		return true
	end
	local rank = table.find(access.Tiers, name)
	if not rank then
		if not access.Keyless then
			warn(`[Halcyon] Tier "{name}" is not one of this window's tiers, so what it gates stays locked.`)
		end
		return false
	end
	return access.Rank >= rank
end

-- True when the player holds a paid tier or one ranked above it.
function Window:IsPaid()
	local access = self.access
	return access.PaidRank ~= nil and access.Rank >= access.PaidRank
end

-- `requirement` is a tier name, or true for "any paid tier".
function Window:allows(requirement)
	if requirement == true then
		return self:IsPaid()
	end
	return self:HasTier(requirement)
end

function Window:applyGate(handle, requirement)
	-- A row whose executor functions are missing stays locked whatever the tier.
	if handle.MissingText then
		handle:Lock(handle.MissingText, "wrench")
		return
	end
	if self:allows(requirement) then
		handle:Unlock()
		return
	end
	local wording = self:lockWording(requirement, handle.LockText, handle.LockHint)
	handle:Lock(wording, if requirement == true then "crown" else "lock", handle.QuietLock)
end

-- The wording and the hint for a lock: the row's or section's own text if
-- it has any, otherwise the window's.
function Window:lockWording(requirement, ownText, ownHint)
	local paid = requirement == true
	local wording = ownText
	if not wording and paid then
		wording = self.paidLockText
	elseif not wording then
		wording = string.gsub(self.lockText, "{tier}", function()
			return requirement
		end)
	end
	return wording, ownHint or (if paid then self.paidLockHint else self.lockHint)
end

function Window:gate(handle, requirement)
	self.gated[handle] = requirement
	handle.scope:add(function()
		self.gated[handle] = nil
	end)
	if not self:allows(requirement) then
		self:applyGate(handle, requirement)
	end
end

function Window:applyGates()
	for handle, requirement in self.gated do
		self:applyGate(handle, requirement)
	end
	for _, section in self.lockedSections do
		section:refreshLock()
	end
end

function Window:GetTier()
	return self.access.Tier
end

-- Seconds until the player's key expires, or nil when it does not.
function Window:GetKeyExpiry()
	local expires = self.access.ExpiresAt
	return if expires then math.max(expires - os.time(), 0) else nil
end

-- Moves the player to another tier and unlocks or locks what it gates.
function Window:SetTier(name)
	local access = self.access
	local rank = table.find(access.Tiers, name)
	if not rank then
		return false
	end
	access.Tier, access.Rank = name, rank
	self:applyGates()
	self:buildNav()
	return true
end

-- Changes the wording on locked rows: `text` for tier locks ("{tier}" is
-- replaced by the tier's name) and `paidText` for paid-only locks.
function Window:SetLockText(text, paidText)
	self.lockText = text or self.lockText
	self.paidLockText = paidText or self.paidLockText
	self:applyGates()
end

-- Changes the second line on locked sections: `hint` for tier locks and
-- `paidHint` for paid-only locks. An empty string removes the line.
function Window:SetLockHint(hint, paidHint)
	if hint ~= nil then
		self.lockHint = hint
	end
	if paidHint ~= nil then
		self.paidLockHint = paidHint
	end
	self:applyGates()
end

-- Visibility ----------------------------------------------------------------

-- Shows whichever piece stands for the window right now: the window
-- itself, the pill or chip it was minimised to, or the open button a hidden
-- window leaves behind.
function Window:refreshVisibility()
	for _, hook in self.visibilityHooks or {} do
		task.defer(hook)
	end
	local mode = self:minimizeMode()
	local docked = self.minimized and mode ~= "Topbar"
	self.root.Visible = self.Visible and not docked
	self.pill.Visible = self.Visible and docked and mode == "Pill"
	-- A phone has no menu key, so a hidden window always leaves a button to bring it back.
	self.openButton.Visible = (self.Visible and docked and mode == "Chip")
		or (not self.Visible and (self.library.touch or self.options.OpenButton == true))
end

-- What a press on the pill or the open button does.
function Window:restore()
	if self.Visible then
		self:Minimize(false)
	else
		self:Show()
	end
end

function Window:Show()
	local hidden = not self.root.Visible
	self.Visible = true
	self:refreshVisibility()
	if hidden then
		self:pop()
	end
end

function Window:Hide()
	Popup.close(self.library)
	self.Visible = false
	self:unpop(function()
		if not self.Visible then
			self:refreshVisibility()
		end
	end)
	if not self.openButton.Visible and not self.hinted and self.toggleKey then
		self.hinted = true
		self:Notify({ Title = Strings.get("Menu hidden"), Content = Strings.get("Press {key} to open it again.", { key = self.toggleKey.Name }) })
	end
end

function Window:Toggle()
	if self.Visible then
		self:Hide()
	else
		self:Show()
	end
end

-- The menu key. When the hub minimises to a pill or the round chip, the key
-- folds the window to that and back instead of hiding it, so the player
-- always has something on screen to press.
function Window:menuKey()
	local folds = self:minimizeMode() ~= "Topbar" and self.options.Minimizable ~= false
	if not folds or not self.Visible then
		self:Toggle()
	else
		self:Minimize(not self.minimized)
	end
end

function Window:Minimize(minimized)
	self.minimized = minimized == true
	if self.minimizeGlyph then
		Icons.apply(self.minimizeGlyph, if self.minimized then "maximize-2" else "minus")
	end
	Popup.close(self.library)
	self:layout()
	self:refreshVisibility()
	Switches.applyBlur(self)
end

-- "Topbar" folds the window to its top bar, "Pill" swaps it for a small
-- titled pill and "Chip" for the round open button.
function Window:SetMinimizeStyle(name)
	if not MINIMIZE[name] then
		return false
	end
	self.minimizeStyle = name
	self:layout()
	self:refreshVisibility()
	self:savePreferences()
	return true
end

-- Settings ------------------------------------------------------------------

function Window:SetTabStyle(name)
	if not (LANES[name] or STRIPS[name]) then
		return false
	end
	self.tabStyle = name
	self:layout()
	self:savePreferences()
	return true
end

function Window:SetScale(scale)
	self.scale = math.clamp(tonumber(scale) or 1, 0.75, 1.25)
	self.library.scale = self.scale
	self.uiScale.Scale = self.scale
	Hairline.setScale(self.scale)
	Popup.close(self.library)
	self:layout()
	self:savePreferences()
end

function Window:SetToggleKey(key)
	self.toggleKey = if typeof(key) == "EnumItem" then key else nil
	self:savePreferences()
end

function Window:SetAnonymous(anonymous)
	self.profile.Anonymous = anonymous == true
	self:buildNav()
	self:savePreferences()
end

-- Changes profile settings (Avatar, ShowClock, Name and the rest) after creation.
function Window:SetProfile(settings)
	for key, value in settings do
		self.profile[key] = value
	end
	self:buildNav()
end

-- Turns slider tooltips on or off for the whole window and, optionally,
-- picks their shape: "Rounded", "Sharp", "Pill" or "Plain".
function Window:SetSliderTooltips(enabled, style)
	self.sliderTooltips = enabled == true
	if style then
		self.sliderTooltipStyle = style
		self.styles.SliderTooltip = style
	end
end

-- Turns the toggle hover outline on or off for the whole window. `color` is
-- optional: a Color3 sets it, false goes back to the theme's accent.
function Window:SetToggleOutline(enabled, color)
	self.toggleOutline = enabled == true
	if color ~= nil then
		self.toggleOutlineColor = if typeof(color) == "Color3" then color else nil
	end
end

function Window:SetReducedMotion(reduced)
	Motion.reduced = reduced == true
	self:savePreferences()
end

function Window:SetTitle(title)
	self.Title = title
	-- The top bar's title and, with the sidebar header, the sidebar's logo text.
	for _, label in { self.topbarTitle, self.titleLabel, self.pillLabel } do
		label.Text = title
	end
end

-- Sets the text of the version tag; nil or "" hides it.
function Window:SetVersion(version)
	local text = if version == nil then "" else tostring(version)
	self.options.Version = if text == "" then nil else text
	self.versionTag.Text = text
	self.versionTag.Visible = text ~= "" and self.options.ShowVersion ~= false
end

-- Shows or hides the version tag without changing its text.
function Window:SetVersionVisible(visible)
	self.options.ShowVersion = visible == true
	self.versionTag.Visible = visible == true and self.options.Version ~= nil
end

function Window:SetSubtitle(subtitle)
	self.Subtitle = subtitle
	local shown = subtitle ~= nil and subtitle ~= ""
	for _, label in { self.topbarSubtitle, self.subtitleLabel } do
		label.Text = subtitle or ""
		-- The Wordmark header shows the logo in place of the titles.
		label.Visible = shown and not (label == self.topbarSubtitle and self.header.wordmark)
	end
end

function Window:writePreferences()
	self.preferencesQueued = false
	local collapsed = {}
	for name in self.collapsedGroups do
		table.insert(collapsed, name)
	end
	table.sort(collapsed)
	local seen = {}
	for id in self.seenSpotlights do
		table.insert(seen, id)
	end
	table.sort(seen)
	local themes = {}
	for _, plain in self.customThemes do
		table.insert(themes, plain)
	end
	local encoded, text = Env.encode({
		seen = seen,
		changelog = self.changelogSeen,
		updateSeen = self.updateSeen,
		personal = self.personal,
		themes = themes,
		version = PREFERENCES_VERSION,
		collapsedGroups = collapsed,
		minimizeStyle = self.minimizeStyle,
		size = { x = self.size.X, y = self.size.Y },
		position = if self.placed then { x = self.placed.X, y = self.placed.Y } else nil,
		theme = Theme.current.Name,
		tabStyle = self.tabStyle,
		scale = self.scale,
		reducedMotion = Motion.reduced,
		anonymous = self.profile.Anonymous,
		toggleKey = if self.toggleKey then self.toggleKey.Name else "",
		language = self.languagePicked,
		favourites = Favourites.saved(self),
		tabOrder = TabOrder.saved(self),
		popOuts = if next(self.popOutState) then self.popOutState else nil,
	})
	local wrote, message = false, Strings.get("The settings could not be encoded.")
	if encoded then
		wrote, message = Env.write(self.preferencesPath, text)
	end
	if not wrote and not self.preferencesWarned then
		self.preferencesWarned = true
		self:Notify({ Title = Strings.get("Settings not saved"), Content = message, Kind = "warning" })
	end
end

-- Interface choices are saved on their own, a moment after the last change.
-- Without file functions nothing is written; the Settings tab says so.
function Window:savePreferences()
	if self.options.SavePreferences == false or not Env.canSave or self.preferencesQueued then
		return
	end
	self.preferencesQueued = true
	task.delay(0.5, function()
		if not self.scope.cleaned and self.preferencesQueued then
			self:writePreferences()
		end
	end)
end

-- Runs `callback` once a second while `scope` lives. One loop serves every
-- clock in the window, and it starts only when something asks for it.
function Window:everySecond(scope, callback)
	scope:add(self.Tick:Connect(callback))
	if not self.ticker then
		self.ticker = self.scope:add(task.spawn(function()
			while true do
				task.wait(1)
				self.Tick:Fire()
			end
		end))
	end
end

-- Feedback ------------------------------------------------------------------

function Window:Notify(options)
	return Notifications.push(self.library, options)
end

-- Dismisses every notice on screen or waiting.
function Window:ClearNotifications()
	Notifications.clear(self.library)
end

function Window:Dialog(options)
	return Dialog.open(self.library, options)
end

-- Configs -------------------------------------------------------------------

-- Runs a config call and announces it on ConfigChanged when it worked.
local function announce(window, action, name, ok, message)
	if ok then
		window.ConfigChanged:Fire(action, Env.safeName(name))
	end
	return ok, message
end

function Window:SaveConfig(name)
	return announce(self, "save", name, self.config:save(name))
end

function Window:LoadConfig(name)
	self:keepForUndo()
	return announce(self, "load", name, self.config:load(name))
end

-- Switches the language for everything built from now on and remembers the
-- player's pick. Parts already on screen keep their text until the hub runs
-- again. Returns the code used.
function Window:SetLanguage(code)
	local chosen = Strings.setLanguage(code)
	self.languagePicked = chosen
	-- Written now rather than batched: the pick only matters on the next
	-- run, and the player may unload straight after making it.
	if self.options.SavePreferences ~= false and Env.canSave then
		self:writePreferences()
	end
	return chosen
end

-- Values ----------------------------------------------------------------------

-- Every flagged element's value, by flag.
function Window:GetValues()
	local values = {}
	for flag, handle in self.Flags do
		if handle.Get then
			values[flag] = handle:Get()
		end
	end
	return values
end

-- Sets flags from a table of flag = value; flags the hub doesn't have are
-- skipped. With `silent`, callbacks don't run. Returns how many were set.
function Window:SetValues(values, silent)
	self:keepForUndo()
	local count = 0
	for flag, value in values do
		local handle = self.Flags[flag]
		if handle and handle.Set then
			if silent and handle.SetSilent then
				handle:SetSilent(value)
			else
				handle:Set(value)
			end
			count += 1
		end
	end
	return count
end

-- Puts every flagged element back to the value it was made with.
function Window:ResetValues()
	self:keepForUndo()
	for _, handle in self.Flags do
		if handle.Reset then
			handle:Reset()
		end
	end
end

-- Remembers the current values so the next Undo can bring them back. Only
-- the latest change is kept.
function Window:keepForUndo()
	self.undoValues = self.config:collect()
end

-- Restores the values from before the last LoadConfig, ImportConfig,
-- SetValues or ResetValues. Returns false when there is nothing to undo.
function Window:Undo()
	local values = self.undoValues
	if not values then
		return false, Strings.get("Nothing to undo.")
	end
	self.undoValues = nil
	local count = self.config:apply(values)
	return true, Strings.get("Restored {count} settings.", { count = count })
end

-- Share codes -------------------------------------------------------------------

local SHARE_PREFIX = "Halcyon1:"

-- The flagged values as one line of text players can paste to each other.
-- Needs no file functions.
function Window:ExportConfig()
	local ok, text = Env.encode({ folder = self.folder, flags = self.config:collect() })
	return if ok then SHARE_PREFIX .. text else nil
end

-- Applies a code from ExportConfig. Returns ok, message.
function Window:ImportConfig(code)
	if type(code) ~= "string" then
		return false, Strings.get("Paste a share code first.")
	end
	code = string.match(code, "^%s*(.-)%s*$")
	if string.sub(code, 1, #SHARE_PREFIX) ~= SHARE_PREFIX then
		return false, Strings.get("That isn't a Halcyon share code.")
	end
	local ok, decoded = Env.decode(string.sub(code, #SHARE_PREFIX + 1))
	if not ok or type(decoded) ~= "table" or type(decoded.flags) ~= "table" then
		return false, Strings.get("The share code is incomplete. Copy it again.")
	end
	self:keepForUndo()
	local count = self.config:apply(decoded.flags)
	self.ConfigChanged:Fire("import", nil)
	return true, Strings.get("Imported {count} settings.", { count = count })
end

-- Callback errors ------------------------------------------------------------------

local ERROR_HISTORY = 50

function Window:recordError(title, message, trace)
	local entry = { Title = title, Message = message, Trace = trace, Time = os.time() }
	table.insert(self.Errors, entry)
	if #self.Errors > ERROR_HISTORY then
		table.remove(self.Errors, 1)
	end
	self.ErrorsChanged:Fire(entry)
end

-- Asks the UpdateCheck address now. Returns ok, latest (nil when this is
-- the newest), notes.
function Window:CheckForUpdate()
	return Services.check(self)
end

-- A panel listing what this executor offers and what is locked for it.
function Window:SupportPanel()
	return Services.supportPanel(self)
end

-- A panel listing the callbacks that failed this session.
function Window:ErrorsPanel()
	return Services.errorsPanel(self)
end

function Window:ClearErrors()
	table.clear(self.Errors)
	self.ErrorsChanged:Fire(nil)
end

function Window:DeleteConfig(name)
	return announce(self, "delete", name, self.config:delete(name))
end

function Window:ConfigExists(name)
	return self.config:exists(name)
end

-- The executor functions in `names` this executor lacks; empty when it has them all.
function Window:Require(names)
	return Env.missing(names)
end

function Window:ListConfigs()
	return self.config:list()
end

function Window:SetAutoload(name)
	return announce(self, "autoload", name, self.config:setAutoload(name))
end

function Window:GetAutoload()
	return self.config:getAutoload()
end

-- Call this after every element exists: a flag the hub has not created yet
-- is skipped.
function Window:LoadAutoload()
	local name = self.config:getAutoload()
	if not name then
		return false, Strings.get("No autoload config is set.")
	end
	return self.config:load(name)
end

-- What the Unload button does. With ConfirmUnload on (the default) the
-- player is asked first; a hub calling Unload() itself is never asked.
function Window:RequestUnload()
	if self.options.ConfirmUnload == false then
		self:Unload()
		return
	end
	self:Dialog({
		Title = Strings.get("Unload the hub?"),
		Content = Strings.get("Everything it turned on stops. Run the script again to bring it back."),
		Icon = "power",
		Dismissible = true,
		Buttons = {
			{ Title = Strings.get("Keep") },
			{
				Title = Strings.get("Unload"),
				Variant = "Danger",
				Callback = function()
					self:Unload()
				end,
			},
		},
	})
end

function Window:Unload()
	if self.unloaded then
		return
	end
	self.unloaded = true
	if self.preferencesQueued then
		self:writePreferences()
	end
	self.OnUnload:Fire()
	Popup.close(self.library)
	self.library.scope:release(self.scope)
	local index = table.find(self.library.windows, self)
	if index then
		table.remove(self.library.windows, index)
	end
	if self.onUnloaded then
		self.onUnloaded()
	end
end

return Window
