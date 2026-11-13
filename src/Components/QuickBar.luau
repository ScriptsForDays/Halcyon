-- A small floating bar of the hub's most used switches and buttons. It
-- stays on screen when the window is hidden, so a phone player can flip a
-- feature without opening the hub. Drag it by its grip.
--
-- Items: a toggle's Flag or handle (pressing flips it and the bar shows
-- its state), or { Title, Icon, Callback } for a button.

local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Env = require("../Core/Env")
local Theme = require("../Core/Theme")

local QuickBar = {}

function QuickBar.new(window, options)
	options = options or {}
	local scope = window.scope:child()
	local touch = window.library.touch
	local size = if touch then 44 else 36
	local bar = Create.new("Frame", {
		Name = "QuickBar",
		Size = UDim2.fromOffset(0, size + 12),
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = options.Position or UDim2.new(0.5, 0, 1, -16),
		Active = true,
		Theme = { BackgroundColor3 = "surface" },
		Parent = window.gui,
	})
	scope:add(bar)
	Create.corner(-1, bar)
	Create.stroke("stroke", bar)
	Create.padding(bar, 6, 6)
	Create.list(bar, "Horizontal", 4, { VerticalAlignment = Enum.VerticalAlignment.Center })
	Create.new("UIScale", { Scale = window.scale, Parent = bar })

	local grip = Create.new("Frame", { Name = "Grip", Size = UDim2.fromOffset(18, size), Parent = bar })
	local dots = Create.icon("grip-vertical", 14, "textMuted", grip)
	dots.AnchorPoint, dots.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	Drag.move(scope, grip, bar, {})

	local handle = { Frame = bar, scope = scope }
	local order = 0

	local function button(icon, title)
		order += 1
		local press = Create.new("TextButton", {
			Name = title or "Item",
			Size = UDim2.fromOffset(0, size),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
			BackgroundTransparency = 1,
			Theme = { BackgroundColor3 = "accent" },
			Parent = bar,
		})
		Create.corner(-1, press)
		Create.padding(press, 10, 0)
		Create.list(press, "Horizontal", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
		local glyph = Create.icon(icon or "circle", 16, "textMuted", press)
		local label = Create.new("TextLabel", {
			Name = "Title",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = title or "",
			TextSize = 12,
			Weight = "medium",
			LayoutOrder = 1,
			Visible = (title or "") ~= "",
			Theme = { TextColor3 = "text" },
			Parent = press,
		})
		return press, glyph, label
	end

	-- Adds an item: a toggle (its Flag or handle) or { Title, Icon, Callback }.
	function handle:Add(item)
		local target = if type(item) == "string" then window.Flags[item] else item
		if type(target) == "table" and target.Get and target.Set and target.Changed then
			local press, glyph, label = button(target.QuickIcon or target.Icon or "zap", target.Title)
			local function paint()
				local on = target:Get() == true
				press.BackgroundTransparency = if on then 0 else 1
				Theme.bind(glyph, "ImageColor3", if on then "onAccent" else "textMuted")
				Theme.bind(label, "TextColor3", if on then "onAccent" else "text")
			end
			scope:connect(press.Activated, function()
				target:Set(not (target:Get() == true))
			end)
			scope:connect(target.Changed, paint)
			paint()
			return press
		elseif type(item) == "table" then
			local press = button(item.Icon, item.Title)
			scope:connect(press.Activated, function()
				Env.call(item.Title or "Quick bar", item.Callback)
			end)
			return press
		end
		warn(`[Halcyon] QuickBar couldn't use {tostring(item)}: give a toggle, its Flag, or a table with a Callback.`)
		return nil
	end

	function handle:SetVisible(visible)
		bar.Visible = visible ~= false
	end

	function handle:Destroy()
		window.scope:release(scope)
	end

	for _, item in options.Items or {} do
		handle:Add(item)
	end
	return handle
end

return QuickBar
