-- Queued toasts. A few show at once; the rest wait. Each can carry a
-- countdown bar for its duration and buttons of its own. On a phone they
-- always sit across the top, clear of the thumbs.

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")

local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")

local WIDTH, NARROW = 320, 480
local KINDS = {
	info = { icon = "info", role = "info" },
	success = { icon = "circle-check", role = "success" },
	warning = { icon = "triangle-alert", role = "warning" },
	danger = { icon = "circle-alert", role = "danger" },
}
local POSITIONS = { TopLeft = true, TopCenter = true, TopRight = true, BottomLeft = true, BottomCenter = true, BottomRight = true }

local Notifications = {
	-- What a notice uses when it does not say otherwise. Hubs change these
	-- with Halcyon:SetNotificationDefaults.
	Defaults = { Duration = 4, Position = "BottomRight", Progress = true, MaxVisible = 4 },
}

-- Accepts any of Duration, Position, Progress and MaxVisible; anything
-- else, or a value of the wrong kind, is ignored.
function Notifications.configure(kit, settings)
	if type(settings) ~= "table" then
		return
	end
	local defaults = Notifications.Defaults
	if type(settings.Duration) == "number" and settings.Duration >= 0 then
		defaults.Duration = settings.Duration
	end
	if POSITIONS[settings.Position] then
		defaults.Position = settings.Position
	end
	if type(settings.Progress) == "boolean" then
		defaults.Progress = settings.Progress
	end
	if type(settings.MaxVisible) == "number" and settings.MaxVisible >= 1 then
		defaults.MaxVisible = math.floor(settings.MaxVisible)
	end
	if kit.toasts then
		kit.toasts.place()
	end
end

local function host(kit)
	if kit.toasts then
		return kit.toasts
	end
	local overlay = Mount.overlay(kit)
	local holder = Create.new("Frame", { Name = "Holder", Parent = overlay.toasts })
	local layout = Create.list(holder, "Vertical", 8)
	local state = { holder = holder, active = {}, queue = {}, order = 0, side = 1 }
	kit.toasts = state

	function state.place()
		local narrow = overlay.gui.AbsoluteSize.X < NARROW
		local position = if narrow then "TopCenter" else Notifications.Defaults.Position
		local top = string.find(position, "Top", 1, true) ~= nil
		local x = if string.find(position, "Left", 1, true) then 0 elseif string.find(position, "Center", 1, true) then 0.5 else 1
		-- The overlay covers the whole screen, so toasts at the top start
		-- below Roblox's top bar themselves.
		local inset = GuiService:GetGuiInset().Y + 8
		state.side = x * 2 - 1
		holder.AnchorPoint = Vector2.new(x, if top then 0 else 1)
		holder.Position = UDim2.new(x, -12 * state.side, if top then 0 else 1, if top then inset else -12)
		holder.Size = if narrow then UDim2.new(1, -24, 1, -inset - 8) else UDim2.new(0, WIDTH, 1, -inset - 20)
		layout.VerticalAlignment = if top then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	end
	kit.scope:connect(overlay.gui:GetPropertyChangedSignal("AbsoluteSize"), state.place)
	kit.scope:add(function()
		kit.toasts = nil
	end)
	state.place()
	return state
end

local function show(kit, state, toast)
	local options = toast.options
	local kind = KINDS[options.Kind] or KINDS.info
	local scope = kit.scope:child()
	toast.scope = scope
	state.order += 1

	local slot = Create.new("Frame", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = state.order,
		Parent = state.holder,
	})
	scope:add(slot)
	-- The card slides in from the side of the screen it sits on.
	local card = Create.new("TextButton", {
		Name = "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(28 * state.side, 0),
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "surface" },
		Parent = slot,
	})
	Create.corner(10, card)
	Create.stroke("stroke", card)

	local body = Create.new("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	Create.padding(body, 12)
	Create.list(body, "Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Top })
	Create.icon(options.Icon or kind.icon, 18, kind.role, body)

	local text = Create.new("Frame", { Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(text, "Vertical", 2)
	Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Weight = "medium",
		Text = options.Title or "",
		Theme = { TextColor3 = "text" },
		Parent = text,
	})
	if options.Content and options.Content ~= "" then
		Create.new("TextLabel", {
			Name = "Content",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 12,
			LayoutOrder = 1,
			Text = options.Content,
			Theme = { TextColor3 = "textMuted" },
			Parent = text,
		})
	end

	-- Buttons of the notice's own: each runs its Callback and dismisses it.
	if type(options.Actions) == "table" and #options.Actions > 0 then
		local actions = Create.new("Frame", { Name = "Actions", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = text })
		Create.padding(actions, 0, 6, 0, 0)
		Create.list(actions, "Horizontal", 6, { Wraps = true })
		for index, settings in options.Actions do
			local button = Create.new("TextButton", {
				Name = "Action",
				Size = UDim2.fromOffset(0, if kit.touch then 40 else 28),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = index,
				Text = settings.Title or "",
				TextSize = 12,
				Weight = "medium",
				Theme = { BackgroundColor3 = if index == 1 then "accent" else "raised", TextColor3 = if index == 1 then "onAccent" else "text" },
				Parent = actions,
			})
			Create.corner(6, button)
			Create.padding(button, 10, 0)
			scope:connect(button.Activated, function()
				toast.Dismiss()
				Env.call(settings.Title or "Notification", settings.Callback)
			end)
		end
	end

	Motion.tween(card, "base", { Position = UDim2.fromOffset(0, 0) })
	scope:connect(card.Activated, toast.Dismiss)

	local duration = toast.duration
	if duration > 0 then
		-- The bar empties over the notice's lifetime, so the time left is visible.
		if toast.progress and not Motion.reduced then
			local bar = Create.new("Frame", {
				Name = "Countdown",
				-- Inset by the card's corner radius so the bar's ends stay inside the rounding.
				Size = UDim2.new(1, -20, 0, 2),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10, 1, -1),
				Theme = { BackgroundColor3 = kind.role },
				Parent = card,
			})
			TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
		end
		scope:add(task.delay(duration, toast.Dismiss))
	end
end

-- Options: Title, Content, Kind ("info", "success", "warning", "danger"),
-- Icon, Duration in seconds (0 stays until tapped), Progress (false hides
-- the countdown bar), Actions as a list of { Title, Callback }.
-- Returns { Dismiss }.
function Notifications.push(kit, options)
	if type(options) == "string" then
		options = { Title = options }
	end
	local defaults = Notifications.Defaults
	local state = host(kit)
	local toast = {
		options = options,
		done = false,
		duration = if type(options.Duration) == "number" then options.Duration else defaults.Duration,
		progress = if options.Progress ~= nil then options.Progress == true else defaults.Progress,
	}

	function toast.Dismiss()
		if toast.done then
			return
		end
		toast.done = true
		local queued = table.find(state.queue, toast)
		if queued then
			table.remove(state.queue, queued)
			return
		end
		table.remove(state.active, table.find(state.active, toast))
		kit.scope:release(toast.scope)
		local waiting = table.remove(state.queue, 1)
		if waiting then
			table.insert(state.active, waiting)
			show(kit, state, waiting)
		end
	end

	if #state.active < defaults.MaxVisible then
		table.insert(state.active, toast)
		show(kit, state, toast)
	else
		table.insert(state.queue, toast)
	end
	return toast
end

return Notifications
