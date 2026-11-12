-- The layout and states every element shares: a title and description on
-- the left, a control slot on the right, a 44 px minimum height, and the
-- disabled and locked looks. An element only adds its control.

local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Popup = require("../Components/Popup")
local Signal = require("../Core/Signal")
local Theme = require("../Core/Theme")
local Tokens = require("../Core/Tokens")

-- The narrowest the title lane may get before the controls wrap under it.
local MIN_TITLE = 96

local Row = {}

-- Named badges and the theme roles they are drawn in.
local BADGES = { New = "accent", Beta = "info", Risky = "danger", Paid = "warning" }

-- `badge` is a name from BADGES, any other text, or { Text, Color }.
function Row.badge(parent, badge)
	local text, role, color
	if type(badge) == "table" then
		text, color = tostring(badge.Text or ""), badge.Color
	else
		text = tostring(badge)
		role = BADGES[text] or "accent"
	end
	local pill = Create.new("TextLabel", {
		Name = "Badge",
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = string.upper(text),
		TextSize = 10,
		Weight = "bold",
		LayoutOrder = 2,
		BackgroundTransparency = 0.82,
		Parent = parent,
	})
	Create.corner(4, pill)
	Create.padding(pill, 5, 0)
	if typeof(color) == "Color3" then
		pill.BackgroundColor3, pill.TextColor3 = color, color
	else
		Theme.bind(pill, "BackgroundColor3", role or "accent")
		Theme.bind(pill, "TextColor3", role or "accent")
	end
	return pill
end

-- An info icon. Hovering shows the explanation in a popup; on touch, a tap
-- opens and closes it.
function Row.info(row, parent, explanation)
	local button = Create.new("ImageButton", { Name = "Info", Size = UDim2.fromOffset(18, 18), LayoutOrder = 3, Parent = parent })
	local glyph = Create.icon("info", 14, "textMuted", button)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	local open = false
	local function show(wanted)
		local library = row.library
		local current = library.popup
		local showing = current ~= nil and current.anchor == button
		if wanted == showing then
			return
		end
		local popup = Popup.toggle(library, button, { Width = 240 })
		open = popup ~= nil
		if popup then
			Create.new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 13,
				Text = tostring(explanation),
				Theme = { TextColor3 = "text" },
				Parent = popup.frame,
			})
		end
	end
	row.scope:connect(button.MouseEnter, function()
		Theme.bind(glyph, "ImageColor3", "text")
		show(true)
	end)
	row.scope:connect(button.MouseLeave, function()
		Theme.bind(glyph, "ImageColor3", "textMuted")
		show(false)
	end)
	row.scope:connect(button.Activated, function()
		show(not open)
	end)
	return button
end

-- Options: button (the whole row is one press target), bare (no title or
-- slot; the element fills the row itself), compact (no minimum height).
function Row.new(container, options, layout)
	layout = layout or {}
	local scope = container.scope:child()
	local filled = container.rowFill == true

	local frame = Create.new(if layout.button then "TextButton" else "Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = container:nextOrder(),
		BackgroundTransparency = if filled and not layout.bare then 0 else 1,
		Theme = { BackgroundColor3 = "raised" },
		Parent = container.frame,
	})
	Create.corner(8, frame)
	scope:add(frame)

	local content = Create.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	Create.padding(content, 12, if layout.compact then 4 else Tokens.density.rowPadding)
	Create.list(content, "Vertical", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if not layout.compact then
		Create.new("UISizeConstraint", { MinSize = Vector2.new(0, Tokens.rowHeight()), Parent = content })
	end

	local row = {
		frame = frame,
		content = content,
		scope = scope,
		library = container.library,
		window = container.window,
		options = options,
		-- The fill for chips and boxes inside this row, one step off the row's own.
		controlRole = if filled then "background" else "raised",
		reach = if container.library.touch then 40 else 28,
	}

	local title, description, slot, head
	if not layout.bare then
		head = Create.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
		Create.list(head, "Horizontal", 12)
		if options.Icon then
			Create.icon(options.Icon, 18, "textMuted", head)
		end

		local text = Create.new("Frame", { Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = head }, {
			Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		Create.list(text, "Vertical", 2)
		title = Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			Weight = "medium",
			Text = options.Title or "",
			Theme = { TextColor3 = "text" },
			Parent = text,
		})
		row.titleBlock = text
		description = Create.new("TextLabel", {
			Name = "Description",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 12,
			LayoutOrder = 1,
			Theme = { TextColor3 = "textMuted" },
			Parent = text,
		})

		slot = Create.new("Frame", { Name = "Slot", AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, Parent = head })
		local slotLayout = Create.list(slot, "Horizontal", 8, { HorizontalAlignment = Enum.HorizontalAlignment.Right })
		row.slot, row.title = slot, title

		-- The title keeps a readable lane. When the controls would leave it
		-- less than that, they drop to their own line under the title, so a
		-- word is never broken letter by letter in a narrow column.
		local wrapped = false
		local function arrange()
			local width, taken = head.AbsoluteSize.X, slot.AbsoluteSize.X
			local lane = (width - taken) / row.library.scale - 12 - (if options.Icon then 30 else 0)
			local wrap = width > 0 and taken > 0 and lane < MIN_TITLE
			if wrap ~= wrapped then
				wrapped = wrap
				slotLayout.HorizontalAlignment = if wrap then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right
				slot.LayoutOrder = if wrap then 1 else 2
				slot.Parent = if wrap then content else head
			end
		end
		scope:connect(head:GetPropertyChangedSignal("AbsoluteSize"), arrange)
		scope:connect(slot:GetPropertyChangedSignal("AbsoluteSize"), arrange)
	end

	-- The veil dims the row and takes its input while it is disabled or locked.
	local veil = Create.new("TextButton", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Visible = false,
		BackgroundTransparency = 0.45,
		Theme = { BackgroundColor3 = if filled then "raised" else container.surface },
		Parent = frame,
	})
	Create.corner(8, veil)
	-- A locked row wears an accent badge where its control was: an icon and
	-- the hub's own wording, so the row reads as an upgrade and not as broken.
	local lock = Create.new("Frame", {
		Name = "Lock",
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0, 22),
		Theme = { BackgroundColor3 = "accent" },
		Parent = veil,
	})
	Create.corner(-1, lock)
	-- The badge's contents sit in their own frame so the shimmer layer is
	-- not laid out as one of them.
	local badge = Create.new("Frame", { Name = "Badge", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = lock })
	local badgePadding = Create.padding(badge, 10, 0)
	local badgeLayout = Create.list(badge, "Horizontal", 6)
	local lockIcon = Create.icon("lock", 13, "onAccent", badge)
	local lockLabel = Create.new("TextLabel", {
		Name = "Reason",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = "bold",
		LayoutOrder = 1,
		Theme = { TextColor3 = "onAccent" },
		Parent = badge,
	})
	local shimmer = Effects.shimmer(scope, lock, -1)
	-- While locked, the title keeps clear of the badge instead of running
	-- under it. In a narrow row the badge shrinks to its icon and the reason
	-- moves into the description line, so the title is not squeezed.
	local refresh
	-- True while a locked row is too narrow for the badge's wording.
	local narrowLock = false
	local headRoom = if head then Create.new("UIPadding", { Parent = head }) else nil
	local function makeRoom()
		if not headRoom then
			return
		end
		local scale = row.library.scale
		local full = lockLabel.TextBounds.X + 13 + 6 + 20
		local narrow = lock.Visible and (frame.AbsoluteSize.X / scale) - full - 24 < MIN_TITLE
		if narrow ~= narrowLock then
			narrowLock = narrow
			lockLabel.Visible = not narrow
			-- The narrow badge is a round chip just big enough for its icon.
			lock.AutomaticSize = if narrow then Enum.AutomaticSize.None else Enum.AutomaticSize.X
			lock.Size = UDim2.fromOffset(if narrow then 24 else 0, 24)
			badge.AutomaticSize = lock.AutomaticSize
			badge.Size = if narrow then UDim2.fromScale(1, 1) else UDim2.fromScale(0, 1)
			badgeLayout.HorizontalAlignment = if narrow then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
			badgePadding.PaddingLeft = UDim.new(0, if narrow then 0 else 10)
			badgePadding.PaddingRight = badgePadding.PaddingLeft
			refresh()
			return
		end
		headRoom.PaddingRight = UDim.new(0, if lock.Visible then lock.AbsoluteSize.X / scale + 12 else 0)
	end
	scope:connect(lock:GetPropertyChangedSignal("AbsoluteSize"), makeRoom)
	scope:connect(frame:GetPropertyChangedSignal("AbsoluteSize"), makeRoom)
	-- Centred on the title and description, where the control was; a track or
	-- bar under the title stays clear of it.
	if head then
		local function align()
			lock.Position = UDim2.new(1, -12, 0, (head.AbsolutePosition.Y - frame.AbsolutePosition.Y + head.AbsoluteSize.Y / 2) / row.library.scale)
		end
		scope:connect(head:GetPropertyChangedSignal("AbsoluteSize"), align)
		scope:connect(head:GetPropertyChangedSignal("AbsolutePosition"), align)
		align()
	end

	local state = { disabled = false, locked = false, reason = nil, description = options.Description }
	local handle = { Frame = frame, Title = options.Title or "", Changed = Signal.new(), Hidden = false, scope = scope }
	scope:add(handle.Changed)
	row.handle = handle

	function refresh()
		veil.Visible = state.disabled or state.locked or state.blocked
		lock.Visible = state.locked and not state.quiet
		makeRoom()
		if slot then
			slot.Visible = not state.locked
		end
		-- One veil for both: light enough that a locked feature's name stays readable.
		veil.BackgroundTransparency = 0.45
		if lock.Visible and row.window.lockShimmer then
			shimmer.start()
		else
			shimmer.stop()
		end
		lockLabel.Text = state.reason or ""
		if description then
			-- A narrow locked row says why in the description instead of the badge.
			local shown = if state.locked and narrowLock then state.reason else state.description
			description.Text = shown or ""
			description.Visible = shown ~= nil and shown ~= ""
			Theme.bind(description, "TextColor3", if state.locked and narrowLock then "accent" else "textMuted")
		end
		-- SearchExtra holds words an element shows besides its title, such as
		-- a status or an accordion's text.
		handle.SearchText = string.lower(handle.Title .. " " .. (state.description or "") .. " " .. (handle.SearchExtra or ""))
	end

	function handle:SetTitle(text)
		self.Title = text
		if title then
			title.Text = text
		end
		refresh()
	end

	function handle:SetDescription(text)
		state.description = text
		refresh()
	end

	function handle:SetDisabled(disabled)
		state.disabled = disabled == true
		refresh()
	end

	-- Greys the row for its section's switch or the window's SetEnabled,
	-- apart from the hub's own SetDisabled, so turning one back on never
	-- re-enables a row the hub turned off.
	function handle:SetBlocked(blocked)
		state.blocked = blocked == true
		refresh()
	end

	-- Marks where `query` appears in the title while a search is typed.
	function handle:Highlight(query)
		if not title then
			return
		end
		local plain = self.Title
		local from, to = nil, nil
		if query and query ~= "" then
			from, to = string.find(string.lower(plain), query, 1, true)
		end
		if not from then
			title.RichText = false
			title.Text = plain
			return
		end
		local function escape(text)
			return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
		end
		title.RichText = true
		title.Text = escape(string.sub(plain, 1, from - 1))
			.. `<font color="#{Theme.color("accent"):ToHex()}">`
			.. escape(string.sub(plain, from, to))
			.. "</font>"
			.. escape(string.sub(plain, to + 1))
	end

	-- `reason` is the wording on the badge and `icon` replaces its lock.
	-- A `quiet` lock shows no badge: the section's overlay speaks for the row.
	function handle:Lock(reason, icon, quiet)
		state.locked, state.reason, state.quiet = true, reason or "Locked", quiet == true
		Icons.apply(lockIcon, icon or "lock")
		refresh()
	end

	function handle:Unlock()
		state.locked = false
		refresh()
	end

	function handle:IsLocked()
		return state.locked or state.disabled or state.blocked == true
	end

	function handle:SetVisible(visible)
		self.Hidden = not visible
		frame.Visible = visible
		row.window:applySearch()
	end

	function handle:Destroy()
		container.scope:release(scope)
	end

	-- Fires Changed and runs the element's Callback with the same values.
	function row.fire(...)
		handle.Changed:Fire(...)
		Env.call(handle.Title, options.Callback, ...)
	end

	-- Calls `apply(narrow)` whenever the row crosses the width below which a
	-- wide control would squeeze the title, as in a two-column page or on a
	-- phone. The element shrinks or stacks its control in answer.
	function row.onNarrow(apply)
		local narrow = false
		local function measure()
			local width = frame.AbsoluteSize.X / row.library.scale
			local now = width > 0 and width < 300
			if now ~= narrow then
				narrow = now
				apply(narrow)
			end
		end
		scope:connect(frame:GetPropertyChangedSignal("AbsoluteSize"), measure)
		measure()
	end

	-- Puts a wide control beside the title, or across the full width under
	-- it when the row is narrow or `always` is set.
	function row.placeControl(control, width, height, always)
		local under
		local function place(stacked)
			if stacked then
				under = under or row.belowTitle()
				under.Visible = true
				control.Size = UDim2.new(1, 0, 0, height)
				control.Parent = under
			else
				if under then
					under.Visible = false
				end
				control.Size = UDim2.fromOffset(width, height)
				control.Parent = slot
			end
		end
		place(always == true)
		if not always then
			row.onNarrow(place)
		end
	end

	-- A full-width area under the title line, for sliders and progress bars.
	function row.belowTitle()
		return Create.new("Frame", {
			Name = "Below",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = content,
		})
	end

	-- A tag beside the title (Badge) and an info icon that opens a longer
	-- explanation (Info). The title moves into a line with them and
	-- truncates rather than wrap, so the marks stay beside it.
	function row.marks(text, title)
		local line = Create.new("Frame", { Name = "TitleLine", Size = UDim2.new(1, 0, 0, 18), Parent = text })
		Create.list(line, "Horizontal", 6)
		title.Parent = line
		title.Size = UDim2.fromScale(0, 1)
		title.AutomaticSize = Enum.AutomaticSize.X
		title.TextWrapped = false
		title.TextTruncate = Enum.TextTruncate.AtEnd
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Shrink, Parent = title })
		if options.Badge then
			Row.badge(line, options.Badge)
		end
		if options.Info then
			Row.info(row, line, options.Info)
		end
	end
	if title and (options.Badge or options.Info) then
		row.marks(row.titleBlock, title)
	end

	-- Hover marks a control only while the pointer is on `target` itself
	-- (the row, unless a control is given), never the whole row. The engine
	-- can miss a MouseLeave when the pointer moves fast, so entering one
	-- control also clears whichever one was marked before it.
	function row.onHover(paint, target)
		local library = row.library
		local function leave()
			if library.clearHover == leave then
				library.clearHover = nil
			end
			paint(false)
		end
		target = target or frame
		scope:connect(target.MouseEnter, function()
			local previous = library.clearHover
			if previous and previous ~= leave then
				previous()
			end
			library.clearHover = leave
			paint(true)
		end)
		scope:connect(target.MouseLeave, leave)
		scope:add(function()
			if library.clearHover == leave then
				library.clearHover = nil
			end
		end)
	end

	refresh()
	return row
end

return Row
