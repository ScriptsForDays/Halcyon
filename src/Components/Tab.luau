-- A tab: its page of sections and its button in the navigation. The page
-- holds one or two columns and folds to one when the window is narrow, so a
-- phone shows the same controls in one ordered flow.

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Registry = require("../Elements/Registry")
local Section = require("./Section")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

local GAP = 10

-- How the open tab is marked (kind "TabIndicator").
--   marker  "edge" (a bar on the leading edge), "under" (a line under it),
--           "dot" (a dot at the trailing end) or nil
--   fill, fillTransparency  the open tab's background
--   text, icon              the open tab's title and icon roles
--   glow                    an accent outline around the open tab
Styles.register("TabIndicator", "Bar", { marker = "edge", fill = "raised", fillTransparency = 0 })
Styles.register("TabIndicator", "Pill", { fill = "accent", fillTransparency = 0.85, text = "accent" })
Styles.register("TabIndicator", "Underline", { marker = "under" })
Styles.register("TabIndicator", "Dot", { marker = "dot", text = "text" })
Styles.register("TabIndicator", "Glow", { fill = "raised", fillTransparency = 0, glow = true })
Styles.register("TabIndicator", "Fill", { fill = "accent", fillTransparency = 0, text = "onAccent", icon = "onAccent" })

local NOTICE_ICONS = { info = "info", success = "circle-check", warning = "triangle-alert", danger = "circle-x" }

local Tab = {}
Tab.__index = Tab

-- Options: Title, Icon, Group (a heading above this tab in the sidebar),
-- SectionStyle, Tier or PaidOnly (lock every row inside), LockText,
-- Description (a heading with this line at the top of the page).
function Tab.new(window, options)
	local self = setmetatable({
		library = window.library,
		window = window,
		scope = window.scope:child(),
		entries = {},
		sections = {},
		order = 0,
		Title = options.Title,
		Description = options.Description,
		Icon = options.Icon,
		Group = options.Group,
		tier = options.Tier or (options.PaidOnly and true) or nil,
		lockText = options.LockText,
		lockHint = options.LockHint,
		sectionStyle = options.SectionStyle,
		matches = 0,
		wide = false,
	}, Tab)

	local page = Create.new("ScrollingFrame", { Name = "Page", Size = UDim2.fromScale(1, 1), Visible = false, Parent = window.pages })
	-- The padding sits on a plain frame: scale-sized children of a padded
	-- ScrollingFrame keep the full canvas width and overflow on the right.
	local inset = Create.new("Frame", { Name = "Inset", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = page })
	Create.padding(inset, 12)
	Create.list(inset, "Vertical", GAP)
	if options.Description then
		-- The page names itself, with a line on what the tab is for.
		local header = Create.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = inset })
		Create.padding(header, 4, 2, 4, 2)
		Create.list(header, "Vertical", 2)
		Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 24),
			Text = options.Title,
			TextSize = 20,
			Weight = "bold",
			Theme = { TextColor3 = "text" },
			Parent = header,
		})
		Create.new("TextLabel", {
			Name = "Description",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 13,
			LayoutOrder = 1,
			Text = options.Description,
			Theme = { TextColor3 = "textMuted" },
			Parent = header,
		})
	end
	self.notices = Create.new("Frame", { Name = "Notices", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Visible = false, Parent = inset })
	Create.list(self.notices, "Vertical", 6)
	local columns = Create.new("Frame", {
		Name = "Columns",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = inset,
	})
	self.page = page
	self.left = Create.new("Frame", { Name = "Left", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = columns })
	self.right = Create.new("Frame", {
		Name = "Right",
		Size = UDim2.new(0.5, -GAP / 2, 0, 0),
		Position = UDim2.new(0.5, GAP / 2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = columns,
	})
	Create.list(self.left, "Vertical", GAP)
	Create.list(self.right, "Vertical", GAP)
	self.scope:add(page)
	return self
end

function Tab:nextOrder()
	self.order += 1
	return self.order
end

function Tab:Section(options)
	local section = Section.new(self, options)
	table.insert(self.sections, section)
	self.last = section
	self:reflow(self.wide)
	return section
end

-- Two columns only when the page is wide enough and something asked for the
-- right one; otherwise every section stacks in the order it was created.
function Tab:reflow(wide)
	self.wide = wide
	local double = false
	if wide then
		for _, section in self.sections do
			if section.side == "Right" then
				double = true
				break
			end
		end
	end
	self.left.Size = if double then UDim2.new(0.5, -GAP / 2, 0, 0) else UDim2.new(1, 0, 0, 0)
	self.right.Visible = double
	for _, section in self.sections do
		section.root.Parent = if double and section.side == "Right" then self.right else self.left
	end
end

-- A callout at the top of the page: an outage, a patch warning, a tip.
-- Options: Title, Content, Kind ("info", "success", "warning", "danger"),
-- Dismissible (a cross that removes it). Returns { SetContent, Destroy }.
function Tab:Notice(options)
	if type(options) == "string" then
		options = { Content = options }
	end
	local role = if NOTICE_ICONS[options.Kind] then options.Kind else "info"
	local scope = self.scope:child()
	local box = Create.new("Frame", {
		Name = "Notice",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.88,
		Theme = { BackgroundColor3 = role },
		Parent = self.notices,
	})
	scope:add(box)
	Create.corner(10, box)
	Create.stroke(role, box).Transparency = 0.55
	Create.padding(box, 12, 10)
	Create.list(box, "Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Top })
	Create.icon(NOTICE_ICONS[role], 18, role, box)
	local text = Create.new("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		RichText = true,
		TextSize = 13,
		LayoutOrder = 1,
		Theme = { TextColor3 = "text" },
		Parent = box,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	local function write(content)
		text.Text = if options.Title then `<b>{options.Title}</b>  {content or ""}` else tostring(content or "")
	end
	write(options.Content)
	self.notices.Visible = true
	local notice = {}
	function notice.SetContent(_, content)
		write(content)
	end
	function notice.Destroy()
		self.scope:release(scope)
		self.notices.Visible = #self.notices:GetChildren() > 1
	end
	if options.Dismissible then
		local close = Create.new("ImageButton", { Name = "Dismiss", Size = UDim2.fromOffset(18, 18), LayoutOrder = 2, Parent = box })
		local glyph = Create.icon("x", 14, "textMuted", close)
		glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		scope:connect(close.Activated, notice.Destroy)
	end
	return notice
end

-- Hides rows that do not match and sections left empty. Returns the match
-- count. A query that matches the tab's own name keeps every row.
function Tab:filter(query)
	local counts, total = {}, 0
	local named = query ~= "" and string.find(string.lower(self.Title), query, 1, true) ~= nil
	for _, entry in self.entries do
		local handle, section = entry.handle, entry.section
		local match = query == ""
			or named
			or string.find(handle.SearchText or "", query, 1, true) ~= nil
			or (section.searchTitle ~= nil and string.find(section.searchTitle, query, 1, true) ~= nil)
		handle.Frame.Visible = match and not handle.Hidden
		if handle.Highlight then
			handle:Highlight(if match then query else nil)
		end
		if match then
			total += 1
			counts[section] = (counts[section] or 0) + 1
		end
	end
	for _, section in self.sections do
		section.root.Visible = not section.Hidden and (query == "" or (counts[section] or 0) > 0)
		section:setSearching(query ~= "")
	end
	self.matches = total
	return total
end

-- Builds this tab's button for the active navigation style.
function Tab:buildButton(style, parent, scope, order)
	local button = Create.new("TextButton", {
		Name = "Tab",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Theme = { BackgroundColor3 = "raised" },
		Parent = parent,
	})
	Create.corner(8, button)
	local icon = Create.icon(self.Icon or "circle", if style == "Rail" or style == "Dock" then 20 else 18, "textMuted", button)
	local label = Create.new("TextLabel", {
		Name = "Title",
		Text = self.Title,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Theme = { TextColor3 = "textMuted" },
		Parent = button,
	})

	self.bar, self.inner = nil, nil
	local look = Styles.pick("TabIndicator", nil, self.window)
	self.look = look
	-- The marker is not laid out: it lies over the button wherever it goes.
	local function marker()
		local frame = Create.new("Frame", {
			Name = "Marker",
			Visible = false,
			ZIndex = 2,
			Theme = { BackgroundColor3 = "accent" },
		})
		Create.corner(-1, frame)
		if look.marker == "under" then
			frame.Size = UDim2.new(0.6, 0, 0, 2)
			frame.AnchorPoint = Vector2.new(0.5, 1)
			frame.Position = UDim2.new(0.5, 0, 1, 0)
		elseif look.marker == "dot" then
			frame.Size = UDim2.fromOffset(6, 6)
			frame.AnchorPoint = Vector2.new(1, 0.5)
			frame.Position = UDim2.new(1, -8, 0.5, 0)
		elseif style == "Sidebar" then
			frame.Size = UDim2.fromOffset(3, 16)
			frame.AnchorPoint = Vector2.new(0, 0.5)
			frame.Position = UDim2.fromScale(0, 0.5)
		else
			-- The edge bar sits under strips and beside lanes.
			frame.Size = if style == "Rail" then UDim2.fromOffset(3, 18) else UDim2.new(0.5, 0, 0, 3)
			frame.AnchorPoint = if style == "Rail" then Vector2.new(0, 0.5) else Vector2.new(0.5, 1)
			frame.Position = if style == "Rail" then UDim2.fromScale(0, 0.5) else UDim2.new(0.5, 0, 1, 0)
		end
		return frame
	end
	if look.glow then
		self.glow = Create.new("UIStroke", { Thickness = 1.5, Transparency = 1, Theme = { Color = "accent" }, Parent = button })
	else
		self.glow = nil
	end
	if style == "Sidebar" then
		button.Size = UDim2.new(1, 0, 0, if self.library.touch then 44 else 36)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 10, 0.5, 0)
		label.Position = UDim2.fromOffset(38, 0)
		label.Size = UDim2.new(1, if self.tier then -66 else -46, 1, 0)
		if self.tier then
			local lock = Create.icon("lock", 14, "textMuted", button)
			lock.AnchorPoint = Vector2.new(1, 0.5)
			lock.Position = UDim2.new(1, -10, 0.5, 0)
			self.lock = lock
		end
	elseif style == "Rail" then
		button.Size = UDim2.new(1, 0, 0, 44)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		label.Visible = false
	elseif style == "Top" then
		-- The icon and title are laid out in an inner frame, and the button
		-- takes its width from it, so the marker can lie over the button.
		local height = if self.library.touch then 40 else 32
		local inner = Create.new("Frame", { Name = "Inner", Size = UDim2.fromOffset(0, height), AutomaticSize = Enum.AutomaticSize.X, Parent = button })
		Create.padding(inner, 12, 0)
		Create.list(inner, "Horizontal", 6)
		icon.Parent, label.Parent = inner, inner
		label.Size = UDim2.fromScale(0, 1)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextSize = 13
		local function fit()
			button.Size = UDim2.fromOffset(inner.AbsoluteSize.X / self.library.scale, height)
		end
		scope:connect(inner:GetPropertyChangedSignal("AbsoluteSize"), fit)
		button.Size = UDim2.fromOffset(80, height)
		fit()
		self.inner = inner
	else
		button.Size = UDim2.new(0, 72, 1, 0)
		local inner = Create.new("Frame", { Name = "Inner", Size = UDim2.fromScale(1, 1), Parent = button })
		Create.list(inner, "Vertical", 3, {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})
		icon.Parent, label.Parent = inner, inner
		label.Size = UDim2.new(1, -4, 0, 14)
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Center
		self.inner = inner
	end
	if look.marker then
		self.bar = marker()
		self.bar.Parent = button
	end

	-- A count, a word or a dot beside the tab, set with Tab:SetBadge.
	local mark = self.badge
	if mark ~= nil and mark ~= false then
		local dot = mark == true or style == "Rail" or style == "Dock"
		local pill = Create.new("TextLabel", {
			Name = "Badge",
			Size = if dot then UDim2.fromOffset(8, 8) else UDim2.fromOffset(0, 16),
			AutomaticSize = if dot then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
			Text = if dot then "" else tostring(mark),
			TextSize = 10,
			Weight = "bold",
			ZIndex = 3,
			LayoutOrder = 3,
			Theme = { BackgroundColor3 = "accent", TextColor3 = "onAccent" },
			-- Beside the title in a top strip; over the button everywhere else.
			Parent = if style == "Top" then self.inner else button,
		})
		Create.corner(-1, pill)
		if not dot then
			Create.padding(pill, 5, 0)
		end
		if style == "Sidebar" then
			pill.AnchorPoint = Vector2.new(1, 0.5)
			pill.Position = UDim2.new(1, if self.tier then -30 else -10, 0.5, 0)
		elseif dot and style ~= "Top" then
			pill.AnchorPoint = Vector2.new(0.5, 0.5)
			pill.Position = UDim2.new(0.5, 10, 0, 10)
		end
	end

	self.button, self.buttonIcon, self.buttonLabel = button, icon, label
	scope:connect(button.Activated, function()
		self.window:SelectTab(self)
	end)
	scope:connect(button.MouseEnter, function()
		if self.window.selected ~= self then
			Motion.tween(button, "fast", { BackgroundTransparency = 0.5 })
		end
	end)
	scope:connect(button.MouseLeave, function()
		if self.window.selected ~= self then
			Motion.tween(button, "fast", { BackgroundTransparency = 1 })
		end
	end)
end

-- Selected shows as a fill, an accent icon and a heavier title, not colour
-- alone. A tab with no search matches is dimmed.
function Tab:paint(selected, dimmed)
	if not self.button then
		return
	end
	local textRole = if selected then "text" else "textMuted"
	Theme.bind(self.buttonIcon, "ImageColor3", if selected then "accent" else "textMuted")
	Theme.bind(self.buttonLabel, "TextColor3", textRole)
	self.buttonLabel.FontFace = Create.font(if selected then "bold" else "medium")
	self.buttonLabel.TextTransparency = if dimmed then 0.5 else 0
	self.buttonIcon.ImageTransparency = if dimmed then 0.5 else 0
	local look = self.look or {}
	if selected and look.text then
		Theme.bind(self.buttonLabel, "TextColor3", look.text)
	end
	if selected and (look.icon or look.text) then
		Theme.bind(self.buttonIcon, "ImageColor3", look.icon or (if look.text == "onAccent" then "onAccent" else "accent"))
	end
	Theme.bind(self.button, "BackgroundColor3", if selected and look.fill then look.fill else "raised")
	Motion.tween(self.button, "fast", { BackgroundTransparency = if selected and look.fill then look.fillTransparency or 0 else 1 })
	if self.bar then
		self.bar.Visible = selected
	end
	if self.glow then
		Motion.tween(self.glow, "fast", { Transparency = if selected then 0.35 else 1 })
	end
	if self.lock then
		self.lock.Visible = not self.window:allows(self.tier)
	end
end

-- A number, a short word, true for a dot, or nil to clear it.
function Tab:SetBadge(value)
	self.badge = value
	self.window:buildNav()
end

function Tab:Select()
	self.window:SelectTab(self)
end

function Tab:SetTitle(title)
	self.Title = title
	if self.buttonLabel then
		self.buttonLabel.Text = title
	end
end

-- Elements added straight to a tab go into an untitled flat section. A new
-- one starts after each titled section, so rows keep the order they were written in.
local function looseSection(tab)
	local loose = tab.loose
	if not loose or tab.last ~= loose or loose.scope.cleaned then
		loose = tab:Section({ Style = "Flat" })
		tab.loose = loose
	end
	return loose
end

for _, kind in Registry.Kinds do
	Tab[kind] = function(self, options)
		local section = looseSection(self)
		return section[kind](section, options)
	end
end

return Tab
