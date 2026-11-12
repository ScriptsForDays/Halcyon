-- The layout and states every element shares: a title and description on
-- the left, a control slot on the right, a 44 px minimum height, and the
-- disabled and locked looks. An element only adds its control.

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Signal = require("../Core/Signal")

-- The narrowest the title lane may get before the controls wrap under it.
local MIN_TITLE = 96

local Row = {}

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

	local content = Create.new("Frame", { Name = "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = frame })
	Create.padding(content, 12, if layout.compact then 4 else 8)
	Create.list(content, "Vertical", 8, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if not layout.compact then
		Create.new("UISizeConstraint", { MinSize = Vector2.new(0, 44), Parent = content })
	end

	local row = {
		frame = frame,
		content = content,
		scope = scope,
		kit = container.kit,
		window = container.window,
		options = options,
		-- The fill for chips and boxes inside this row, one step off the row's own.
		controlRole = if filled then "background" else "raised",
		reach = if container.kit.touch then 40 else 28,
	}

	local title, description, slot
	if not layout.bare then
		local head = Create.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = content })
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
			local lane = (width - taken) / row.kit.scale - 12 - (if options.Icon then 30 else 0)
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
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		-- On the title line, where the control was: centred in a one-line
		-- row and clear of a track or bar under the title in a taller one.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 9),
		Theme = { BackgroundColor3 = "accent" },
		Parent = veil,
	})
	Create.corner(-1, lock)
	Create.padding(lock, 10, 0)
	Create.list(lock, "Horizontal", 6)
	local lockIcon = Create.icon("lock", 13, "onAccent", lock)
	local lockLabel = Create.new("TextLabel", {
		Name = "Reason",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = "bold",
		LayoutOrder = 1,
		Theme = { TextColor3 = "onAccent" },
		Parent = lock,
	})

	local state = { disabled = false, locked = false, reason = nil, description = options.Description }
	local handle = { Frame = frame, Title = options.Title or "", Changed = Signal.new(), Hidden = false, scope = scope }
	scope:add(handle.Changed)
	row.handle = handle

	local function refresh()
		veil.Visible = state.disabled or state.locked
		lock.Visible = state.locked and not state.quiet
		if slot then
			slot.Visible = not state.locked
		end
		veil.BackgroundTransparency = if state.locked then 0.3 else 0.45
		lockLabel.Text = state.reason or ""
		if description then
			description.Text = state.description or ""
			description.Visible = state.description ~= nil and state.description ~= ""
		end
		handle.SearchText = string.lower(handle.Title .. " " .. (state.description or ""))
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
		return state.locked or state.disabled
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
	function row.fit(apply)
		local narrow = false
		local function measure()
			local width = frame.AbsoluteSize.X / row.kit.scale
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
	function row.adapt(control, width, height, always)
		local under
		local function place(stacked)
			if stacked then
				under = under or row.below()
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
			row.fit(place)
		end
	end

	-- A full-width area under the title line, for sliders and progress bars.
	function row.below()
		return Create.new("Frame", { Name = "Below", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = content })
	end

	-- Hover marks a control only while the pointer is on `target` itself
	-- (the row, unless a control is given), never the whole row. The engine
	-- can miss a MouseLeave when the pointer moves fast, so entering one
	-- control also clears whichever one was marked before it.
	function row.onHover(paint, target)
		local kit = row.kit
		local function leave()
			if kit.hoverLeave == leave then
				kit.hoverLeave = nil
			end
			paint(false)
		end
		target = target or frame
		scope:connect(target.MouseEnter, function()
			local previous = kit.hoverLeave
			if previous and previous ~= leave then
				previous()
			end
			kit.hoverLeave = leave
			paint(true)
		end)
		scope:connect(target.MouseLeave, leave)
		scope:add(function()
			if kit.hoverLeave == leave then
				kit.hoverLeave = nil
			end
		end)
	end

	refresh()
	return row
end

return Row
