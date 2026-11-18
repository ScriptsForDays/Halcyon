-- Charts for comparing numbers: Donut and Pie show shares of a whole, Line
-- and Bars show several series across the same labels. Colours are theme
-- roles, so a theme change recolours the chart; the legend names every
-- colour, so colour is never the only way to tell series apart.
--
--   Section:Chart({ Title = "Loot", Type = "Donut",
--       Items = { { Name = "Coins", Value = 120 }, { Name = "Gems", Value = 30 } } })
--   Section:Chart({ Title = "Per hour", Type = "Line", Labels = { "1", "2", "3" },
--       Series = { { Name = "Coins", Values = { 10, 40, 25 } } } })

local Arc = require("../Core/Arc")
local Create = require("../Core/Create")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Chart = {}

-- The roles series take in turn when they don't name one.
local ROLES = { "accent", "info", "success", "warning", "danger", "textMuted" }
local TYPES = { Donut = true, Pie = true, Line = true, Bars = true }
local INSET = 10

local function format(options, value)
	if type(options.Format) == "function" then
		local ok, text = pcall(options.Format, value)
		if ok then
			return tostring(text)
		end
	end
	local rounded = if math.abs(value) >= 100 then math.round(value) else math.round(value * 10) / 10
	return tostring(rounded) .. (options.Suffix or "")
end

local function colourOf(entry, index)
	return entry.Role or ROLES[(index - 1) % #ROLES + 1]
end

function Chart.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local kind = if TYPES[options.Type] then options.Type else "Line"
	local round = kind == "Donut" or kind == "Pie"
	local height = math.clamp(tonumber(options.Height) or (if round then 132 else 140), 60, 320)
	local items = options.Items or {}
	local series = options.Series or {}
	local labels = options.Labels or {}

	local below = row.belowTitle()
	-- Line and Bars put the legend above the plot.
	if not round then
		Create.list(below, "Vertical", 6)
	end
	local body = Create.new("Frame", { Name = "Chart", Size = UDim2.new(1, 0, 0, height), LayoutOrder = 1, Parent = below })
	local legend = Create.new("Frame", {
		Name = "Legend",
		Size = if round then UDim2.new(1, -height - 16, 1, 0) else UDim2.new(1, 0, 0, 0),
		Position = if round then UDim2.fromOffset(height + 16, 0) else UDim2.new(),
		AutomaticSize = if round then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		Parent = if round then body else below,
	})
	Create.list(legend, if round then "Vertical" else "Horizontal", if round then 6 else 12, {
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Wraps = not round,
	})

	local legendRows = {}
	local function drawLegend(entries, withValues)
		legend:ClearAllChildren()
		Create.list(legend, if round then "Vertical" else "Horizontal", if round then 6 else 12, {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Wraps = not round,
		})
		table.clear(legendRows)
		local total = 0
		for _, entry in entries do
			total += tonumber(entry.Value) or 0
		end
		for index, entry in entries do
			local line = Create.new("Frame", { Name = "Entry", Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = index, Parent = legend })
			Create.list(line, "Horizontal", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
			local dot = Create.new("Frame", { Name = "Swatch", Size = UDim2.fromOffset(8, 8), Theme = { BackgroundColor3 = colourOf(entry, index) }, Parent = line })
			Create.corner(-1, dot)
			local share = if total > 0 then math.round((tonumber(entry.Value) or 0) / total * 100) else 0
			local text = Create.new("TextLabel", {
				Name = "Name",
				Size = UDim2.fromOffset(0, 18),
				AutomaticSize = Enum.AutomaticSize.X,
				TextSize = 12,
				LayoutOrder = 1,
				Text = if withValues then `{entry.Name or ""}  <font transparency="0.4">{format(options, tonumber(entry.Value) or 0)} · {share}%</font>` else tostring(entry.Name or ""),
				RichText = true,
				Theme = { TextColor3 = "text" },
				Parent = line,
			})
			legendRows[index] = text
		end
	end

	-- Donut and Pie --------------------------------------------------------------
	local ring, centre, arcs = nil, nil, {}
	if round then
		ring = Create.new("Frame", { Name = "Ring", Size = UDim2.fromOffset(height, height), Parent = body })
		centre = Create.new("TextLabel", {
			Name = "Centre",
			Size = UDim2.fromScale(1, 1),
			TextSize = 13,
			Weight = "bold",
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Visible = kind == "Donut",
			Theme = { TextColor3 = "text" },
			ZIndex = 3,
			Parent = ring,
		})
	end
	local thickness = if kind == "Pie" then math.floor(height / 2) - 1 else math.max(math.round(height / 9), 8)

	local function total()
		local sum = 0
		for _, item in items do
			sum += math.max(tonumber(item.Value) or 0, 0)
		end
		return sum
	end

	local function drawRound()
		for _, arc in arcs do
			arc:Destroy()
		end
		table.clear(arcs)
		local sum = total()
		-- Each item draws from the top to the end of its own share; drawn
		-- largest-reach first, later ones cover the start of earlier ones,
		-- which leaves every item showing exactly its own slice.
		local reach = {}
		local running = 0
		for index, item in items do
			running += math.max(tonumber(item.Value) or 0, 0)
			reach[index] = if sum > 0 then running / sum else 0
		end
		if sum <= 0 then
			local empty = Arc.new(ring, { Thickness = thickness, Role = "raised", Radius = -1, Even = false })
			table.insert(arcs, empty)
		end
		for index = #items, 1, -1 do
			local arc = Arc.new(ring, { Thickness = thickness, Role = colourOf(items[index], index), Radius = -1, Even = false, ZIndex = 2 })
			arc:Set(reach[index])
			table.insert(arcs, arc)
		end
		if centre then
			centre.Text = format(options, sum)
		end
		drawLegend(items, true)
	end

	-- Hovering a slice shows its name and value in the middle.
	if round then
		scope:connect(ring.MouseMoved, function(x, y)
			local sum = total()
			if sum <= 0 or not centre then
				return
			end
			local middle = ring.AbsolutePosition + ring.AbsoluteSize / 2
			local angle = math.deg(math.atan2(x - middle.X, -(y - middle.Y)))
			if angle < 0 then
				angle += 360
			end
			local running = 0
			for index, item in items do
				running += math.max(tonumber(item.Value) or 0, 0)
				if angle / 360 <= running / sum then
					centre.Text = `{item.Name or ""}\n{format(options, tonumber(item.Value) or 0)}`
					for other, label in legendRows do
						label.TextTransparency = if other == index then 0 else 0.5
					end
					return
				end
			end
		end)
		scope:connect(ring.MouseLeave, function()
			if centre then
				centre.Text = format(options, total())
			end
			for _, label in legendRows do
				label.TextTransparency = 0
			end
		end)
	end

	-- Line and Bars --------------------------------------------------------------
	local plot, marks, guide, readout
	if not round then
		plot = Create.new("Frame", {
			Name = "Plot",
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = true,
			Theme = { BackgroundColor3 = row.controlRole },
			Parent = body,
		})
		Create.corner(8, plot)
		marks = Create.new("Frame", { Name = "Marks", Size = UDim2.fromScale(1, 1), Parent = plot })
		guide = Create.new("Frame", {
			Name = "Guide",
			Size = UDim2.new(0, 1, 1, -INSET * 2),
			Position = UDim2.fromOffset(0, INSET),
			Visible = false,
			ZIndex = 4,
			Theme = { BackgroundColor3 = "textMuted" },
			Parent = plot,
		})
		readout = Create.new("TextLabel", {
			Name = "Readout",
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 12,
			RichText = true,
			Visible = false,
			ZIndex = 5,
			Theme = { BackgroundColor3 = "surface", TextColor3 = "text" },
			Parent = plot,
		})
		Create.corner(6, readout)
		Create.padding(readout, 8, 0)
		Create.stroke("stroke", readout)
	end

	local function longest()
		local count = #labels
		for _, entry in series do
			count = math.max(count, #(entry.Values or {}))
		end
		return count
	end

	local function range()
		local low, high = math.huge, -math.huge
		for _, entry in series do
			for _, value in entry.Values or {} do
				if type(value) == "number" then
					low, high = math.min(low, value), math.max(high, value)
				end
			end
		end
		if kind == "Bars" or low == math.huge then
			low = math.min(if low == math.huge then 0 else low, 0)
		end
		if type(options.Min) == "number" then
			low = options.Min
		end
		if type(options.Max) == "number" then
			high = options.Max
		end
		if high == -math.huge or high - low < 1e-6 then
			high = low + 1
		end
		return low, high
	end

	local function drawPlot()
		marks:ClearAllChildren()
		local size = plot.AbsoluteSize / row.library.scale
		local count = longest()
		drawLegend(series, false)
		if size.X <= 0 or count == 0 then
			return
		end
		local low, high = range()
		local width, tall = size.X - INSET * 2, size.Y - INSET * 2
		local function y(value)
			return INSET + tall - (value - low) / (high - low) * tall
		end
		if kind == "Line" then
			local step = if count > 1 then width / (count - 1) else 0
			for index, entry in series do
				local role = colourOf(entry, index)
				local values = entry.Values or {}
				for point = 2, #values do
					local a, b = values[point - 1], values[point]
					if type(a) == "number" and type(b) == "number" then
						local x1, y1 = INSET + (point - 2) * step, y(a)
						local x2, y2 = INSET + (point - 1) * step, y(b)
						local dx, dy = x2 - x1, y2 - y1
						local segment = Create.new("Frame", {
							Name = "Segment",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
							Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 2),
							Rotation = math.deg(math.atan2(dy, dx)),
							ZIndex = 3,
							Theme = { BackgroundColor3 = role },
							Parent = marks,
						})
						Create.corner(-1, segment)
					end
				end
			end
		else
			-- Bars: one group per label, one bar per series in it.
			local group = width / count
			local per = math.max((group - 6) / math.max(#series, 1), 2)
			local base = y(math.max(low, 0))
			for slot = 1, count do
				for index, entry in series do
					local value = (entry.Values or {})[slot]
					if type(value) == "number" then
						local top = y(value)
						local bar = Create.new("Frame", {
							Name = "Bar",
							Position = UDim2.fromOffset(INSET + (slot - 1) * group + 3 + (index - 1) * per, math.min(top, base)),
							Size = UDim2.fromOffset(math.max(per - 2, 1), math.max(math.abs(base - top), 1)),
							ZIndex = 2,
							Theme = { BackgroundColor3 = colourOf(entry, index) },
							Parent = marks,
						})
						Create.corner(3, bar)
					end
				end
			end
		end
	end

	-- Hovering the plot shows every series' value at the nearest label.
	if plot then
		scope:connect(plot.MouseMoved, function(x)
			local count = longest()
			local size = plot.AbsoluteSize
			if count == 0 or size.X <= 0 then
				return
			end
			local pointerX = (x - plot.AbsolutePosition.X) / row.library.scale
			local width = size.X / row.library.scale - INSET * 2
			local slot
			if kind == "Line" then
				slot = if count > 1 then math.clamp(math.round((pointerX - INSET) / width * (count - 1)) + 1, 1, count) else 1
			else
				slot = math.clamp(math.floor((pointerX - INSET) / width * count) + 1, 1, count)
			end
			local parts = { `<b>{labels[slot] or slot}</b>` }
			for index, entry in series do
				local value = (entry.Values or {})[slot]
				if type(value) == "number" then
					local colour = Theme.color(colourOf(entry, index)):ToHex()
					table.insert(parts, `<font color="#{colour}">{entry.Name or ""}</font> {format(options, value)}`)
				end
			end
			local guideX = if kind == "Line" then INSET + (if count > 1 then (slot - 1) * width / (count - 1) else 0) else INSET + (slot - 0.5) * width / count
			guide.Position = UDim2.fromOffset(guideX, INSET)
			guide.Visible = true
			readout.Text = table.concat(parts, "  ")
			readout.Visible = true
			-- Beside the guide on whichever side it fits, and never past the
			-- plot's edges (its width is last frame's, close enough for one label).
			local plotWidth = size.X / row.library.scale
			local readoutWidth = readout.AbsoluteSize.X / row.library.scale
			if guideX + 6 + readoutWidth <= plotWidth - 4 then
				readout.AnchorPoint = Vector2.new(0, 0)
				readout.Position = UDim2.fromOffset(guideX + 6, 4)
			else
				readout.AnchorPoint = Vector2.new(1, 0)
				readout.Position = UDim2.fromOffset(math.min(math.max(guideX - 6, readoutWidth + 4), plotWidth - 4), 4)
			end
		end)
		scope:connect(plot.MouseLeave, function()
			guide.Visible = false
			readout.Visible = false
		end)
		scope:connect(plot:GetPropertyChangedSignal("AbsoluteSize"), drawPlot)
	end

	local function draw()
		if round then
			drawRound()
		else
			drawPlot()
		end
	end
	scope:connect(Theme.Changed, function()
		if not round then
			drawPlot()
		end
	end)

	function handle:Get()
		return if round then items else series
	end

	-- Donut and Pie take a list of { Name, Value, Role }; Line and Bars a
	-- list of { Name, Values, Role }.
	function handle:Set(data)
		if type(data) ~= "table" then
			return
		end
		if round then
			items = data
		else
			series = data
		end
		draw()
		row.fire(data)
	end
	handle.SetItems = handle.Set
	handle.SetSeries = handle.Set

	function handle:SetLabels(list)
		labels = list or {}
		draw()
	end

	-- Adds one value to the end of each series (Line and Bars), with an
	-- optional label; `keep` trims the oldest beyond that many.
	function handle:Push(values, label, keep)
		if round or type(values) ~= "table" then
			return
		end
		for index, entry in series do
			entry.Values = entry.Values or {}
			table.insert(entry.Values, values[index] or values[entry.Name])
			if keep then
				while #entry.Values > keep do
					table.remove(entry.Values, 1)
				end
			end
		end
		if label ~= nil then
			table.insert(labels, label)
			if keep then
				while #labels > keep do
					table.remove(labels, 1)
				end
			end
		end
		draw()
	end

	draw()
	return handle
end

return Chart
