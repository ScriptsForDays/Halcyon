-- The window: top bar, navigation in one of four styles, pages, search, the
-- menu key, preferences and unload. Everything it creates is owned by its
-- scope, so Unload is one clean().

local UserInputService = game:GetService("UserInputService")

local Config = require("../Core/Config")
local Create = require("../Core/Create")
local Dialog = require("./Dialog")
local Drag = require("../Core/Drag")
local Env = require("../Core/Env")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Notifications = require("./Notifications")
local Popup = require("./Popup")
local Profile = require("./Profile")
local Signal = require("../Core/Signal")
local Tab = require("./Tab")
local Theme = require("../Core/Theme")

local TOPBAR = 48
-- Below this window width the side navigation becomes a strip of tabs.
local NARROW = 560
-- Two columns of sections need at least this much page width.
local COLUMNS = 520
local LANES = { Sidebar = 196, Rail = 60 }
local STRIPS = { Top = 46, Dock = 58 }
-- Where a minimised window goes: its own top bar, a pill carrying its
-- title, or the round open button.
local MINIMIZE = { Topbar = true, Pill = true, Chip = true }
-- A blurred rounded square, the same image asset WindUI stretches around
-- its window. It is sliced 99 px in from each edge.
local SHADOW_IMAGE = "rbxassetid://8992230677"
local SHADOW_SPREAD = 50
local MIN_SIZE = Vector2.new(420, 300)
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

function Window.new(kit, options, access)
	local self = setmetatable({}, Window)
	self.kit, self.options = kit, options
	self.scope = kit.scope:child()
	self.folder = Env.safeName(options.Folder or options.Title) or "Default"
	self.config = Config.new(self.folder)
	self.preferencesPath = `Halcyon/{self.folder}/settings.json`
	self.Flags, self.tabs, self.keybinds, self.gated = {}, {}, {}, {}
	self.OnUnload, self.KeybindsChanged, self.TabChanged, self.Tick = Signal.new(), Signal.new(), Signal.new(), Signal.new()
	self.query = ""
	self.Visible = true
	self.Title, self.Subtitle, self.Icon = options.Title or "Halcyon", options.Subtitle, options.Icon
	self.sectionStyle = options.SectionStyle or "Card"
	-- The value bubble over a slider's knob while it is dragged.
	self.sliderTooltips = options.SliderTooltips ~= false
	self.sliderTooltipStyle = options.SliderTooltipStyle or "Rounded"
	-- The ring drawn around a toggle's switch while its row is hovered. With
	-- no colour given it uses the theme's accent.
	self.toggleOutline = options.ToggleOutline ~= false
	self.toggleOutlineColor = options.ToggleOutlineColor
	self.toggleThumb = options.ToggleThumb or "Circle"
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
	self.lockText = options.LockText or "Requires {tier}"
	self.paidLockText = options.PaidLockText or "Paid only"
	-- The second line on a locked section's overlay.
	self.lockHint = options.LockHint
	self.paidLockHint = options.PaidLockHint or "Unlock with a paid key"
	self.lockedSections = {}

	-- Saved preferences win over the script's defaults: they are the player's choice.
	local saved = if options.SavePreferences == false then {} else readPreferences(self.preferencesPath)
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
	kit.scale = self.scale

	self.gui = Create.new("ScreenGui", { Name = "Halcyon", DisplayOrder = kit.displayOrder, Parent = Mount.parent() })
	self.scope:add(self.gui)
	-- Active, so a press on the window never reaches the game underneath.
	self.root = centred(Create.new("Frame", { Name = "Window", Active = true, ClipsDescendants = true, Theme = { BackgroundColor3 = "background" }, Parent = self.gui }))
	Create.corner(12, self.root)
	Create.stroke("stroke", self.root)
	self.uiScale = Create.new("UIScale", { Scale = self.scale, Parent = self.root })
	if options.Shadow ~= false then
		self:buildShadow()
	end

	self:buildTopbar()
	self.body = Create.new("Frame", { Name = "Body", Position = UDim2.fromOffset(0, TOPBAR), Size = UDim2.new(1, 0, 1, -TOPBAR), ClipsDescendants = true, Parent = self.root })
	self.pages = Create.new("Frame", { Name = "Pages", Parent = self.body })
	self.empty = centred(Create.new("TextLabel", {
		Name = "Empty",
		Size = UDim2.new(1, -32, 0, 40),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		Theme = { TextColor3 = "textMuted" },
		Parent = self.pages,
	}))

	self.openButton = Create.new("TextButton", {
		Name = "Open",
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

	if not kit.touch and options.Resizable ~= false then
		self:buildGrip()
	end

	self.scope:connect(UserInputService.InputBegan, function(input, processed)
		if not processed and not kit.capturing and self.toggleKey and input.KeyCode == self.toggleKey then
			self:Toggle()
		end
	end)
	self.scope:connect(self.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:layout()
	end)
	self.scope:add(Theme.Changed:Connect(function()
		self:savePreferences()
	end))

	self:layout()
	self:pop()
	return self
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
		shadow.Visible = root.Visible
		scale.Scale = self.uiScale.Scale
	end
	for _, property in { "Size", "Position", "Visible" } do
		scope:connect(root:GetPropertyChangedSignal(property), follow)
	end
	scope:connect(self.uiScale:GetPropertyChangedSignal("Scale"), follow)
	follow()
	self.shadow = shadow
end

-- The window grows the last few percent into place when it appears.
function Window:pop()
	if self.root.Visible then
		self.uiScale.Scale = self.scale * 0.96
		Motion.tween(self.uiScale, "base", { Scale = self.scale })
	end
end

function Window:buildTopbar()
	local scope = self.scope
	local topbar = Create.new("Frame", { Name = "Topbar", Size = UDim2.new(1, 0, 0, TOPBAR), Parent = self.root })
	Create.new("Frame", { Name = "Seam", Size = UDim2.new(1, 0, 0, 1), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Theme = { BackgroundColor3 = "stroke" }, Parent = topbar })

	local brand = Create.new("Frame", { Name = "Brand", Size = UDim2.fromScale(1, 1), Parent = topbar })
	local inset = Create.padding(brand, 16, 0)
	Create.list(brand, "Horizontal", 10)
	if self.Icon then
		Create.icon(self.Icon, 20, "accent", brand)
	end
	local titles = Create.new("Frame", { Name = "Titles", Size = UDim2.fromScale(0, 1), LayoutOrder = 1, Parent = brand }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(titles, "Vertical", 0, { VerticalAlignment = Enum.VerticalAlignment.Center })
	local heading = Create.new("Frame", { Name = "Heading", Size = UDim2.new(1, 0, 0, 18), ClipsDescendants = true, Parent = titles })
	Create.list(heading, "Horizontal", 8)
	self.titleLabel = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = self.Title,
		Weight = "bold",
		Theme = { TextColor3 = "text" },
		Parent = heading,
	})
	-- The version tag beside the title: shown when the hub gives a Version
	-- and has not set ShowVersion to false.
	self.versionTag = Create.new("TextLabel", {
		Name = "Version",
		Size = UDim2.fromScale(0, 1),
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
	self.subtitleLabel = Create.new("TextLabel", {
		Name = "Subtitle",
		Size = UDim2.new(1, 0, 0, 15),
		Text = self.Subtitle or "",
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Visible = self.Subtitle ~= nil,
		Theme = { TextColor3 = "textMuted" },
		Parent = titles,
	})

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

	local search = Create.new("Frame", { Name = "Search", Size = UDim2.fromOffset(170, 30), Theme = { BackgroundColor3 = "raised" }, Parent = actions })
	Create.corner(8, search)
	local glass = Create.icon("search", 14, "textMuted", search)
	glass.AnchorPoint = Vector2.new(0, 0.5)
	glass.Position = UDim2.new(0, 9, 0.5, 0)
	local box = Create.new("TextBox", {
		Name = "Query",
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -36, 1, 0),
		PlaceholderText = "Search",
		TextSize = 13,
		ClipsDescendants = true,
		Theme = { TextColor3 = "text" },
		Parent = search,
	})
	scope:connect(box:GetPropertyChangedSignal("Text"), function()
		self:applySearch(box.Text)
	end)
	self.searchFrame, self.searchBox = search, box
	search.Visible = self.options.Search ~= false

	self.chipHolder = Create.new("Frame", { Name = "Profile", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = actions })
	Create.list(self.chipHolder, "Horizontal", 0)

	local function action(icon, order, callback)
		local button = Create.new("TextButton", { Name = icon, Size = UDim2.new(0, 40, 1, 0), LayoutOrder = order, Parent = actions })
		local glyph = centred(Create.icon(icon, 16, "textMuted", button))
		scope:connect(button.MouseEnter, function()
			Theme.bind(glyph, "ImageColor3", "text")
		end)
		scope:connect(button.MouseLeave, function()
			Theme.bind(glyph, "ImageColor3", "textMuted")
		end)
		scope:connect(button.Activated, callback)
	end
	if self.options.Minimizable ~= false then
		action("minus", 2, function()
			self:Minimize(not self.minimized)
		end)
	end
	action("x", 3, function()
		self:Hide()
	end)

	Drag.move(scope, topbar, self.root, {
		onMoved = function()
			self.moved = true
		end,
	})
end

-- A corner grip for mouse users. The window is anchored at its centre, so the
-- size grows by twice the pointer's travel to keep the corner under it.
function Window:buildGrip()
	local grip = Create.new("TextButton", { Name = "Resize", Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), ZIndex = 10, Parent = self.root })
	for _, offset in { Vector2.new(12, 12), Vector2.new(7, 12), Vector2.new(12, 7) } do
		Create.new("Frame", { Size = UDim2.fromOffset(2, 2), Position = UDim2.fromOffset(offset.X, offset.Y), Theme = { BackgroundColor3 = "textMuted" }, Parent = grip })
	end
	local start = self.size
	Drag.track(self.scope, grip, function()
		start = self.size
		return not self.minimized
	end, function(position, origin)
		local travel = (position - origin) * (2 / self.scale)
		self.size = Vector2.new(math.max(start.X + travel.X, MIN_SIZE.X), math.max(start.Y + travel.Y, MIN_SIZE.Y))
		self:layout()
	end)
end

-- Fits the window to the screen and picks the navigation and column layout
-- for the width it ended up with. Runs on every viewport or setting change.
function Window:layout()
	local view, scale = self.gui.AbsoluteSize, self.scale
	local width = math.max(math.min(self.size.X, (view.X - 16) / scale), 240)
	local height = math.max(math.min(self.size.Y, (view.Y - 16) / scale), 200)
	local folded = self.minimized and self.minimizeStyle == "Topbar"
	self.root.Size = UDim2.fromOffset(width, if folded then TOPBAR else height)
	self.body.Visible = not folded

	local narrow = width < NARROW
	local style = self.tabStyle
	if narrow and LANES[style] then
		style = "Top"
	end
	if style ~= self.activeStyle then
		self.activeStyle = style
		self:buildNav()
	end
	self.searchFrame.Size = UDim2.fromOffset(if narrow then 104 else 170, 30)

	self.wide = width - (LANES[style] or 0) >= COLUMNS
	for _, tab in self.tabs do
		tab:reflow(self.wide)
	end

	if self.moved then
		local position = self.root.Position
		local halfWidth, halfHeight = width * scale / 2, height * scale / 2
		self.root.Position = UDim2.fromOffset(
			math.clamp(position.X.Offset, halfWidth, math.max(view.X - halfWidth, halfWidth)),
			math.clamp(position.Y.Offset, halfHeight, math.max(view.Y - halfHeight, halfHeight))
		)
	end
end

-- Rebuilds the tab buttons for the active style. The pages, the selected tab
-- and every element value stay as they are; only the navigation is redrawn.
function Window:buildNav()
	if self.navScope then
		self.scope:release(self.navScope)
	end
	Popup.close(self.kit)
	local scope = self.scope:child()
	self.navScope = scope
	local style = self.activeStyle
	local lane, strip = LANES[style], STRIPS[style]

	local host = Create.new("Frame", { Name = "Navigation", Parent = self.body })
	scope:add(host)
	local seam = Create.new("Frame", { Name = "Seam", ZIndex = 2, Theme = { BackgroundColor3 = "stroke" }, Parent = host })
	local list

	if lane then
		host.Size = UDim2.new(0, lane, 1, 0)
		seam.Size = UDim2.new(0, 1, 1, 0)
		seam.AnchorPoint = Vector2.new(1, 0)
		seam.Position = UDim2.fromScale(1, 0)
		self.pages.Position = UDim2.fromOffset(lane, 0)
		self.pages.Size = UDim2.new(1, -lane, 1, 0)

		local column = Create.new("Frame", { Name = "Column", Size = UDim2.new(1, -1, 1, 0), Parent = host })
		Create.list(column, "Vertical", 0)
		list = Create.new("ScrollingFrame", { Name = "Tabs", Size = UDim2.fromScale(1, 0), ScrollBarThickness = 0, Parent = column }, {
			Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		Create.padding(list, 8)
		Create.list(list, "Vertical", 2)
		if self.profile.Enabled then
			Create.new("Frame", { Name = "Seam", Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 1, Theme = { BackgroundColor3 = "stroke" }, Parent = column })
			local footer = Create.new("Frame", { Name = "Footer", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = column })
			Create.list(footer, "Vertical", 0, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
			if style == "Sidebar" then
				Profile.card(self, scope, footer)
			else
				Profile.chip(self, scope, footer)
			end
		end
	else
		host.Size = UDim2.new(1, 0, 0, strip)
		seam.Size = UDim2.new(1, 0, 0, 1)
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
	for _, tab in self.tabs do
		if style == "Sidebar" and tab.Group and tab.Group ~= group then
			order += 1
			self:buildGroupHeading(list, scope, tab.Group, order)
		end
		group = tab.Group
		order += 1
		tab:buildButton(style, list, scope, order)
		if style == "Sidebar" and tab.Group and self.collapsedGroups[tab.Group] then
			tab.button.Visible = false
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
		Size = UDim2.new(1, 0, 0, if collapsible and self.kit.touch then 40 else 28),
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

function Window:paintTabs()
	for _, tab in self.tabs do
		tab:paint(tab == self.selected, self.query ~= "" and tab.matches == 0)
	end
end

function Window:Tab(options)
	if type(options) == "string" then
		options = { Title = options }
	end
	if type(options) ~= "table" or type(options.Title) ~= "string" then
		error("Tab needs a Title", 2)
	end
	local tab = Tab.new(self, options)
	table.insert(self.tabs, tab)
	tab:reflow(self.wide)
	self:buildNav()
	if not self.selected then
		self:SelectTab(tab)
	end
	return tab
end

function Window:SelectTab(tab)
	if self.selected == tab then
		return
	end
	Popup.close(self.kit)
	if self.selected then
		self.selected.page.Visible = false
	end
	self.selected = tab
	tab.page.Visible = true
	tab.page.Position = UDim2.fromOffset(0, 8)
	Motion.tween(tab.page, "base", { Position = UDim2.fromOffset(0, 0) })
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
		if tab:filter(self.query) > 0 and not first then
			first = tab
		end
	end
	if self.query ~= "" and first and self.selected and self.selected.matches == 0 then
		self:SelectTab(first)
	end
	self.empty.Visible = self.query ~= "" and first == nil
	self.empty.Text = `Nothing matches "{self.query}".`
	if self.selected then
		self.selected.page.Visible = not self.empty.Visible
	end
	self:paintTabs()
end

function Window:Search(query)
	self.searchBox.Text = query or ""
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
	local docked = self.minimized and self.minimizeStyle ~= "Topbar"
	self.root.Visible = self.Visible and not docked
	self.pill.Visible = self.Visible and docked and self.minimizeStyle == "Pill"
	-- A phone has no menu key, so a hidden window always leaves a button to bring it back.
	self.openButton.Visible = (self.Visible and docked and self.minimizeStyle == "Chip")
		or (not self.Visible and (self.kit.touch or self.options.OpenButton == true))
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
	Popup.close(self.kit)
	self.Visible = false
	self:refreshVisibility()
	if not self.openButton.Visible and not self.hinted and self.toggleKey then
		self.hinted = true
		self:Notify({ Title = "Menu hidden", Content = `Press {self.toggleKey.Name} to open it again.` })
	end
end

function Window:Toggle()
	if self.Visible then
		self:Hide()
	else
		self:Show()
	end
end

function Window:Minimize(minimized)
	self.minimized = minimized == true
	Popup.close(self.kit)
	self:layout()
	self:refreshVisibility()
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
	self.kit.scale = self.scale
	self.uiScale.Scale = self.scale
	Popup.close(self.kit)
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
	self.titleLabel.Text = title
	self.pillLabel.Text = title
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
	self.subtitleLabel.Text = subtitle or ""
	self.subtitleLabel.Visible = subtitle ~= nil and subtitle ~= ""
end

function Window:writePreferences()
	self.preferencesQueued = false
	local collapsed = {}
	for name in self.collapsedGroups do
		table.insert(collapsed, name)
	end
	table.sort(collapsed)
	local encoded, text = Env.encode({
		version = PREFERENCES_VERSION,
		collapsedGroups = collapsed,
		minimizeStyle = self.minimizeStyle,
		theme = Theme.current.Name,
		tabStyle = self.tabStyle,
		scale = self.scale,
		reducedMotion = Motion.reduced,
		anonymous = self.profile.Anonymous,
		toggleKey = if self.toggleKey then self.toggleKey.Name else "",
	})
	local wrote, message = false, "The settings could not be encoded."
	if encoded then
		wrote, message = Env.write(self.preferencesPath, text)
	end
	if not wrote and not self.preferencesWarned then
		self.preferencesWarned = true
		self:Notify({ Title = "Settings not saved", Content = message, Kind = "warning" })
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
	return Notifications.push(self.kit, options)
end

function Window:Dialog(options)
	return Dialog.open(self.kit, options)
end

-- Configs -------------------------------------------------------------------

function Window:SaveConfig(name)
	return self.config:save(name)
end

function Window:LoadConfig(name)
	return self.config:load(name)
end

function Window:DeleteConfig(name)
	return self.config:delete(name)
end

function Window:ListConfigs()
	return self.config:list()
end

function Window:SetAutoload(name)
	return self.config:setAutoload(name)
end

function Window:GetAutoload()
	return self.config:getAutoload()
end

-- Call this after every element exists: a flag the hub has not created yet
-- is skipped.
function Window:LoadAutoload()
	local name = self.config:getAutoload()
	if not name then
		return false, "No autoload config is set."
	end
	return self.config:load(name)
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
	Popup.close(self.kit)
	self.kit.scope:release(self.scope)
	local index = table.find(self.kit.windows, self)
	if index then
		table.remove(self.kit.windows, index)
	end
	if self.onUnloaded then
		self.onUnloaded()
	end
end

return Window
