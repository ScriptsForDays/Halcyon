local Create = require("../Core/Create")
local Row = require("./Row")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

-- Looks for a metric tile (kind "Stat"): Card sits on its own fill, Plain
-- on the section.
Styles.register("Stat", "Card", { fill = true })
Styles.register("Stat", "Plain", {})

local Stat = {}

-- The role a change line takes: up is good unless the hub says otherwise.
local function changeRole(text, kind)
	if kind then
		return ({ good = "success", bad = "danger", neutral = "textMuted", success = "success", danger = "danger", warning = "warning" })[kind]
			or "textMuted"
	end
	local first = string.sub(tostring(text or ""), 1, 1)
	return if first == "+" then "success" elseif first == "-" then "danger" else "textMuted"
end

-- One tile: label, value, unit and a change line. Returns its parts.
local function tile(parent, settings, look, order, controlRole)
	local frame = Create.new("Frame", {
		Name = "Stat",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		BackgroundTransparency = if look.fill then 0 else 1,
		Theme = { BackgroundColor3 = controlRole },
		Parent = parent,
	})
	Create.corner(8, frame)
	Create.padding(frame, if look.fill then 12 else 2, 10)
	Create.list(frame, "Vertical", 2)
	local head = Create.new("Frame", { Name = "Head", Size = UDim2.new(1, 0, 0, 16), Parent = frame })
	Create.list(head, "Horizontal", 6, { VerticalAlignment = Enum.VerticalAlignment.Center })
	if settings.Icon then
		Create.icon(settings.Icon, 13, "textMuted", head)
	end
	Create.fit(Create.new("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(0, 1),
		Text = settings.Title or "",
		TextSize = 12,
		Weight = "medium",
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = 1,
		Theme = { TextColor3 = "textMuted" },
		Parent = head,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) }), 10)
	local line = Create.new("Frame", { Name = "Line", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1, Parent = frame })
	Create.list(line, "Horizontal", 4, { VerticalAlignment = Enum.VerticalAlignment.Bottom })
	local value = Create.new("TextLabel", {
		Name = "Value",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = tostring(settings.Value or "0"),
		TextSize = 24,
		Weight = "bold",
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Theme = { TextColor3 = "text" },
		Parent = line,
	})
	local unit = Create.new("TextLabel", {
		Name = "Unit",
		Size = UDim2.new(0, 0, 1, -3),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = settings.Unit or "",
		TextSize = 13,
		LayoutOrder = 1,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Visible = (settings.Unit or "") ~= "",
		Theme = { TextColor3 = "textMuted" },
		Parent = line,
	})
	local change = Create.new("TextLabel", {
		Name = "Change",
		Size = UDim2.new(1, 0, 0, 16),
		Text = settings.Change or "",
		TextSize = 12,
		LayoutOrder = 2,
		Visible = (settings.Change or "") ~= "",
		Theme = { TextColor3 = changeRole(settings.Change, settings.Kind) },
		Parent = frame,
	})
	return { frame = frame, value = value, unit = unit, change = change }
end

local function setters(handle, parts)
	function handle:Set(value)
		parts.value.Text = tostring(value)
		handle.Value = value
		handle.Changed:Fire(value)
	end
	function handle:Get()
		return handle.Value
	end
	function handle:SetUnit(text)
		parts.unit.Text = tostring(text or "")
		parts.unit.Visible = parts.unit.Text ~= ""
	end
	-- "+12% this hour" turns green, "-3" red; Kind ("good", "bad",
	-- "neutral") says so outright.
	function handle:SetChange(text, kind)
		parts.change.Text = tostring(text or "")
		parts.change.Visible = parts.change.Text ~= ""
		Theme.bind(parts.change, "TextColor3", changeRole(text, kind))
	end
end

-- A single figure: Title (its label), Value, Unit, Change, Kind, Icon,
-- Style ("Card" or "Plain"). Set, SetUnit and SetChange update it live.
function Stat.new(container, options)
	local row = Row.new(container, options, { bare = true, compact = true })
	local handle = row.handle
	local look = Styles.pick("Stat", options.Style, row.window)
	local parts = tile(row.content, options, look, 1, row.controlRole)
	handle.Value = options.Value
	setters(handle, parts)
	return handle
end

-- Several figures side by side, wrapping onto more lines when narrow.
-- Items = { { Title, Value, Unit, Change, Kind, Icon, Key } }. Returns a
-- handle whose Set(key, value) and Get(key) reach each figure by its Key
-- (or Title), and whose Items[key] is that figure's own handle.
function Stat.group(container, options)
	local row = Row.new(container, options, { bare = true, compact = true })
	local handle, scope = row.handle, row.scope
	local look = Styles.pick("Stat", options.Style, row.window)
	local columns = math.clamp(math.floor(tonumber(options.Columns) or 3), 1, 4)
	local holder = Create.new("Frame", { Name = "Stats", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row.content })
	local layout = Create.list(holder, "Horizontal", 8, { Wraps = true })
	handle.Items = {}
	local frames = {}
	for order, settings in options.Items or {} do
		local parts = tile(holder, settings, look, order, row.controlRole)
		local item = { Changed = handle.Changed, Value = settings.Value }
		setters(item, parts)
		handle.Items[settings.Key or settings.Title or order] = item
		table.insert(frames, parts.frame)
	end
	-- As many to a line as fit at 96 px or more, up to Columns.
	local function fit()
		local width = holder.AbsoluteSize.X / row.library.scale
		if width <= 0 then
			return
		end
		local count = math.max(1, math.min(columns, math.floor((width + 8) / 104), #frames))
		for _, frame in frames do
			-- A pixel of slack each, so rounding never pushes the last tile onto a new line.
			frame.Size = UDim2.new(1 / count, -8 * (count - 1) / count - 1, 0, 0)
		end
	end
	scope:connect(holder:GetPropertyChangedSignal("AbsoluteSize"), fit)
	fit()
	layout.Padding = UDim.new(0, 8)

	function handle:Set(key, value)
		local item = handle.Items[key]
		if item then
			item:Set(value)
		end
	end
	function handle:Get(key)
		local item = handle.Items[key]
		return item and item:Get()
	end
	return handle
end

return Stat
