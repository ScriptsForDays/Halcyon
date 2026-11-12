local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Rating = {}

-- A row of icons picked by count: a rating, a level, a strength.
-- Options: Max (default 5), Default, Icon (default "star"), AllowNone
-- (pressing the current value clears it).
function Rating.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local max = math.clamp(math.floor(tonumber(options.Max) or 5), 1, 10)
	local value = math.clamp(math.floor(tonumber(options.Default) or 0), 0, max)
	local preview
	local marks = {}
	local size = if row.library.touch then 30 else 22

	local holder = Create.new("Frame", { Name = "Rating", Size = UDim2.fromOffset(0, size), AutomaticSize = Enum.AutomaticSize.X, Parent = row.slot })
	Create.list(holder, "Horizontal", 2)

	local function draw()
		local shown = preview or value
		for index, mark in marks do
			local on = index <= shown
			Theme.bind(mark.glyph, "ImageColor3", if on then "warning" else "stroke")
			Motion.tween(mark.scale, "fast", { Scale = if preview and index == preview then 1.15 else 1 })
		end
	end

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		value = math.clamp(math.floor(tonumber(newValue) or 0), 0, max)
		draw()
		row.fire(value)
	end

	for index = 1, max do
		local button = Create.new("ImageButton", { Name = "Mark", Size = UDim2.fromOffset(size, size), LayoutOrder = index, Parent = holder })
		local glyph = Create.icon(options.Icon or "star", size - 6, "stroke", button)
		glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		local mark = { glyph = glyph, scale = Create.new("UIScale", { Parent = glyph }) }
		marks[index] = mark
		scope:connect(button.MouseEnter, function()
			preview = index
			draw()
		end)
		scope:connect(button.MouseLeave, function()
			if preview == index then
				preview = nil
				draw()
			end
		end)
		scope:connect(button.Activated, function()
			handle:Set(if index == value and options.AllowNone then 0 else index)
		end)
	end

	draw()
	return handle
end

return Rating
