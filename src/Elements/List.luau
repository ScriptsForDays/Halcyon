local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Motion = require("../Core/Motion")
local Options = require("./Options")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local List = {}

-- A list shown in place rather than in a dropdown: pick one or several, or
-- drag the items into an order (a priority list, a route). Options: Values
-- (strings or { Text, Value, Icon, Description }), Default, Multi, Search,
-- Reorder, Height (the most it shows before scrolling, default 200).
-- Get returns the picked value, the picked list (Multi), or every value in
-- its current order (Reorder).
function List.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local reorder = options.Reorder == true
	local multi = options.Multi == true and not reorder
	local entries, plain = Options.entries(options.Values)
	local values = {}
	for _, entry in entries do
		if not entry.heading then
			table.insert(values, entry)
		end
	end
	local itemHeight = if row.library.touch then 40 else 34
	local picked = {}
	if multi and type(options.Default) == "table" then
		for _, value in options.Default do
			picked[value] = true
		end
	elseif not multi and not reorder and options.Default ~= nil then
		picked[options.Default] = true
	end

	local below = row.belowTitle()
	Create.list(below, "Vertical", 6)
	local search
	if options.Search then
		search = Create.new("TextBox", {
			Name = "Search",
			Size = UDim2.new(1, 0, 0, 30),
			PlaceholderText = "Filter",
			TextSize = 13,
			ClearTextOnFocus = false,
			Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text" },
			Parent = below,
		})
		Create.corner(8, search)
		Create.padding(search, 10, 0)
	end
	local box = Create.new("ScrollingFrame", {
		Name = "Items",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		ScrollBarThickness = 3,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = below,
	})
	Create.corner(8, box)
	local inner = Create.new("Frame", { Name = "Inner", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = box })
	Create.padding(inner, 4)
	Create.fitHeight(box, inner, math.clamp(tonumber(options.Height) or 200, 80, 480), row.library, scope)
	Create.list(inner, "Vertical", 2)

	local items = {}

	local function current()
		if reorder then
			local ordered = {}
			for _, item in items do
				table.insert(ordered, item.value)
			end
			return ordered
		elseif multi then
			return Options.ordered(plain, picked)
		end
		return (next(picked))
	end

	local function paint()
		for index, item in items do
			item.button.LayoutOrder = index
			if not reorder then
				local on = picked[item.value] == true
				Theme.bind(item.button, "BackgroundColor3", if on then "accent" else "hover")
				item.button.BackgroundTransparency = if on then 0.86 else 1
				item.mark.Visible = on
			end
		end
	end

	local function changed()
		paint()
		row.fire(current())
	end

	local function filter()
		local query = if search then string.lower(search.Text) else ""
		for _, item in items do
			item.button.Visible = query == "" or string.find(string.lower(item.text), query, 1, true) ~= nil
		end
	end

	for index, entry in values do
		local button = Create.new("TextButton", {
			Name = "Item",
			Size = UDim2.new(1, 0, 0, itemHeight),
			LayoutOrder = index,
			BackgroundTransparency = 1,
			Theme = { BackgroundColor3 = "hover" },
			Parent = inner,
		})
		Create.corner(6, button)
		Create.padding(button, 10, 0, 8, 0)
		Create.list(button, "Horizontal", 10, { VerticalAlignment = Enum.VerticalAlignment.Center })
		local grip
		if reorder then
			grip = Create.new("Frame", { Name = "Grip", Size = UDim2.fromOffset(18, itemHeight), Parent = button })
			local glyph = Create.icon("grip-vertical", 14, "textMuted", grip)
			glyph.AnchorPoint, glyph.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		end
		if entry.icon then
			Create.icon(entry.icon, 15, "textMuted", button).LayoutOrder = 1
		end
		local text = Create.new("TextLabel", {
			Name = "Text",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 13,
			LayoutOrder = 2,
			Text = entry.text .. (if entry.description then `  <font transparency="0.45" size="12">{entry.description}</font>` else ""),
			RichText = entry.description ~= nil,
			Theme = { TextColor3 = "text" },
			Parent = button,
		}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
		text.TextTruncate = Enum.TextTruncate.AtEnd
		local mark = Create.icon("check", 14, "accent", button)
		mark.LayoutOrder = 3
		mark.Visible = false
		if reorder then
			mark:Destroy()
		end
		local item = { button = button, value = entry.value, text = entry.text, mark = mark }
		table.insert(items, item)
		if reorder then
			-- Dragging the grip moves the item; it takes the place under the pointer.
			Drag.track(scope, grip, function()
				Motion.tween(button, "fast", { BackgroundTransparency = 0.6 })
				return true
			end, function(position)
				local top = inner.AbsolutePosition.Y
				local slot = math.clamp(math.floor((position.Y - top) / ((itemHeight + 2) * row.library.scale)) + 1, 1, #items)
				local from = table.find(items, item)
				if from and slot ~= from then
					table.remove(items, from)
					table.insert(items, slot, item)
					paint()
				end
			end, function()
				Motion.tween(button, "fast", { BackgroundTransparency = 1 })
				changed()
			end)
		else
			scope:connect(button.Activated, function()
				if multi then
					picked[entry.value] = if picked[entry.value] then nil else true
				else
					local was = picked[entry.value]
					table.clear(picked)
					if not (was and options.AllowNone) then
						picked[entry.value] = true
					end
				end
				changed()
			end)
			row.onHover(function(on)
				if not picked[entry.value] then
					button.BackgroundTransparency = if on then 0.5 else 1
				end
			end, button)
		end
	end
	if search then
		scope:connect(search:GetPropertyChangedSignal("Text"), filter)
	end

	function handle:Get()
		return current()
	end

	function handle:Set(value)
		if reorder then
			local ordered = {}
			for _, wanted in if type(value) == "table" then value else {} do
				for _, item in items do
					if item.value == wanted and not table.find(ordered, item) then
						table.insert(ordered, item)
					end
				end
			end
			for _, item in items do
				if not table.find(ordered, item) then
					table.insert(ordered, item)
				end
			end
			items = ordered
		else
			table.clear(picked)
			if multi then
				for _, wanted in if type(value) == "table" then value else {} do
					picked[wanted] = true
				end
			elseif value ~= nil then
				picked[value] = true
			end
		end
		changed()
	end

	local words = {}
	for _, entry in values do
		table.insert(words, entry.text)
	end
	handle.SearchExtra = table.concat(words, " ")
	paint()
	return handle
end

return List
