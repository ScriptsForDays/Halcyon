-- Queued toasts. A few show at once; the rest wait. Each can carry a
-- countdown bar for its duration and buttons of its own. On a phone they
-- always sit across the top, clear of the thumbs.

local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Create = require("../Core/Create")
local Icons = require("../Core/Icons")
local Env = require("../Core/Env")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

local WIDTH, NARROW = 320, 480
local KINDS = {
	info = { icon = "info", role = "info" },
	success = { icon = "circle-check", role = "success" },
	warning = { icon = "triangle-alert", role = "warning" },
	danger = { icon = "circle-alert", role = "danger" },
}
local POSITIONS = { TopLeft = true, TopCenter = true, TopRight = true, BottomLeft = true, BottomCenter = true, BottomRight = true }
-- Default: a card with a countdown bar. Timer: the seconds left in the
-- corner. Compact: one line in a pill. Banner: a coloured strip across the
-- top. Progress: a bar the hub fills, for work that takes a while.
-- Accent: a card with a coloured edge and the icon on a tinted disc.
-- Glass: a see-through card. Achievement: a large icon disc for a reward
-- or milestone. Snackbar: a dark one-line bar with its first action as a
-- word. Island: a pill at the top centre of the screen, apart from the stack.
local STYLES = {}
for _, name in { "Default", "Timer", "Compact", "Banner", "Progress", "Accent", "Glass", "Achievement", "Snackbar", "Island" } do
	STYLES[name] = true
	Styles.register("Notification", name, {})
end
-- A short chime that ships with every Roblox client, used when Sound is on.
local CHIME = "rbxasset://sounds/electronicpingshort.wav"

local Notifications = {
	-- What a notice uses when it does not say otherwise. Hubs change these
	-- with Halcyon:SetNotificationDefaults.
	Defaults = { Duration = 4, Position = "BottomRight", Progress = true, MaxVisible = 4, Style = "Default", Sound = false },
}

-- Accepts any of Duration, Position, Progress and MaxVisible; anything
-- else, or a value of the wrong kind, is ignored.
function Notifications.configure(library, settings)
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
	-- true for the built-in chime, or a sound id of the hub's own.
	if type(settings.Sound) == "boolean" or type(settings.Sound) == "string" then
		defaults.Sound = settings.Sound
	end
	if STYLES[settings.Style] then
		defaults.Style = settings.Style
	end
	if type(settings.MaxVisible) == "number" and settings.MaxVisible >= 1 then
		defaults.MaxVisible = math.floor(settings.MaxVisible)
	end
	if library.toasts then
		library.toasts.place()
	end
end

local function toastStack(library)
	if library.toasts then
		return library.toasts
	end
	local overlay = Mount.overlay(library)
	local holder = Create.new("Frame", { Name = "Holder", Parent = overlay.toasts })
	local layout = Create.list(holder, "Vertical", 8)
	-- Island notices sit at the top centre, apart from the stack.
	local island = Create.new("Frame", {
		Name = "Island",
		Size = UDim2.new(0, 360, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, GuiService:GetGuiInset().Y + 8),
		Parent = overlay.toasts,
	})
	Create.list(island, "Vertical", 6, { HorizontalAlignment = Enum.HorizontalAlignment.Center })
	local state = { holder = holder, island = island, active = {}, queue = {}, order = 0, side = 1 }
	library.toasts = state

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
		holder.Position = UDim2.new(x, -16 * state.side, if top then 0 else 1, if top then inset else -16)
		holder.Size = if narrow then UDim2.new(1, -24, 1, -inset - 8) else UDim2.new(0, WIDTH, 1, -inset - 24)
		layout.VerticalAlignment = if top then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	end
	library.scope:connect(overlay.gui:GetPropertyChangedSignal("AbsoluteSize"), state.place)
	library.scope:add(function()
		library.toasts = nil
	end)
	state.place()
	return state
end

local function show(library, state, toast)
	local options = toast.options
	local kind = KINDS[toast.kind] or KINDS.info
	local style = toast.style
	local snack, isle = style == "Snackbar", style == "Island"
	local compact = style == "Compact" or isle
	local scope = library.scope:child()
	toast.scope = scope
	state.order += 1
	local sound = if options.Sound ~= nil then options.Sound else Notifications.Defaults.Sound
	if sound then
		local chime = Create.new("Sound", { SoundId = if type(sound) == "string" then sound else CHIME, Volume = 0.35 })
		pcall(SoundService.PlayLocalSound, SoundService, chime)
		task.delay(3, function()
			chime:Destroy()
		end)
	end

	local slot = Create.new("Frame", {
		Name = "Toast",
		Size = if isle then UDim2.fromOffset(0, 0) else UDim2.new(1, 0, 0, 0),
		AutomaticSize = if isle then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
		LayoutOrder = state.order,
		Parent = if isle then state.island else state.holder,
	})
	scope:add(slot)
	-- The card slides in from the side of the screen it sits on.
	local card = Create.new("TextButton", {
		Name = "Card",
		Text = "",
		Size = if isle then UDim2.fromOffset(0, 0) else UDim2.new(1, 0, 0, 0),
		AutomaticSize = if isle then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
		Position = if isle then UDim2.fromOffset(0, -16) else UDim2.fromOffset(28 * state.side, 0),
		ClipsDescendants = true,
		BackgroundTransparency = if style == "Glass" then 0.2 else 0,
		Theme = { BackgroundColor3 = if snack or isle then "text" else "surface" },
		Parent = slot,
	})
	Create.corner(if compact or snack then -1 else 10, card)
	local edge = Create.stroke(if style == "Glass" then "text" else "stroke", card)
	if style == "Glass" then
		edge.Transparency = 0.82
	elseif snack or isle then
		edge.Transparency = 1
	end
	if isle then
		Create.new("UISizeConstraint", { MaxSize = Vector2.new(360, math.huge), Parent = card })
	end
	if style == "Accent" then
		-- Inside the card's edge, not on it, so the stroke stays one clean line.
		local stripe = Create.new("Frame", {
			Name = "Edge",
			Size = UDim2.new(0, 3, 1, -20),
			Position = UDim2.fromOffset(7, 10),
			ZIndex = 2,
			Theme = { BackgroundColor3 = kind.role },
			Parent = card,
		})
		Create.corner(-1, stripe)
		toast.stripe = stripe
	end
	if style == "Banner" then
		-- A rail across the top, inside the padding. On a timed notice it doubles
		-- as the countdown, so a banner never carries two bars.
		local strip = Create.new("Frame", {
			Name = "Strip",
			Size = UDim2.new(1, -24, 0, 3),
			Position = UDim2.fromOffset(12, 10),
			ZIndex = 2,
			Theme = { BackgroundColor3 = "raised" },
			Parent = card,
		})
		Create.corner(-1, strip)
		toast.strip = Create.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Theme = { BackgroundColor3 = kind.role },
			Parent = strip,
		})
		Create.corner(-1, toast.strip)
	end

	local body = Create.new("Frame", { Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
	local pad = if compact
		then Create.padding(body, 14, 9)
		else Create.padding(body, if style == "Accent" then 18 else 12, if style == "Banner" then 23 else 12, 12, 12)
	if isle then
		body.Size = UDim2.fromOffset(0, 0)
		body.AutomaticSize = Enum.AutomaticSize.XY
	end
	Create.list(body, "Horizontal", 10, { VerticalAlignment = if compact or snack then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top })
	if style == "Accent" or style == "Achievement" then
		-- The icon sits on a disc tinted with the notice's colour.
		local big = style == "Achievement"
		local disc = Create.new("Frame", {
			Name = "Disc",
			Size = UDim2.fromOffset(if big then 44 else 30, if big then 44 else 30),
			BackgroundTransparency = if big then 0 else 0.82,
			Theme = { BackgroundColor3 = kind.role },
			Parent = body,
		})
		Create.corner(-1, disc)
		toast.icon = Create.icon(options.Icon or (if big then "trophy" else kind.icon), if big then 22 else 16, if big then "onAccent" else kind.role, disc)
		toast.icon.AnchorPoint, toast.icon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	else
		toast.icon = Create.icon(options.Icon or kind.icon, if compact then 16 else 18, kind.role, body)
	end

	local text = Create.new("Frame", { Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(text, "Vertical", 2)
	toast.titleLabel = Create.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		Weight = "medium",
		Text = toast.title,
		TextSize = if compact or snack then 13 else (if style == "Achievement" then 15 else 14),
		TextTruncate = if compact or snack then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
		Theme = { TextColor3 = if snack or isle then "background" else "text" },
		Parent = text,
	})
	if isle then
		-- An island grows with its words instead of filling a fixed card.
		text.AutomaticSize = Enum.AutomaticSize.XY
		text.Size = UDim2.fromOffset(0, 0)
		text:FindFirstChildOfClass("UIFlexItem"):Destroy()
		toast.titleLabel.Size = UDim2.fromOffset(0, 0)
		toast.titleLabel.AutomaticSize = Enum.AutomaticSize.XY
		toast.titleLabel.TextWrapped = false
	end
	if style == "Achievement" then
		toast.titleLabel.FontFace = Create.font("bold")
	end
	if not compact and not snack and (toast.content ~= "" or style == "Progress") then
		toast.contentLabel = Create.new("TextLabel", {
			Name = "Content",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextSize = 12,
			LayoutOrder = 1,
			Text = toast.content,
			Visible = toast.content ~= "",
			Theme = { TextColor3 = "textMuted" },
			Parent = text,
		})
	end

	if style == "Progress" then
		local rail = Create.new("Frame", {
			Name = "Progress",
			Size = UDim2.new(1, 0, 0, 4),
			LayoutOrder = 3,
			Theme = { BackgroundColor3 = "raised" },
			Parent = text,
		})
		Create.corner(-1, rail)
		toast.fill = Create.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(toast.value, 1),
			Theme = { BackgroundColor3 = kind.role },
			Parent = rail,
		})
		Create.corner(-1, toast.fill)
	end

	-- A snackbar's first action is a word at its end, such as Undo.
	if snack and type(options.Actions) == "table" and options.Actions[1] then
		local settings = options.Actions[1]
		local word = Create.new("TextButton", {
			Name = "Action",
			Size = UDim2.fromOffset(0, if library.touch then 40 else 24),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = string.upper(settings.Title or "OK"),
			TextSize = 12,
			Weight = "bold",
			LayoutOrder = 3,
			Theme = { TextColor3 = "accent" },
			Parent = body,
		})
		scope:connect(word.Activated, function()
			toast.Dismiss()
			Env.call(settings.Title or "Notification", settings.Callback)
		end)
	end

	-- Buttons of the notice's own: each runs its Callback and dismisses it.
	if not compact and not snack and type(options.Actions) == "table" and #options.Actions > 0 then
		local actions = Create.new("Frame", {
			Name = "Actions",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = text,
		})
		Create.padding(actions, 0, 6, 0, 0)
		Create.list(actions, "Horizontal", 6, { Wraps = true })
		for index, settings in options.Actions do
			local button = Create.new("TextButton", {
				Name = "Action",
				Size = UDim2.fromOffset(0, if library.touch then 40 else 28),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = index,
				Text = settings.Title or "",
				TextSize = 12,
				Weight = "medium",
				Theme = {
					BackgroundColor3 = if index == 1 then "accent" else "raised",
					TextColor3 = if index == 1 then "onAccent" else "text",
				},
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

	if style == "Achievement" and not Motion.reduced then
		local grow = Create.new("UIScale", { Scale = 0.9, Parent = card })
		Motion.tween(grow, "spring", { Scale = 1 })
	end
	Motion.tween(card, "base", { Position = UDim2.fromOffset(0, 0) })
	scope:connect(card.Activated, toast.Dismiss)

	local duration = toast.duration
	if duration > 0 then
		if style == "Timer" then
			local seconds = Create.new("TextLabel", {
				Name = "Timer",
				Size = UDim2.fromOffset(0, 18),
				AutomaticSize = Enum.AutomaticSize.X,
				TextSize = 12,
				Weight = "bold",
				LayoutOrder = 2,
				Theme = { TextColor3 = "textMuted" },
				Parent = body,
			})
			-- Counts on the same scheduler as the dismiss timer, so the two agree.
			local left = math.ceil(duration)
			scope:add(task.spawn(function()
				while left > 0 do
					seconds.Text = `{left}s`
					task.wait(1)
					left -= 1
				end
			end))
		end
		-- The bar empties over the notice's lifetime, so the time left is visible.
		if toast.progress and style == "Banner" and not Motion.reduced then
			TweenService:Create(toast.strip, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
		elseif toast.progress and style ~= "Timer" and style ~= "Progress" and not compact and not snack and not Motion.reduced then
			-- A rounded rail inside the card's padding, so it never touches the edge or the stroke.
			pad.PaddingBottom = UDim.new(0, 20)
			if toast.stripe then
				-- Stop the side stripe above the rail instead of crossing it.
				toast.stripe.Size = UDim2.new(0, 3, 1, -32)
			end
			local track = Create.new("Frame", {
				Name = "Countdown",
				Size = UDim2.new(1, -24, 0, 3),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -9),
				BackgroundTransparency = if snack or isle then 0.85 else 0,
				Theme = { BackgroundColor3 = "raised" },
				Parent = card,
			})
			Create.corner(-1, track)
			local bar = Create.new("Frame", {
				Name = "Fill",
				Size = UDim2.fromScale(1, 1),
				Theme = { BackgroundColor3 = kind.role },
				Parent = track,
			})
			Create.corner(-1, bar)
			TweenService:Create(bar, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
		end
		scope:add(task.delay(duration, toast.Dismiss))
	end
end

-- Options: Title, Content, Kind ("info", "success", "warning", "danger"),
-- Style ("Default", "Timer", "Compact", "Banner", "Progress", "Accent",
-- "Glass", "Achievement", "Snackbar", "Island"), Sound (true or a sound id),
-- Icon, Duration in seconds (0 stays until tapped), Progress (false hides
-- the countdown bar), Actions as a list of { Title, Callback }.
-- Returns a handle with Dismiss, SetTitle, SetContent, SetProgress and Done.
function Notifications.push(library, options)
	if type(options) == "string" then
		options = { Title = options }
	end
	local defaults = Notifications.Defaults
	local state = toastStack(library)
	local style = if STYLES[options.Style] then options.Style else defaults.Style
	local toast = {
		options = options,
		done = false,
		style = style,
		kind = options.Kind,
		title = options.Title or "",
		content = options.Content or "",
		value = 0,
		-- A Progress notice stays until the hub calls Done.
		duration = if type(options.Duration) == "number" then options.Duration elseif style == "Progress" then 0 else defaults.Duration,
		progress = if options.Progress ~= nil then options.Progress == true else defaults.Progress,
	}

	-- For Progress notices: a fraction from 0 to 1.
	function toast.SetProgress(value)
		toast.value = math.clamp(tonumber(value) or 0, 0, 1)
		if toast.fill then
			Motion.tween(toast.fill, "base", { Size = UDim2.fromScale(toast.value, 1) })
		end
	end

	function toast.SetTitle(title)
		toast.title = tostring(title)
		if toast.titleLabel then
			toast.titleLabel.Text = toast.title
		end
	end

	function toast.SetContent(content)
		toast.content = tostring(content or "")
		if toast.contentLabel then
			toast.contentLabel.Text = toast.content
			toast.contentLabel.Visible = toast.content ~= ""
		end
	end

	-- Marks the work finished: fills the bar, shows `title` and leaves after
	-- a moment. `kind` defaults to "success".
	function toast.Done(title, kind)
		if toast.done then
			return
		end
		toast.SetProgress(1)
		if title then
			toast.SetTitle(title)
		end
		local finished = KINDS[kind or "success"] or KINDS.success
		toast.kind = kind or "success"
		if toast.icon then
			Icons.apply(toast.icon, finished.icon)
			Theme.bind(toast.icon, "ImageColor3", finished.role)
		end
		if toast.fill then
			Theme.bind(toast.fill, "BackgroundColor3", finished.role)
		end
		if toast.scope then
			toast.scope:add(task.delay(2.5, toast.Dismiss))
		else
			toast.duration = 2.5
		end
	end

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
		library.scope:release(toast.scope)
		local waiting = table.remove(state.queue, 1)
		if waiting then
			table.insert(state.active, waiting)
			show(library, state, waiting)
		end
	end

	if #state.active < defaults.MaxVisible then
		table.insert(state.active, toast)
		show(library, state, toast)
	else
		table.insert(state.queue, toast)
	end
	return toast
end

return Notifications
