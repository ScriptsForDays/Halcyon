local Create = require("../Core/Create")
local Hairline = require("../Core/Hairline")
local Icons = require("../Core/Icons")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Theme = require("../Core/Theme")

local ROW_HEIGHT = 28

local Table = {}

local function columnsFrom(list)
	local columns, shared, claimed = {}, 0, 0
	for index, raw in list or {} do
		local column = if type(raw) == "table" then raw else { Title = raw }
		columns[index] = { title = tostring(column.Title or ""), width = tonumber(column.Width), align = column.Align }
		if columns[index].width then
			claimed += columns[index].width
		else
			shared += 1
		end
	end
	-- Columns without a Width share what the others leave.
	local each = if shared > 0 then math.max(1 - claimed, 0) / shared else 0
	for _, column in columns do
		column.width = column.width or each
	end
	return columns
end

-- Rows and columns of text: server lists, item stats, logs.
-- Options: Title, Columns ({ "Name", { Title, Width (a share of the row,
-- 0 to 1), Align ("Left", "Center", "Right") } }), Rows ({ { cell, cell } }),
-- Sortable (default true: pressing a heading sorts by it), MaxHeight
-- (default 220; the body scrolls past it), Striped (default true).
function Table.new(container, options)
	local row = Row.new(container, { Title = options.Title or "", Description = options.Description }, { bare = options.Title == nil })
	local handle, scope = row.handle, row.scope
	local columns = columnsFrom(options.Columns)
	local rows = table.clone(options.Rows or {})
	local sortColumn, ascending = nil, true
	local bodyScope

	local frame = Create.new("Frame", {
		Name = "Table",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = row.content,
	})
	Create.corner(8, frame)
	Create.stroke("stroke", frame)
	Create.list(frame, "Vertical", 0)

	local function cell(parent, column, text, order, header)
		local label = Create.new("TextLabel", {
			Name = "Cell",
			Size = UDim2.new(column.width, 0, 1, 0),
			Text = text,
			TextSize = if header then 12 else 13,
			Weight = if header then "bold" else "regular",
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment[column.align or "Left"] or Enum.TextXAlignment.Left,
			LayoutOrder = order,
			Theme = { TextColor3 = if header then "textMuted" else "text" },
			Parent = parent,
		})
		Create.padding(label, 10, 0)
		return label
	end

	local head = Create.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, ROW_HEIGHT), Parent = frame })
	Create.list(head, "Horizontal", 0)
	local arrows = {}
	for index, column in columns do
		local button = Create.new("TextButton", {
			Name = "Heading",
			Size = UDim2.new(column.width, 0, 1, 0),
			LayoutOrder = index,
			Parent = head,
		})
		Create.list(button, "Horizontal", 2, {
			HorizontalAlignment = Enum.HorizontalAlignment[column.align or "Left"] or Enum.HorizontalAlignment.Left,
		})
		local label = cell(button, { width = 0 }, string.upper(column.title), 1, true)
		label.Size = UDim2.fromScale(0, 1)
		label.AutomaticSize = Enum.AutomaticSize.X
		local arrow = Create.icon("chevron-down", 12, "accent", button)
		arrow.LayoutOrder = 2
		arrow.Visible = false
		arrows[index] = arrow
		if options.Sortable ~= false then
			scope:connect(button.Activated, function()
				if sortColumn == index then
					ascending = not ascending
				else
					sortColumn, ascending = index, true
				end
				handle:Refresh()
			end)
		end
	end
	Hairline.new("X", "stroke", { LayoutOrder = 1, Parent = frame })

	local body = Create.new("ScrollingFrame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = frame,
	})
	Create.list(body, "Vertical", 0)
	local empty = Create.new("TextLabel", {
		Name = "Empty",
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT + 8),
		Text = options.EmptyText or Strings.get("Nothing to show yet"),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		Theme = { TextColor3 = "textMuted" },
		Parent = frame,
	})

	local function sorted()
		local list = table.clone(rows)
		if sortColumn then
			table.sort(list, function(a, b)
				local left, right = a[sortColumn], b[sortColumn]
				-- Numbers sort as numbers, everything else as text.
				local leftNumber, rightNumber = tonumber(left), tonumber(right)
				if leftNumber and rightNumber then
					if ascending then
						return leftNumber < rightNumber
					end
					return leftNumber > rightNumber
				end
				left, right = string.lower(tostring(left or "")), string.lower(tostring(right or ""))
				if ascending then
					return left < right
				end
				return left > right
			end)
		end
		return list
	end

	function handle:Refresh()
		if bodyScope then
			scope:release(bodyScope)
		end
		bodyScope = scope:child()
		for index, arrow in arrows do
			arrow.Visible = index == sortColumn
			Icons.apply(arrow, if ascending then "chevron-up" else "chevron-down")
		end
		local words = { options.Title or "" }
		for order, values in sorted() do
			local line = Create.new("Frame", {
				Name = "Line",
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				LayoutOrder = order,
				BackgroundTransparency = if options.Striped ~= false and order % 2 == 0 then 0.5 else 1,
				Theme = { BackgroundColor3 = "hover" },
				Parent = body,
			})
			bodyScope:add(line)
			Create.list(line, "Horizontal", 0)
			for index, column in columns do
				local text = tostring(if values[index] ~= nil then values[index] else "")
				cell(line, column, text, index, false)
				table.insert(words, text)
			end
		end
		local maxHeight = tonumber(options.MaxHeight) or 220
		body.Size = UDim2.new(1, 0, 0, math.min(#rows * ROW_HEIGHT, maxHeight))
		empty.Visible = #rows == 0
		self.SearchExtra = table.concat(words, " ")
		self.SearchText = string.lower(self.SearchExtra)
	end

	function handle:Get()
		return table.clone(rows)
	end

	function handle:SetRows(newRows)
		rows = table.clone(newRows or {})
		self:Refresh()
		self.Changed:Fire(self:Get())
	end
	handle.Set = handle.SetRows

	function handle:AddRow(values)
		table.insert(rows, values)
		self:Refresh()
	end

	function handle:Clear()
		self:SetRows({})
	end

	handle:Refresh()
	return handle
end

return Table
