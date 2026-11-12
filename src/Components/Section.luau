-- A titled group of rows: the "groupbox". Its look comes from the style
-- registry (kind "Section"):
--   Card      a filled surface with an outline; rows sit on it unboxed
--   Outlined  the outline alone
--   Flat      no container; each row carries its own fill
--   Glass     a see-through card
--   Accent    a card with an accent stripe down its left edge
--   Inset     sunk into the page: the page colour with an outline
--   Header    a card whose title sits on a band of its own

local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Registry = require("../Elements/Registry")
local Row = require("../Elements/Row")
local Signal = require("../Core/Signal")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")
local Tokens = require("../Core/Tokens")

-- fill: the section's own colour; stroke: its outline; surface: the colour
-- rows sit on (veils match it); flat: no container at all.
Styles.register("Section", "Card", { fill = "card", stroke = "stroke", surface = "card" })
Styles.register("Section", "Outlined", { stroke = "stroke", surface = "background" })
Styles.register("Section", "Flat", { flat = true, surface = "background" })
Styles.register("Section", "Glass", { fill = "card", fillTransparency = 0.35, stroke = "text", strokeTransparency = 0.88, surface = "card" })
Styles.register("Section", "Accent", { fill = "card", stroke = "stroke", surface = "card", edge = "accent" })
Styles.register("Section", "Inset", { fill = "background", stroke = "stroke", surface = "background" })
Styles.register("Section", "Header", { fill = "card", stroke = "stroke", surface = "card", band = "raised" })

local Section = {}
Section.__index = Section

-- Options: Title, Icon, IconColor, Description, Badge, Style, Side,
-- Tabs (a list of names: tabs inside the box, see Section:Tab), Switch
-- ({ Default, Flag, Callback }: a switch in the header that greys the rows
-- while off), MaxHeight (the rows scroll past this height), ("Left" or "Right"), Collapsible,
-- Collapsed, Tier or PaidOnly (lock every row inside under one overlay),
-- LockText, LockHint.
function Section.new(tab, options)
	options = options or {}
	local window = tab.window
	local look = Styles.pick("Section", options.Style or tab.sectionStyle, window)
	local flat = look.flat == true
	local self = setmetatable({
		library = tab.library,
		window = window,
		tab = tab,
		scope = tab.scope:child(),
		entries = tab.entries,
		order = 0,
		tier = options.Tier or (options.PaidOnly and true) or tab.tier,
		lockText = options.LockText or tab.lockText,
		lockHint = options.LockHint or tab.lockHint,
		rowFill = flat,
		surface = look.surface or "card",
		side = if options.Side == "Right" then "Right" else "Left",
		Title = options.Title,
		Hidden = false,
		collapsed = options.Collapsed == true,
		searching = false,
	}, Section)
	self.section = self
	self.searchTitle = if options.Title then string.lower(options.Title) else nil

	local root = Create.new("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = tab:nextOrder(),
		BackgroundTransparency = if look.fill then look.fillTransparency or 0 else 1,
		Theme = { BackgroundColor3 = look.fill or "card" },
		Parent = tab.left,
	})
	self.scope:add(root)
	self.root = root
	self.look = look
	if not flat then
		Create.corner(10, root)
		if look.stroke then
			local stroke = Create.stroke(look.stroke, root)
			stroke.Transparency = look.strokeTransparency or 0
		end
	end
	Create.list(root, "Vertical", 0)

	if options.Title then
		local collapsible = options.Collapsible ~= false
		local holder = root
		if look.band then
			-- The band is rounded on top only: a square strip fills its
			-- lower corners while the rows show below it.
			holder = Create.new("Frame", { Name = "Band", Size = UDim2.new(1, 0, 0, 40), Theme = { BackgroundColor3 = look.band }, Parent = root })
			Create.corner(10, holder)
			self.bandFill = Create.new("Frame", {
				Name = "Square",
				Size = UDim2.new(1, 0, 0, 10),
				Position = UDim2.new(0, 0, 1, -10),
				Theme = { BackgroundColor3 = look.band },
				Parent = holder,
			})
		end
		local header = Create.new(if collapsible then "TextButton" else "Frame", {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, if flat then 32 else 40),
			ZIndex = 2,
			Parent = holder,
		})
		Create.padding(header, if flat then 4 else 14, 0)
		Create.list(header, "Horizontal", 8)
		if options.Icon then
			-- IconColor is a theme role name or a Color3.
			local icon = Create.icon(options.Icon, 16, "textMuted", header)
			Theme.paint(icon, "ImageColor3", options.IconColor)
		end
		self.label = Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.fromScale(0, 1),
			TextSize = 13,
			Weight = "bold",
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = 1,
			Text = options.Title,
			Theme = { TextColor3 = "text" },
			Parent = header,
		}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
		self.header = header
		if options.Badge ~= nil then
			self:SetBadge(options.Badge)
		end
		if type(options.Switch) == "table" then
			self:buildSwitch(header, options.Switch)
		end
		if collapsible then
			-- The arrow turns inside a fixed holder: a rotated child of a
			-- list layout is drawn unrotated.
			local holder = Create.new("Frame", { Name = "Arrow", Size = UDim2.fromOffset(14, 14), LayoutOrder = 4, Parent = header })
			self.chevron = Create.icon("chevron-down", 14, "textMuted", holder)
			self.scope:connect(header.Activated, function()
				self:SetCollapsed(not self.collapsed)
			end)
		end
	end

	-- The body has no layout of its own, so a lock overlay can lie across
	-- the rows without becoming a row itself.
	local body = Create.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = root,
	})
	self.body = body
	if look.edge then
		-- The body has no layout, so the stripe lies beside the rows
		-- without becoming one of them.
		local stripe = Create.new("Frame", {
			Name = "Edge",
			Size = UDim2.new(0, 3, 1, -12),
			Position = UDim2.fromOffset(5, 4),
			Theme = { BackgroundColor3 = look.edge },
			Parent = body,
		})
		Create.corner(-1, stripe)
	end
	local rows = Create.new(if options.MaxHeight then "ScrollingFrame" else "Frame", {
		Name = "Rows",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
	if options.MaxHeight then
		-- A long list scrolls inside its box instead of stretching the page.
		Create.new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, tonumber(options.MaxHeight) or 240), Parent = rows })
	end
	if not flat then
		local edge = if look.edge then 8 else 0
		Create.padding(rows, 6 + edge, if options.Title and not look.band then 0 else 6, 6, 6)
	end
	Create.list(rows, "Vertical", if flat then Tokens.density.gap else 2)
	if options.Description then
		-- A line under the title that explains the group; it folds with the rows.
		self.description = Create.new("TextLabel", {
			Name = "Description",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 12,
			LayoutOrder = 0,
			Text = options.Description,
			Theme = { TextColor3 = "textMuted" },
			Parent = rows,
		})
		Create.padding(self.description, 6, 0, 6, 4)
	end
	self.frame, self.rows = rows, rows

	if self.tier then
		self:buildLock()
	end
	Registry.install(self)
	if type(options.Tabs) == "table" and #options.Tabs > 0 then
		self:buildTabs(options.Tabs)
	end
	self:refresh()
	return self
end

-- A locked section wears one overlay across all of it: an accent disc with
-- a crown or lock, the hub's wording and a hint. Its rows stay dimmed
-- underneath without a badge each, so the section reads as one offer.
function Section:buildLock()
	local overlay = Create.new("TextButton", {
		Name = "LockOverlay",
		Size = UDim2.fromScale(1, 0),
		ZIndex = 6,
		BackgroundTransparency = 0.06,
		Visible = false,
		Theme = { BackgroundColor3 = self.surface },
		Parent = self.body,
	})
	Create.corner(10, overlay)
	Create.new("UIStroke", { Transparency = 0.45, Theme = { Color = "accent" }, Parent = overlay })
	-- A wash of the accent, strongest in the top corner, lifts the overlay
	-- off the plain surface.
	local wash = Create.new("Frame", {
		Name = "Wash",
		Size = UDim2.fromScale(1, 1),
		Theme = { BackgroundColor3 = "accent" },
		Parent = overlay,
	}, {
		Create.new("UIGradient", {
			Rotation = 35,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.8),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	Create.corner(10, wash)

	local content = Create.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 2,
		Parent = overlay,
	})
	Create.list(content, "Horizontal", 10)
	local disc = Create.new("Frame", {
		Name = "Disc",
		Size = UDim2.fromOffset(34, 34),
		Theme = { BackgroundColor3 = "accent" },
		Parent = content,
	})
	Create.corner(-1, disc)
	local icon = Create.icon("lock", 16, "onAccent", disc)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local text = Create.new("Frame", { Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = content }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(text, "Vertical", 1)
	local title = Create.new("TextLabel", {
		Name = "Reason",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Weight = "bold",
		Theme = { TextColor3 = "text" },
		Parent = text,
	})
	local hint = Create.new("TextLabel", {
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 12,
		LayoutOrder = 1,
		Theme = { TextColor3 = "textMuted" },
		Parent = text,
	})

	-- The overlay is given the rows' height in pixels. A child sized by
	-- scale inside a frame that sizes itself to its children feeds back and
	-- stretches both.
	local rows = self.rows
	self.lockShimmer = Effects.shimmer(self.scope, overlay, 10)
	-- A locked section with a single short row still has room for the
	-- overlay's icon, wording and hint.
	self.lockMinimum = Create.new("UISizeConstraint", { MinSize = Vector2.new(0, 0), Parent = rows })
	local function cover()
		overlay.Size = UDim2.new(1, 0, 0, rows.AbsoluteSize.Y / self.library.scale)
	end
	self.scope:connect(rows:GetPropertyChangedSignal("AbsoluteSize"), cover)
	cover()

	self.lockOverlay = { frame = overlay, icon = icon, title = title, hint = hint }
	local sections = self.window.lockedSections
	table.insert(sections, self)
	self.scope:add(function()
		local index = table.find(sections, self)
		if index then
			table.remove(sections, index)
		end
	end)
	self:refreshLock()
end

function Section:refreshLock()
	local lock = self.lockOverlay
	if not lock then
		return
	end
	local wording, hint = self.window:lockWording(self.tier, self.lockText, self.lockHint)
	lock.frame.Visible = not self.window:allows(self.tier)
	self.lockMinimum.MinSize = Vector2.new(0, if lock.frame.Visible then 84 else 0)
	if lock.frame.Visible and self.window.lockShimmer then
		self.lockShimmer.start()
	else
		self.lockShimmer.stop()
	end
	lock.title.Text = wording
	lock.hint.Text = hint or ""
	lock.hint.Visible = hint ~= nil and hint ~= ""
	Icons.apply(lock.icon, if self.tier == true then "crown" else "lock")
end

function Section:nextOrder()
	self.order += 1
	return self.order
end

-- A search opens a collapsed section for as long as the query lasts.
function Section:refresh()
	local open = self.searching or not self.collapsed
	self.rows.Visible = open
	if self.pages then
		-- A search shows every inner tab's matches at once.
		for name, page in self.pages do
			page.frame.Visible = self.searching or name == self.page
		end
		self.strip.Visible = not self.searching
	end
	if self.bandFill then
		self.bandFill.Visible = open
	end
	if self.chevron then
		Motion.tween(self.chevron, "fast", { Rotation = if open then 0 else -90 })
	end
end

function Section:setSearching(searching)
	if self.searching ~= searching then
		self.searching = searching
		self:refresh()
	end
end

function Section:SetCollapsed(collapsed)
	self.collapsed = collapsed == true
	self:refresh()
end

-- A small switch in the header. While it is off every row in the section
-- is greyed and ignores presses; the rows keep their own values.
function Section:buildSwitch(header, settings)
	local on = settings.Default ~= false
	local track = Create.new("TextButton", {
		Name = "Switch",
		Size = UDim2.fromOffset(30, 16),
		LayoutOrder = 3,
		Theme = { BackgroundColor3 = "stroke" },
		Parent = header,
	})
	Create.corner(-1, track)
	local knob = Create.new("Frame", { Name = "Thumb", Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0, 0.5), Parent = track })
	Create.corner(-1, knob)
	local handle = { Title = (self.Title or "Section") .. " switch", Changed = Signal.new(), scope = self.scope }
	self.scope:add(handle.Changed)
	local function draw(timing)
		Theme.bind(track, "BackgroundColor3", if on then "accent" else "stroke", true)
		Theme.bind(knob, "BackgroundColor3", if on then "onAccent" else "textMuted", true)
		Motion.tween(track, timing, { BackgroundColor3 = Theme.color(if on then "accent" else "stroke") })
		Motion.tween(knob, timing, {
			Position = UDim2.new(0, if on then 16 else 2, 0.5, 0),
			BackgroundColor3 = Theme.color(if on then "onAccent" else "textMuted"),
		})
	end
	function handle:Get()
		return on
	end
	function handle.Set(_, value)
		on = value == true
		self.switchedOff = not on
		draw("fast")
		for _, entry in self.entries do
			if entry.section == self then
				entry.handle:SetBlocked(not on or self.window.disabledAll == true)
			end
		end
		handle.Changed:Fire(on)
		Env.call(handle.Title, settings.Callback, on)
	end
	self.scope:connect(track.Activated, function()
		handle:Set(not on)
	end)
	self.switch = handle
	self.switchedOff = not on
	self.window:claimFlag(settings.Flag, handle, self.scope)
	draw(nil)
	-- Rows added later are greyed by Registry while the switch is off.
	task.defer(function()
		if not on and not self.scope.cleaned then
			handle:Set(false)
		end
	end)
end

-- Tabs inside the box: a strip of names over the rows, each with rows of
-- its own. Elements added to the section itself go to the first one.
function Section:buildTabs(names)
	local strip = Create.new("Frame", { Name = "Strip", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = -1, Parent = self.rows })
	Create.padding(strip, 2, 0)
	Create.list(strip, "Horizontal", 4)
	self.strip = strip
	self.pages, self.pageButtons, self.pageOrder = {}, {}, {}
	local height = if self.library.touch then 36 else 28
	strip.Size = UDim2.new(1, 0, 0, height + 2)
	for index, name in names do
		name = tostring(name)
		local button = Create.new("TextButton", {
			Name = "Page",
			Size = UDim2.fromScale(0, 1),
			Text = name,
			TextSize = 12,
			Weight = "medium",
			LayoutOrder = index,
			BackgroundTransparency = 1,
			Theme = { BackgroundColor3 = "raised", TextColor3 = "textMuted" },
			Parent = strip,
		}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
		Create.corner(6, button)
		local frame = Create.new("Frame", {
			Name = "Rows",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = index,
			Visible = index == 1,
			Parent = self.rows,
		})
		Create.list(frame, "Vertical", if self.rowFill then Tokens.density.gap else 2)
		local page = setmetatable({ frame = frame, order = 0, Title = name }, { __index = self })
		function page.nextOrder(container)
			rawset(container, "order", rawget(container, "order") + 1)
			return rawget(container, "order")
		end
		Registry.install(page)
		self.pages[name], self.pageButtons[name] = page, button
		table.insert(self.pageOrder, name)
		self.scope:connect(button.Activated, function()
			self:SelectTab(name)
		end)
	end
	self:SelectTab(self.pageOrder[1])
	-- The section's own element methods add to the first inner tab.
	local first = self.pages[self.pageOrder[1]]
	for kind in first do
		if type(rawget(first, kind)) == "function" and kind ~= "nextOrder" then
			self[kind] = function(_, options)
				return first[kind](first, options)
			end
		end
	end
end

-- The inner tab called `name`, to add elements to: box:Tab("Aimbot"):Toggle({...}).
function Section:Tab(name)
	local page = self.pages and self.pages[name]
	if not page then
		error(`This section has no tab called "{tostring(name)}"`, 2)
	end
	return page
end

function Section:SelectTab(name)
	if not (self.pages and self.pages[name]) then
		return
	end
	self.page = name
	for other, button in self.pageButtons do
		local active = other == name
		Theme.bind(button, "TextColor3", if active then "text" else "textMuted")
		button.FontFace = Create.font(if active then "bold" else "medium")
		Motion.tween(button, "fast", { BackgroundTransparency = if active then 0 else 1 })
	end
	self:refresh()
end

-- Shows the section only while `source` (an element or its Flag) has the
-- value `expected` (default true), or while `expected(value)` returns true.
function Section:ShowWhen(source, expected)
	Registry.follow(self, source, expected)
end

-- A count or word in a small pill beside the title; nil or false removes it.
function Section:SetBadge(value)
	if self.badge then
		self.badge:Destroy()
		self.badge = nil
	end
	if self.header and value ~= nil and value ~= false then
		self.badge = Row.badge(self.header, if type(value) == "number" then tostring(value) else value)
		self.badge.LayoutOrder = 2
	end
end

function Section:SetTitle(title)
	self.Title = title
	self.searchTitle = string.lower(title)
	if self.label then
		self.label.Text = title
	end
end

function Section:SetVisible(visible)
	self.Hidden = not visible
	self.window:applySearch()
end

function Section:Destroy()
	local sections = self.tab.sections
	local index = table.find(sections, self)
	if index then
		table.remove(sections, index)
	end
	self.tab.scope:release(self.scope)
end

return Section
