-- A titled group of rows: the "groupbox". Three looks:
--   Card      a filled surface with an outline; rows sit on it unboxed
--   Outlined  the outline alone
--   Flat      no container; each row carries its own fill

local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Registry = require("../Elements/Registry")

local Section = {}
Section.__index = Section

-- Options: Title, Icon, Style, Side ("Left" or "Right"), Collapsible,
-- Collapsed, Tier or PaidOnly (lock every row inside under one overlay),
-- LockText, LockHint.
function Section.new(tab, options)
	options = options or {}
	local window = tab.window
	local style = options.Style or tab.sectionStyle or window.sectionStyle
	local flat = style == "Flat"
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
		surface = if style == "Card" then "card" else "background",
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
		BackgroundTransparency = if style == "Card" then 0 else 1,
		Theme = { BackgroundColor3 = "card" },
		Parent = tab.left,
	})
	self.scope:add(root)
	self.root = root
	if not flat then
		Create.corner(10, root)
		Create.stroke("stroke", root)
	end
	Create.list(root, "Vertical", 0)

	if options.Title then
		local collapsible = options.Collapsible ~= false
		local header = Create.new(if collapsible then "TextButton" else "Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, if flat then 32 else 40), Parent = root })
		Create.padding(header, if flat then 4 else 14, 0)
		Create.list(header, "Horizontal", 8)
		if options.Icon then
			Create.icon(options.Icon, 16, "textMuted", header)
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
		if collapsible then
			-- The arrow turns inside a fixed holder: a rotated child of a
			-- list layout is drawn unrotated.
			local holder = Create.new("Frame", { Name = "Arrow", Size = UDim2.fromOffset(14, 14), LayoutOrder = 2, Parent = header })
			self.chevron = Create.icon("chevron-down", 14, "textMuted", holder)
			self.scope:connect(header.Activated, function()
				self:SetCollapsed(not self.collapsed)
			end)
		end
	end

	-- The body has no layout of its own, so a lock overlay can lie across
	-- the rows without becoming a row itself.
	local body = Create.new("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = root })
	self.body = body
	local rows = Create.new("Frame", { Name = "Rows", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = body })
	if not flat then
		Create.padding(rows, 6, if options.Title then 0 else 6, 6, 6)
	end
	Create.list(rows, "Vertical", if flat then 6 else 2)
	self.frame = rows

	if self.tier then
		self:buildLock()
	end
	Registry.install(self)
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
	local wash = Create.new("Frame", { Name = "Wash", Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "accent" }, Parent = overlay }, {
		Create.new("UIGradient", {
			Rotation = 35,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }),
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
	local disc = Create.new("Frame", { Name = "Disc", Size = UDim2.fromOffset(34, 34), Theme = { BackgroundColor3 = "accent" }, Parent = content })
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
	local rows = self.frame
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
	self.frame.Visible = open
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
