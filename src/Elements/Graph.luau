local Create = require("../Core/Create")
local Row = require("./Row")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

-- How a graph draws its values (kind "Graph"): Line joins them, Area adds a
-- light fill under the line, Bars stands each value up on its own.
Styles.register("Graph", "Line", { line = true })
Styles.register("Graph", "Area", { line = true, fill = true })
Styles.register("Graph", "Bars", { bars = true })

local Graph = {}

local function format(value, options)
	if type(options.Format) == "function" then
		local ok, text = pcall(options.Format, value)
		if ok then
			return tostring(text)
		end
	end
	local rounded = if math.abs(value) >= 100 then math.round(value) else math.round(value * 10) / 10
	return tostring(rounded) .. (options.Suffix or "")
end

-- A small chart of recent values, such as frame rate or coins per minute.
-- Options: Values (to start with), Max (how many it keeps, default 40),
-- Min and Ceiling (a fixed range; otherwise it fits the values), Height
-- (default 80), Suffix or Format for the latest value shown beside the
-- title, Role (the colour, default "accent"), Style ("Line", "Area" or
-- "Bars"). Push(value) adds one; Set(list) replaces them all.
function Graph.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local look = Styles.pick("Graph", options.Style, row.window)
	local keep = math.clamp(math.floor(tonumber(options.Max) or 40), 2, 200)
	local height = math.clamp(tonumber(options.Height) or 80, 40, 240)
	local role = options.Role or "accent"
	local values = {}
	for _, value in options.Values or {} do
		if type(value) == "number" then
			table.insert(values, value)
		end
	end

	local latest = Create.new("TextLabel", {
		Name = "Latest",
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 13,
		Weight = "bold",
		Theme = { TextColor3 = "text" },
		Parent = row.slot,
	})
	local below = row.belowTitle()
	local plot = Create.new("Frame", {
		Name = "Plot",
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = below,
	})
	Create.corner(8, plot)
	local marks = Create.new("Frame", { Name = "Marks", Size = UDim2.fromScale(1, 1), Parent = plot })
	-- A faint guide line across the middle.
	Create.new("Frame", {
		Name = "Guide",
		Size = UDim2.new(1, -16, 0, 1),
		Position = UDim2.new(0, 8, 0.5, 0),
		BackgroundTransparency = 0.5,
		Theme = { BackgroundColor3 = "stroke" },
		Parent = plot,
	})

	local pieces = {}
	local function piece(index)
		local found = pieces[index]
		if not found then
			found = {
				segment = Create.new("Frame", { Name = "Segment", AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Theme = { BackgroundColor3 = role }, Parent = marks }),
				column = Create.new("Frame", { Name = "Column", AnchorPoint = Vector2.new(0, 1), ZIndex = 2, Theme = { BackgroundColor3 = role }, Parent = marks }),
			}
			Create.corner(-1, found.segment)
			pieces[index] = found
		end
		return found
	end

	local function draw()
		local size = plot.AbsoluteSize / row.library.scale
		local count = #values
		latest.Text = if count > 0 then format(values[count], options) else ""
		for index = count + 1, #pieces do
			pieces[index].segment.Visible = false
			pieces[index].column.Visible = false
		end
		if size.X <= 0 or count == 0 then
			return
		end
		local low, high = math.huge, -math.huge
		for _, value in values do
			low, high = math.min(low, value), math.max(high, value)
		end
		low = if type(options.Min) == "number" then options.Min else low
		high = if type(options.Ceiling) == "number" then options.Ceiling else high
		if high - low < 1e-6 then
			high, low = high + 1, low - 1
		end
		local inset = 8
		local width, tall = size.X - inset * 2, size.Y - inset * 2
		local step = if count > 1 then width / (keep - 1) else 0
		local function point(index)
			local x = inset + width - (count - index) * step
			local y = inset + tall - (values[index] - low) / (high - low) * tall
			return x, y
		end
		for index = 1, count do
			local mark = piece(index)
			local x, y = point(index)
			if look.bars then
				local barWidth = math.max(step - 3, 2)
				mark.segment.Visible = false
				mark.column.Visible = true
				mark.column.BackgroundTransparency = 0
				mark.column.Position = UDim2.fromOffset(x - barWidth / 2, size.Y - inset)
				mark.column.Size = UDim2.fromOffset(barWidth, math.max(size.Y - inset - y, 1))
			else
				-- A line is a thin bar from this point to the previous one, turned
				-- to the angle between them.
				if index > 1 then
					local px, py = point(index - 1)
					local dx, dy = x - px, y - py
					mark.segment.Visible = true
					mark.segment.Position = UDim2.fromOffset((x + px) / 2, (y + py) / 2)
					mark.segment.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 2)
					mark.segment.Rotation = math.deg(math.atan2(dy, dx))
				else
					mark.segment.Visible = false
				end
				mark.column.Visible = look.fill == true
				if look.fill then
					mark.column.BackgroundTransparency = 0.88
					mark.column.Position = UDim2.fromOffset(x - step / 2, size.Y - inset)
					mark.column.Size = UDim2.fromOffset(math.max(step, 1), math.max(size.Y - inset - y, 0))
				end
			end
		end
	end
	scope:connect(plot:GetPropertyChangedSignal("AbsoluteSize"), draw)

	function handle:Push(value)
		if type(value) ~= "number" then
			return
		end
		table.insert(values, value)
		while #values > keep do
			table.remove(values, 1)
		end
		draw()
		row.fire(value)
	end

	function handle:Set(list)
		table.clear(values)
		for _, value in list or {} do
			if type(value) == "number" then
				table.insert(values, value)
			end
		end
		while #values > keep do
			table.remove(values, 1)
		end
		draw()
	end

	function handle:Get()
		return table.clone(values)
	end

	function handle:Clear()
		handle:Set({})
	end

	draw()
	return handle
end

return Graph
