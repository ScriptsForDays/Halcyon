-- The layout and states every element shares: a title and description on
-- the left, a control slot on the right, a 44 px minimum height, and the
-- disabled and locked looks. An element only adds its control.

local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Icons = require("../Core/Icons")
local Popup = require("../Components/Popup")
local Signal = require("../Core/Signal")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")
local Tokens = require("../Core/Tokens")

-- The narrowest the title lane may get before the controls wrap under it.
local MIN_TITLE = 96
-- How much more room a narrowed lock badge needs before it widens again.
local LOCK_GIVE = 12
-- A callback still running after this long counts as busy.
local BUSY_AFTER = 0.15

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
		Theme = { BackgroundColor3 = container.rowRole or "raised" },
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
	local padding = Create.padding(content, 12, if layout.compact then 4 else Tokens.density.rowPadding)
	Create.list(content, "Vertical", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if not layout.compact then
		-- Tagged so a later Spacing setting can retune the row.
		padding:SetAttribute("HalcyonDensity", "padding")
		local minimum = Create.new("UISizeConstraint", { MinSize = Vector2.new(0, Tokens.rowHeight()), Parent = content })
		minimum:SetAttribute("HalcyonDensity", "height")
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

	-- The veil dims the row and takes its input while it is disabled or
	-- locked, and a locked row wears an accent badge on it where its control
	-- was. Both are built the first time a row needs them: most rows never
	-- do, and making them for every row up front was a fifth of a large
	-- hub's instances, all laid out while the window opened.
	local veil, lock, badge, badgePadding, badgeLayout, lockIcon, lockLabel, shimmer, headRoom
	local refresh
	-- True while a locked row is too narrow for the badge's wording.
	local narrowLock = false
	-- The wording's width, kept from when it last showed: a hidden label
	-- can report no width, which would flip the row back to wide.
	local labelWidth = 0
	-- While locked, the title keeps clear of the badge instead of running
	-- under it. In a narrow row the badge shrinks to its icon and the reason
	-- moves into the description line, so the title is not squeezed.
	local function makeRoom()
		if not headRoom or not lock then
			return
		end
		local scale = row.library.scale
		if lockLabel.Visible and lockLabel.TextBounds.X > 0 then
			labelWidth = lockLabel.TextBounds.X
		end
		local spare = (frame.AbsoluteSize.X / scale) - (labelWidth + 13 + 6 + 20) - 24
		-- A little give at the line, so a row right at the limit settles
		-- instead of switching back and forth.
		local narrow = lock.Visible and spare < (if narrowLock then MIN_TITLE + LOCK_GIVE else MIN_TITLE)
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

	local function buildVeil()
		if veil then
			return
		end
		veil = Create.new("TextButton", {
			Name = "Veil",
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Visible = false,
			BackgroundTransparency = 0.45,
			Theme = { BackgroundColor3 = if filled then container.rowRole or "raised" else container.surface },
			Parent = frame,
		})
		Create.corner(8, veil)
		lock = Create.new("Frame", {
			Name = "Lock",
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0, 22),
			Visible = false,
			Theme = { BackgroundColor3 = "accent" },
			Parent = veil,
		})
		Create.corner(-1, lock)
		-- The badge's contents sit in their own frame so the shimmer layer is
		-- not laid out as one of them.
		badge = Create.new("Frame", { Name = "Badge", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = lock })
		badgePadding = Create.padding(badge, 10, 0)
		badgeLayout = Create.list(badge, "Horizontal", 6)
		lockIcon = Create.icon("lock", 13, "onAccent", badge)
		lockLabel = Create.new("TextLabel", {
			Name = "Reason",
			Text = "",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 12,
			Weight = "bold",
			LayoutOrder = 1,
			Theme = { TextColor3 = "onAccent" },
			Parent = badge,
		})
		shimmer = Effects.shimmer(scope, lock, -1)
		headRoom = if head then Create.new("UIPadding", { Parent = head }) else nil
		scope:connect(lock:GetPropertyChangedSignal("AbsoluteSize"), makeRoom)
		scope:connect(frame:GetPropertyChangedSignal("AbsoluteSize"), makeRoom)
		-- Centred on the title and description, where the control was; a
		-- track or bar under the title stays clear of it.
		if head then
			local function align()
				lock.Position = UDim2.new(1, -12, 0, (head.AbsolutePosition.Y - frame.AbsolutePosition.Y + head.AbsoluteSize.Y / 2) / row.library.scale)
			end
			scope:connect(head:GetPropertyChangedSignal("AbsoluteSize"), align)
			scope:connect(head:GetPropertyChangedSignal("AbsolutePosition"), align)
			align()
		end
	end

	local state = { disabled = false, locked = false, reason = nil, description = options.Description }
	local handle = { Frame = frame, Title = options.Title or "", Changed = Signal.new(), Hidden = false, scope = scope }
	scope:add(handle.Changed)
	row.handle = handle
	-- Kept so the registry can attach a tooltip to the row after it is built.
	handle.row = row

	function refresh()
		local covered = state.disabled or state.locked or state.blocked == true
		if covered then
			buildVeil()
		end
		if veil then
			veil.Visible = covered
			lock.Visible = state.locked and not state.quiet
			makeRoom()
			-- One veil for both: light enough that a locked feature's name stays readable.
			veil.BackgroundTransparency = 0.45
			if lock.Visible and row.window.lockShimmer then
				shimmer.start()
			else
				shimmer.stop()
			end
			lockLabel.Text = state.reason or ""
		end
		if slot then
			slot.Visible = not state.locked
		end
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
	-- While a search matches this row: the matched words get a marker, and
	-- a thin accent edge and tint pick the row out of its section. Sizes
	-- here are pure scale, since the row sizes itself to its children.
	local searchEdge, searchTint
	local function markRow(matched)
		if matched and not searchEdge then
			searchTint = Create.new("Frame", {
				Name = "SearchTint",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 0.93,
				ZIndex = 0,
				Theme = { BackgroundColor3 = "accent" },
				Parent = frame,
			})
			Create.corner(8, searchTint)
			searchEdge = Create.new("Frame", {
				Name = "SearchEdge",
				Size = UDim2.new(0, 3, 0.56, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 2, 0.5, 0),
				Theme = { BackgroundColor3 = "accent" },
				Parent = frame,
			})
			Create.corner(-1, searchEdge)
		end
		if searchEdge then
			searchEdge.Visible = matched
			searchTint.Visible = matched
		end
	end

	function handle:Highlight(query)
		local searching = query ~= nil and query ~= ""
		markRow(searching)
		if not title then
			return
		end
		local plain = self.Title
		local from, to = nil, nil
		if searching then
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
			.. `<mark color="#{Theme.color("accent"):ToHex()}" transparency="0.72"><b>`
			.. escape(string.sub(plain, from, to))
			.. "</b></mark>"
			.. escape(string.sub(plain, to + 1))
	end

	-- `reason` is the wording on the badge and `icon` replaces its lock.
	-- A `quiet` lock shows no badge: the section's overlay speaks for the row.
	function handle:Lock(reason, icon, quiet)
		state.locked, state.reason, state.quiet = true, reason or Strings.get("Locked"), quiet == true
		buildVeil()
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

	-- A failed callback's message, under the title until a later run works.
	local errorLine
	local function showError(message)
		if message == nil or row.window.showErrors == false then
			if errorLine then
				errorLine.Visible = false
			end
			return
		end
		if not errorLine then
			errorLine = Create.new("TextLabel", {
				Name = "CallbackError",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 9,
				Theme = { TextColor3 = "danger" },
				Parent = content,
			})
		end
		errorLine.Text = message
		errorLine.Visible = true
	end

	-- Runs one of the row's callbacks on its own thread, so a callback that
	-- yields never holds up the UI. A failure is printed, kept in the
	-- window's Errors list and shown on the row. `row.busy(on)`, when the
	-- element sets it, hears about a callback still running after a moment.
	-- `after(ok)` runs once it has finished.
	function row.run(callback, after, ...)
		if type(callback) ~= "function" then
			if after then
				after(true)
			end
			return
		end
		local finished, showedBusy = false, false
		if row.busy then
			task.delay(BUSY_AFTER, function()
				if not finished and not scope.cleaned then
					showedBusy = true
					row.busy(true)
				end
			end)
		end
		task.spawn(function(...)
			local trace
			local ok, message = xpcall(callback, function(problem)
				trace = debug.traceback(tostring(problem), 2)
				return problem
			end, ...)
			finished = true
			if scope.cleaned then
				return
			end
			if showedBusy then
				row.busy(false)
			end
			if ok then
				showError(nil)
			else
				local text = tostring(message)
				warn(`[Halcyon] {handle.Title} callback failed: {text}`)
				-- The player sees the reason without the script path in front of it.
				showError((string.gsub(text, "^.-:%d+: ", "")))
				row.window:recordError(handle.Title, text, trace)
			end
			if after then
				after(ok)
			end
		end, ...)
	end

	-- Fires Changed and runs the element's Callback with the same values.
	-- During SetSilent only Changed fires.
	function row.fire(...)
		handle.Changed:Fire(...)
		if not row.silent then
			row.run(options.Callback, nil, ...)
		end
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
