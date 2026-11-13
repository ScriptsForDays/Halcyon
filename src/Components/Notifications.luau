-- Queued toasts. A few show at once; the rest wait behind a "+N more" pill.
-- Every card has the same parts: a kind icon, the title, optional content
-- and buttons, a close button and a countdown rail. Hovering a card pauses
-- its countdown and dragging it sideways dismisses it. On a phone the stack
-- always sits across the top, clear of the thumbs. Each notice is also kept
-- in a short history that the notice centre (NotificationCenter = true)
-- lists.

local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")

local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Signal = require("../Core/Signal")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

local WIDTH, NARROW = 320, 480
local RADIUS = 12
-- The width of the Accent notice's coloured edge.
local EDGE = 5
-- How far a card has to be dragged sideways for letting go to dismiss it.
local SWIPE = 70
-- How many past notices the notice centre keeps.
local HISTORY = 50
local KINDS = {
	info = { icon = "info", role = "info" },
	success = { icon = "circle-check", role = "success" },
	warning = { icon = "triangle-alert", role = "warning" },
	danger = { icon = "circle-alert", role = "danger" },
}
local POSITIONS = { TopLeft = true, TopCenter = true, TopRight = true, BottomLeft = true, BottomCenter = true, BottomRight = true }
-- Island and Snackbar sit on the same dark fill in every theme, the way a
-- phone's own system notices do.
local DARK = {
	fill = Color3.fromRGB(17, 18, 22),
	text = Color3.fromRGB(244, 245, 247),
	muted = Color3.fromRGB(150, 155, 166),
}

-- The looks (kind "Notification"):
--   Default      a card: icon on a tinted square, title, content, countdown
--   Accent       the notice's colour as one edge down the whole left side
--   Banner       a tinted band across the top with the title; the countdown
--                runs along the band's lower edge
--   Glass        a see-through card with a soft light across the top
--   Timer        the seconds left in a small pill instead of a bar
--   Progress     a bar the hub fills, for work that takes a while
--   Achievement  a large icon disc for a reward or a milestone
--   Compact      one line in a pill
--   Snackbar     a dark one-line bar with its first action as a word
--   Island       a dark capsule at the top centre, apart from the stack
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

-- Accepts any of Duration, Position, Progress, Sound, Style and MaxVisible;
-- anything else, or a value of the wrong kind, is ignored.
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

-- The notices shown so far, newest first, and how many the player hasn't
-- opened the notice centre to see. Added fires with each new entry.
function Notifications.history(library)
	if not library.notices then
		local log = { entries = {}, unread = 0, Added = Signal.new() }
		library.scope:add(log.Added)
		library.notices = log
	end
	return library.notices
end

local function remember(library, toast)
	local log = Notifications.history(library)
	local entry = { title = toast.title, content = toast.content, kind = toast.kind or "info", at = os.time() }
	table.insert(log.entries, 1, entry)
	if #log.entries > HISTORY then
		table.remove(log.entries)
	end
	log.unread += 1
	log.Added:Fire(entry)
end

local function centred(instance)
	instance.AnchorPoint = Vector2.new(0.5, 0.5)
	instance.Position = UDim2.fromScale(0.5, 0.5)
	return instance
end

local function toastStack(library)
	if library.toasts then
		return library.toasts
	end
	local overlay = Mount.overlay(library)
	local holder = Create.new("Frame", { Name = "Holder", Parent = overlay.toasts })
	local layout = Create.list(holder, "Vertical", 8)
	-- How many more notices wait for a free place in the stack.
	local more = Create.new("TextLabel", {
		Name = "More",
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = "medium",
		Visible = false,
		Theme = { BackgroundColor3 = "raised", TextColor3 = "textMuted" },
		Parent = holder,
	})
	Create.corner(-1, more)
	Create.padding(more, 10, 0)
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
	local state = { holder = holder, island = island, more = more, active = {}, queue = {}, order = 0, side = 1 }
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
		layout.HorizontalAlignment = if x == 0 then Enum.HorizontalAlignment.Left elseif x == 1 then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Center
		-- The waiting count sits at the far end of the stack from the edge.
		more.LayoutOrder = if top then 1e9 else 0
	end

	function state.count()
		local waiting = #state.queue
		more.Visible = waiting > 0
		more.Text = `+{waiting} more`
	end
	library.scope:connect(overlay.gui:GetPropertyChangedSignal("AbsoluteSize"), state.place)
	library.scope:add(function()
		library.toasts = nil
	end)
	state.place()
	return state
end

local function chime(options)
	local sound = if options.Sound ~= nil then options.Sound else Notifications.Defaults.Sound
	if not sound then
		return
	end
	local played = Create.new("Sound", { SoundId = if type(sound) == "string" then sound else CHIME, Volume = 0.35 })
	pcall(SoundService.PlayLocalSound, SoundService, played)
	task.delay(3, function()
		played:Destroy()
	end)
end

-- An opaque mix of the card's colour and a role, kept right as themes change.
local function tinted(scope, frames, role, amount)
	for _, frame in frames do
		frame.BackgroundTransparency = 0
	end
	local function paint()
		local colour = Theme.color("surface"):Lerp(Theme.color(role), amount)
		for _, frame in frames do
			frame.BackgroundColor3 = colour
		end
	end
	paint()
	scope:connect(Theme.Changed, paint)
end

-- The leading icon: a tinted square on cards, a disc for Achievement, and a
-- plain icon on the one-line looks, Accent and Banner.
local function buildLead(toast, kind, parent)
	local options, style = toast.options, toast.style
	if style == "Achievement" then
		local disc = Create.new("Frame", { Name = "Disc", Size = UDim2.fromOffset(44, 44), Theme = { BackgroundColor3 = kind.role }, Parent = parent })
		Create.corner(-1, disc)
		toast.tile, toast.tileRole = disc, "fill"
		toast.icon = centred(Create.icon(options.Icon or "trophy", 22, "onAccent", disc))
		return
	end
	if style == "Snackbar" and not options.Icon then
		return
	end
	local plain = style == "Compact" or style == "Island" or style == "Snackbar" or style == "Accent" or style == "Banner"
	if plain then
		toast.icon = Create.icon(options.Icon or kind.icon, if style == "Accent" then 18 else 16, kind.role, parent)
		return
	end
	local tile = Create.new("Frame", {
		Name = "Tile",
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 0.86,
		Theme = { BackgroundColor3 = kind.role },
		Parent = parent,
	})
	Create.corner(8, tile)
	toast.tile, toast.tileRole = tile, "tint"
	toast.icon = centred(Create.icon(options.Icon or kind.icon, 16, kind.role, tile))
end

-- Title, content, buttons and (for Progress) the bar the hub fills.
local function buildText(library, toast, kind, parent, detail)
	local options, style = toast.options, toast.style
	local isle, snack = style == "Island", style == "Snackbar"
	local line = isle or snack or style == "Compact"
	local dark = isle or snack
	local scope = toast.scope

	local text = Create.new("Frame", { Name = "Text", AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = parent }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	Create.list(text, "Vertical", 2)
	if isle then
		-- An island grows with its words instead of filling a fixed card.
		text:FindFirstChildOfClass("UIFlexItem"):Destroy()
		text.Size = UDim2.fromOffset(0, 0)
		text.AutomaticSize = Enum.AutomaticSize.XY
	end
	toast.titleLabel = Create.new("TextLabel", {
		Name = "Title",
		Size = if isle then UDim2.fromOffset(0, 0) else UDim2.new(1, 0, 0, 0),
		AutomaticSize = if isle then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
		TextWrapped = not line,
		TextTruncate = if line and not isle then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None,
		Weight = if style == "Achievement" then "bold" else "medium",
		Text = toast.title,
		TextSize = if line then 13 elseif style == "Achievement" then 15 else 14,
		Parent = text,
	})
	if dark then
		toast.titleLabel.TextColor3 = DARK.text
	else
		Theme.bind(toast.titleLabel, "TextColor3", "text")
	end

	-- Content can arrive later through SetContent, so the label always exists
	-- on the looks that show it.
	if not (snack or style == "Compact") then
		toast.contentLabel = Create.new("TextLabel", {
			Name = "Content",
			Size = if isle then UDim2.fromOffset(0, 0) else UDim2.new(1, 0, 0, 0),
			AutomaticSize = if isle then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
			TextWrapped = not isle,
			TextSize = if isle then 12 else 13,
			LayoutOrder = 1,
			Text = toast.content,
			Visible = toast.content ~= "",
			Parent = detail or text,
		})
		if dark then
			toast.contentLabel.TextColor3 = DARK.muted
		else
			Theme.bind(toast.contentLabel, "TextColor3", "textMuted")
		end
	end

	if style == "Progress" then
		-- The bar sits a little apart from the words above it.
		local room = Create.new("Frame", { Name = "Room", Size = UDim2.new(1, 0, 0, 10), LayoutOrder = 3, Parent = text })
		local rail = Create.new("Frame", {
			Name = "Progress",
			Size = UDim2.new(1, 0, 0, 4),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			ClipsDescendants = true,
			Theme = { BackgroundColor3 = "raised" },
			Parent = room,
		})
		Create.corner(-1, rail)
		toast.fill = Create.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(toast.value, 1),
			Theme = { BackgroundColor3 = kind.role },
			Parent = rail,
		})
		Create.corner(-1, toast.fill)
		if options.Indeterminate and toast.value == 0 then
			-- No amount known yet: a short piece of bar runs across until
			-- the hub reports one.
			toast.fill.Size = UDim2.fromScale(0.3, 1)
			toast.running = true
			scope:add(task.spawn(function()
				while toast.running do
					toast.fill.Position = UDim2.fromScale(-0.3, 0)
					Motion.tween(toast.fill, "slow", { Position = UDim2.fromScale(1, 0) })
					task.wait(1.1)
				end
			end))
		end
	end

	-- Buttons of the notice's own: each runs its Callback and dismisses it.
	if not line and type(options.Actions) == "table" and #options.Actions > 0 then
		local actions = Create.new("Frame", {
			Name = "Actions",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = detail or text,
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
end

-- What sits at the end of the first line: the seconds left for Timer, the
-- action word for Snackbar, and a close button on the cards.
local function buildTrailing(library, toast, parent, card)
	local options, style = toast.options, toast.style
	local scope = toast.scope
	if style == "Timer" and toast.duration > 0 then
		local pill = Create.new("TextLabel", {
			Name = "Timer",
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 12,
			Weight = "bold",
			LayoutOrder = 3,
			Text = `{math.ceil(toast.duration)}s`,
			Theme = { BackgroundColor3 = "raised", TextColor3 = "textMuted" },
			Parent = parent,
		})
		Create.corner(-1, pill)
		Create.padding(pill, 8, 0)
		toast.seconds = pill
		return
	end
	if style == "Snackbar" then
		local settings = type(options.Actions) == "table" and options.Actions[1]
		if settings then
			local word = Create.new("TextButton", {
				Name = "Action",
				Size = UDim2.fromOffset(0, if library.touch then 40 else 28),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = settings.Title or "OK",
				TextSize = 13,
				Weight = "bold",
				LayoutOrder = 3,
				Theme = { TextColor3 = "accent" },
				Parent = parent,
			})
			Create.padding(word, 6, 0)
			scope:connect(word.Activated, function()
				toast.Dismiss()
				Env.call(settings.Title or "Notification", settings.Callback)
			end)
		end
		return
	end
	if style == "Compact" or style == "Island" or options.Close == false then
		return
	end
	local close = Create.new("TextButton", { Name = "Close", Size = UDim2.fromOffset(24, 24), LayoutOrder = 3, Parent = parent })
	Create.corner(6, close)
	local cross = centred(Create.icon("x", 14, "textMuted", close))
	-- Shown while the card is hovered; always on a touch screen, which has no hover.
	cross.ImageTransparency = if library.touch then 0 else 1
	scope:connect(close.Activated, toast.Dismiss)
	scope:connect(close.MouseEnter, function()
		Theme.bind(cross, "ImageColor3", "text")
	end)
	scope:connect(close.MouseLeave, function()
		Theme.bind(cross, "ImageColor3", "textMuted")
	end)
	if not library.touch then
		scope:connect(card.MouseEnter, function()
			Motion.tween(cross, "fast", { ImageTransparency = 0 })
		end)
		scope:connect(card.MouseLeave, function()
			Motion.tween(cross, "fast", { ImageTransparency = 1 })
		end)
	end
end

local function show(library, state, toast)
	local options = toast.options
	local kind = KINDS[toast.kind] or KINDS.info
	local style = toast.style
	local snack, isle, compact = style == "Snackbar", style == "Island", style == "Compact"
	local dark = snack or isle
	local line = dark or compact
	local scope = library.scope:child()
	toast.scope = scope
	state.order += 1
	chime(options)

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
		BackgroundTransparency = if style == "Glass" then 0.3 else 0,
		Parent = slot,
	})
	toast.card = card
	if dark then
		card.BackgroundColor3 = DARK.fill
	else
		Theme.bind(card, "BackgroundColor3", if style == "Accent" then kind.role else "surface")
	end
	Create.corner(if isle or compact then -1 elseif snack then 10 else RADIUS, card)
	local edge = Create.stroke(if style == "Glass" then "text" else "stroke", card)
	if style == "Glass" then
		edge.Transparency = 0.8
	elseif dark then
		Theme.unbind(edge, "Color")
		edge.Color = Color3.new(1, 1, 1)
		edge.Transparency = 0.9
	end
	if isle then
		Create.new("UISizeConstraint", { MaxSize = Vector2.new(360, math.huge), Parent = card })
	end
	if style == "Glass" then
		local sheen = Create.new("Frame", {
			Name = "Sheen",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.88,
			Parent = card,
		}, {
			Create.new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}),
		})
		Create.corner(RADIUS, sheen)
	end

	-- Accent: the card is the notice's colour and this panel sits a few
	-- pixels in from its left with the same corners, so the colour shows as
	-- one edge down the whole left side that curves with the card.
	local panel = card
	if style == "Accent" then
		panel = Create.new("Frame", {
			Name = "Panel",
			Size = UDim2.new(1, -EDGE, 0, 0),
			Position = UDim2.fromOffset(EDGE, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Theme = { BackgroundColor3 = "surface" },
			Parent = card,
		})
		Create.corner(RADIUS, panel)
	end

	-- Banner: the first line sits on a tinted band; content and buttons
	-- follow below it.
	local band, detail
	if style == "Banner" then
		Create.list(card, "Vertical", 0)
		band = Create.new("Frame", { Name = "Band", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
		Create.corner(RADIUS, band)
		-- Squares off the band's lower corners where it meets the card.
		local square = Create.new("Frame", {
			Name = "Square",
			Size = UDim2.new(1, 0, 0, RADIUS),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Parent = band,
		})
		tinted(scope, { band, square }, kind.role, 0.24)
		detail = Create.new("Frame", { Name = "Detail", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
		Create.padding(detail, 40, 8, 12, 12)
		Create.list(detail, "Vertical", 2)
	end

	local body = Create.new("Frame", {
		Name = "Body",
		Size = if isle then UDim2.fromOffset(0, 0) else UDim2.new(1, 0, 0, 0),
		AutomaticSize = if isle then Enum.AutomaticSize.XY else Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = band or panel,
	})
	local pad
	if isle then
		pad = Create.padding(body, 16, 10)
	elseif line then
		pad = Create.padding(body, 14, if snack then 8 else 10)
	elseif style == "Banner" then
		pad = Create.padding(body, 12, 10)
	else
		pad = Create.padding(body, 12, 12, 10, 12)
	end
	Create.list(body, "Horizontal", 10, { VerticalAlignment = if line or style == "Banner" then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top })
	buildLead(toast, kind, body)
	buildText(library, toast, kind, body, detail)
	buildTrailing(library, toast, body, card)
	if detail and toast.contentLabel and toast.content == "" and not detail:FindFirstChild("Actions") then
		-- A banner with nothing below its band ends at the band.
		detail.Visible = false
	end

	if style == "Achievement" and not Motion.reduced then
		local grow = Create.new("UIScale", { Scale = 0.9, Parent = card })
		Motion.tween(grow, "spring", { Scale = 1 })
	end
	Motion.tween(card, "base", { Position = UDim2.fromOffset(0, 0) })

	-- Hovering pauses the countdown; a tap dismisses, unless it ended a drag.
	local hovering = false
	scope:connect(card.MouseEnter, function()
		hovering = true
		toast.paused = true
	end)
	scope:connect(card.MouseLeave, function()
		hovering = false
		toast.paused = toast.dragging == true
	end)
	scope:connect(card.Activated, function()
		if not toast.swiped then
			toast.Dismiss()
		end
	end)
	if not isle then
		-- Dragged far enough sideways and let go, the card leaves; not far
		-- enough, it springs back.
		Drag.track(scope, card, function()
			toast.dragging = true
			toast.paused = true
			return true
		end, function(position, origin, moved)
			if moved then
				toast.swiped = true
				card.Position = UDim2.fromOffset(position.X - origin.X, 0)
			end
		end, function(moved)
			toast.dragging = false
			toast.paused = hovering
			task.defer(function()
				toast.swiped = false
			end)
			if not moved then
				return
			end
			local offset = card.Position.X.Offset
			if math.abs(offset) >= SWIPE then
				toast.leaving = math.sign(offset)
				toast.Dismiss()
			else
				Motion.tween(card, "spring", { Position = UDim2.fromOffset(0, 0) })
			end
		end)
	end

	local duration = toast.duration
	if duration > 0 then
		local fill
		if toast.progress and not line and style ~= "Timer" and style ~= "Progress" and not Motion.reduced then
			if band then
				-- The countdown runs along the bottom of the band, inset from
				-- the card's sides like the rail on the other cards.
				local rail = Create.new("Frame", {
					Name = "Countdown",
					Size = UDim2.new(1, -24, 0, 2),
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 12, 1, -1),
					BackgroundTransparency = 1,
					ZIndex = 3,
					Parent = band,
				})
				fill = Create.new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), ZIndex = 3, Theme = { BackgroundColor3 = kind.role }, Parent = rail })
				Create.corner(-1, fill)
			else
				-- A rounded rail inside the padding, clear of the edge and the outline.
				pad.PaddingBottom = UDim.new(0, 22)
				local rail = Create.new("Frame", {
					Name = "Countdown",
					Size = UDim2.new(1, -24, 0, 3),
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 12, 1, -10),
					ZIndex = 2,
					Theme = { BackgroundColor3 = "raised" },
					Parent = panel,
				})
				Create.corner(-1, rail)
				fill = Create.new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), ZIndex = 2, Theme = { BackgroundColor3 = kind.role }, Parent = rail })
				Create.corner(-1, fill)
			end
		end
		-- Counts on the same scheduler as everything else, and stands still
		-- while the card is hovered or held.
		toast.left = duration
		scope:add(task.spawn(function()
			while toast.left > 0 do
				local elapsed = task.wait(0.05)
				if not toast.paused then
					toast.left -= elapsed
					if fill then
						fill.Size = UDim2.fromScale(math.max(toast.left / duration, 0), 1)
					end
					if toast.seconds then
						toast.seconds.Text = `{math.max(math.ceil(toast.left), 0)}s`
					end
				end
			end
			toast.Dismiss()
		end))
	end
end

-- Options: Title, Content, Kind ("info", "success", "warning", "danger"),
-- Style (see the looks above), Sound (true or a sound id), Icon, Duration in
-- seconds (0 stays until dismissed), Progress (false hides the countdown),
-- Close (false hides the close button), Indeterminate (a Progress notice
-- with no amount yet), Actions as a list of { Title, Callback }.
-- Returns a handle with Dismiss, SetTitle, SetContent, SetProgress and Done
-- (also called Complete).
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
		toast.running = false
		if toast.fill then
			toast.fill.Position = UDim2.fromScale(0, 0)
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
			local detail = toast.contentLabel.Parent
			if detail and detail.Name == "Detail" then
				detail.Visible = true
			end
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
			if toast.tileRole ~= "fill" then
				Theme.bind(toast.icon, "ImageColor3", finished.role)
			end
		end
		if toast.tile then
			Theme.bind(toast.tile, "BackgroundColor3", finished.role)
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
	toast.Complete = toast.Done

	function toast.Dismiss()
		if toast.done then
			return
		end
		toast.done = true
		toast.running = false
		local queued = table.find(state.queue, toast)
		if queued then
			table.remove(state.queue, queued)
			state.count()
			return
		end
		table.remove(state.active, table.find(state.active, toast))
		local scope, card = toast.scope, toast.card
		-- The card slides out towards its edge (or the way it was swiped),
		-- quicker than it came in, then makes room for the next one.
		if card and not Motion.reduced and toast.style ~= "Island" then
			local side = toast.leaving or state.side
			if side == 0 then
				side = 1
			end
			Motion.tween(card, "fast", { Position = UDim2.fromOffset(side * (WIDTH + 24), 0) })
			task.delay(0.14, function()
				library.scope:release(scope)
			end)
		else
			library.scope:release(scope)
		end
		local waiting = table.remove(state.queue, 1)
		if waiting then
			table.insert(state.active, waiting)
			show(library, state, waiting)
		end
		state.count()
	end

	remember(library, toast)
	if #state.active < defaults.MaxVisible then
		table.insert(state.active, toast)
		show(library, state, toast)
	else
		table.insert(state.queue, toast)
	end
	state.count()
	return toast
end

return Notifications
