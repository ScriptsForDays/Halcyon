-- Hover tips on any row: `Tooltip = "text"` or { Title, Text, Key }.
-- A tip appears after a short pause over the row, and on touch after a
-- long press, and lives in the overlay so no page or window edge clips it.

local UserInputService = game:GetService("UserInputService")

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Mount = require("../Core/Mount")
local Styles = require("../Core/Styles")

local DELAY, LONG_PRESS, TOUCH_TIME = 0.45, 0.5, 2.5
local GAP, MARGIN, WIDTH = 8, 8, 240

-- Tooltip looks (kind "Tooltip").
--   Card    a card with an optional title and key, under or over the row
--   Plain   a small dark label, one or two lines
--   Follow  the card, kept beside the pointer while it moves
Styles.register("Tooltip", "Card", { card = true })
Styles.register("Tooltip", "Plain", { inverted = true })
Styles.register("Tooltip", "Follow", { card = true, follow = true })

local Tooltip = {}

local function build(library, spec, look)
	local overlay = Mount.overlay(library)
	local inverted = look.inverted == true
	local frame = Create.new("Frame", {
		Name = "Tooltip",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Theme = { BackgroundColor3 = if inverted then "text" else "surface" },
		Parent = overlay.popups,
	})
	Create.new("UIScale", { Scale = library.scale, Parent = frame })
	Create.new("UISizeConstraint", { MaxSize = Vector2.new(WIDTH, math.huge), Parent = frame })
	Create.corner(if inverted then 6 else 8, frame)
	local edge = Create.stroke("stroke", frame)
	edge.Transparency = if inverted then 1 else 0
	Create.padding(frame, if inverted then 8 else 10, if inverted then 5 else 8)
	Create.list(frame, "Vertical", 3)
	if spec.Title or spec.Key then
		local head = Create.new("Frame", { Name = "Head", Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, Parent = frame })
		Create.list(head, "Horizontal", 6)
		if spec.Title then
			Create.new("TextLabel", {
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = tostring(spec.Title),
				TextSize = 13,
				Weight = "bold",
				Theme = { TextColor3 = if inverted then "background" else "text" },
				Parent = head,
			})
		end
		if spec.Key then
			local key = Create.new("TextLabel", {
				Size = UDim2.fromOffset(0, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = tostring(spec.Key),
				TextSize = 11,
				Weight = "bold",
				LayoutOrder = 1,
				Theme = { BackgroundColor3 = "raised", TextColor3 = "textMuted" },
				Parent = head,
			})
			Create.corner(4, key)
			Create.padding(key, 5, 0)
		end
	end
	if spec.Text then
		Create.new("TextLabel", {
			Name = "Text",
			Size = UDim2.fromOffset(0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			TextWrapped = true,
			RichText = true,
			TextSize = 12,
			LayoutOrder = 1,
			Text = tostring(spec.Text),
			Theme = { TextColor3 = if inverted then "background" else "textMuted" },
			Parent = frame,
		}, { Create.new("UISizeConstraint", { MaxSize = Vector2.new(WIDTH - 20, math.huge) }) })
	end
	return frame, overlay
end

-- Keeps `frame` on screen: under `anchor` (a Vector2 or a GuiObject), or
-- over it when there is no room below.
local function place(frame, overlay, anchor)
	local view, origin = overlay.gui.AbsoluteSize, overlay.gui.AbsolutePosition
	local size = frame.AbsoluteSize
	local x, top, bottom
	if typeof(anchor) == "Vector2" then
		local point = anchor - origin
		x, top, bottom = point.X + 14, point.Y, point.Y + 18
	else
		local corner = anchor.AbsolutePosition - origin
		x, top, bottom = corner.X + 12, corner.Y, corner.Y + anchor.AbsoluteSize.Y
	end
	local y = if bottom + GAP + size.Y <= view.Y - MARGIN then bottom + GAP else top - GAP - size.Y
	x = math.clamp(x, MARGIN, math.max(view.X - size.X - MARGIN, MARGIN))
	y = math.clamp(y, MARGIN, math.max(view.Y - size.Y - MARGIN, MARGIN))
	frame.Position = UDim2.fromOffset(math.round(x), math.round(y))
end

-- Attaches a tip to a row. `spec` is text or { Title, Text, Key, Style }.
function Tooltip.attach(row, spec)
	if type(spec) ~= "table" then
		spec = { Text = tostring(spec) }
	end
	local library, scope = row.library, row.scope
	local look = Styles.pick("Tooltip", spec.Style, row.window)
	local target = row.frame
	local shown, overlay
	local generation = 0

	local function hide()
		generation += 1
		if shown then
			shown:Destroy()
			shown = nil
		end
	end

	local function show(at)
		hide()
		local mine = generation
		local frame
		frame, overlay = build(library, spec, look)
		shown = frame
		place(frame, overlay, if look.follow and at then at else target)
		-- Placed again once its size is known, then faded in.
		task.defer(function()
			if mine == generation and shown == frame then
				place(frame, overlay, if look.follow and at then at else target)
				Motion.tween(frame, "fast", { BackgroundTransparency = 0 })
			end
		end)
	end


	scope:connect(target.MouseEnter, function()
		generation += 1
		local mine = generation
		task.delay(DELAY, function()
			if mine == generation and not scope.cleaned and target.Visible ~= false then
				show(UserInputService:GetMouseLocation())
			end
		end)
	end)
	scope:connect(target.MouseLeave, hide)
	if look.follow then
		scope:connect(UserInputService.InputChanged, function(input)
			if shown and input.UserInputType == Enum.UserInputType.MouseMovement then
				place(shown, overlay, Vector2.new(input.Position.X, input.Position.Y))
			end
		end)
	end
	-- A long press on touch shows the tip for a moment.
	scope:connect(target.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		generation += 1
		local mine = generation
		task.delay(LONG_PRESS, function()
			if mine == generation and not scope.cleaned then
				show(Vector2.new(input.Position.X, input.Position.Y))
				local current = generation
				task.delay(TOUCH_TIME, function()
					if current == generation then
						hide()
					end
				end)
			end
		end)
	end)
	scope:connect(target.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.Touch and not shown then
			generation += 1
		end
	end)
	scope:add(hide)

	return { show = show, hide = hide }
end

return Tooltip
