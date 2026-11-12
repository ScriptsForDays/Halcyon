-- Radio groups (one value) and checklists (several) drawn in the row,
-- under the title. Chips are the same choice drawn as wrapping pills.
--
-- Options: Values (see Options.luau), Default, Inline (options flow side by
-- side instead of one per line), SelectAll (checklists: a first option that
-- picks or clears them all). The value is one entry, or an array in Values
-- order for a checklist or Multi chips.

local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Options = require("./Options")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Choices = {}

local function build(container, options, mode)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local multi = mode == "checklist" or (mode == "chips" and options.Multi == true)
	local entries, values = Options.entries(options.Values)
	local picked = {}
	local items = {}
	local chips = mode == "chips"

	local area = row.belowTitle()
	if chips or options.Inline then
		Create.list(area, "Horizontal", if chips then 6 else 14, { Wraps = true, VerticalAlignment = Enum.VerticalAlignment.Top })
	else
		Create.list(area, "Vertical", 2)
	end
	local height = if row.library.touch then 40 else (if chips then 28 else 30)

	local function draw(timing)
		for _, item in items do
			local on = if item.all then #Options.ordered(values, picked) == #values else picked[item.value] == true
			local some = item.all and not on and next(picked) ~= nil
			if chips then
				Theme.bind(item.button, "BackgroundColor3", if on then "accent" else row.controlRole)
				Theme.bind(item.label, "TextColor3", if on then "onAccent" else "text")
				Theme.bind(item.edge, "Color", if on then "accent" else "stroke")
			else
				Theme.bind(item.edge, "Color", if on or some then "accent" else "stroke")
				Theme.bind(item.mark, "BackgroundColor3", "accent")
				Motion.tween(item.mark, timing, { BackgroundTransparency = if multi and (on or some) then 0 else 1 })
				local size = if multi then (if on then 12 else 0) else (if on then 8 else 0)
				Motion.tween(item.glyph, if timing and on then "spring" else timing, { Size = UDim2.fromOffset(size, size) })
				if item.bar then
					item.bar.Visible = some
				end
				item.label.FontFace = Create.font(if on then "medium" else "regular")
			end
		end
	end

	local function store(value)
		Options.pick(values, picked, value, multi)
		draw("fast")
	end

	function handle:Get()
		local list = Options.ordered(values, picked)
		return if multi then list else list[1]
	end

	function handle:Set(value)
		store(value)
		row.fire(self:Get())
	end

	local function press(item)
		if item.disabled then
			return
		end
		if item.all then
			local everything = #Options.ordered(values, picked) == #values
			handle:Set(if everything then {} else table.clone(values))
		elseif multi then
			local chosen = Options.ordered(values, picked)
			local found = table.find(chosen, item.value)
			if found then
				table.remove(chosen, found)
			else
				table.insert(chosen, item.value)
			end
			handle:Set(chosen)
		else
			handle:Set(if picked[item.value] and options.AllowNone then nil else item.value)
		end
	end

	local function addItem(entry, order, all)
		local button = Create.new("TextButton", {
			Name = "Option",
			Size = if chips then UDim2.fromOffset(0, height) elseif options.Inline then UDim2.fromOffset(0, height) else UDim2.new(1, 0, 0, height),
			AutomaticSize = if chips or options.Inline then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
			LayoutOrder = order,
			BackgroundTransparency = if chips then 0 else 1,
			Theme = { BackgroundColor3 = if chips then row.controlRole else "hover" },
			Parent = area,
		})
		local item = { button = button, value = entry.value, all = all, disabled = entry.disabled }
		if chips then
			Create.corner(-1, button)
			item.edge = Create.stroke("stroke", button)
			Create.padding(button, 12, 0)
			Create.list(button, "Horizontal", 6)
			if entry.icon then
				Create.icon(entry.icon, 14, "textMuted", button)
			end
		else
			Create.corner(6, button)
			Create.padding(button, if options.Inline then 0 else 6, 0)
			Create.list(button, "Horizontal", 10)
			local mark = Create.new("Frame", { Name = "Mark", Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Parent = button })
			Create.corner(if multi then 5 else -1, mark)
			item.mark = mark
			item.edge = Create.stroke("stroke", mark, 1.5)
			if multi then
				local check = Create.icon("check", 12, "onAccent", mark)
				check.AnchorPoint, check.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
				item.glyph = check
				if all then
					-- With only some options picked, "all" shows a bar instead of a tick.
					item.bar = Create.new("Frame", {
						Name = "Some",
						Size = UDim2.fromOffset(10, 2),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Visible = false,
						Theme = { BackgroundColor3 = "onAccent" },
						Parent = mark,
					})
				end
			else
				local dot = Create.new("Frame", { Name = "Dot", Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Theme = { BackgroundColor3 = "accent" }, Parent = mark })
				Create.corner(-1, dot)
				item.glyph = dot
			end
		end
		item.label = Create.new("TextLabel", {
			Name = "Text",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = entry.text,
			TextSize = 13,
			LayoutOrder = 2,
			Theme = { TextColor3 = if entry.disabled then "textMuted" else "text" },
			Parent = button,
		})
		if entry.description and not chips then
			item.label.Text = `{entry.text}  <font transparency="0.4" size="12">{entry.description}</font>`
			item.label.RichText = true
		end
		if not chips then
			scope:connect(button.MouseEnter, function()
				if not item.disabled then
					Motion.tween(button, "fast", { BackgroundTransparency = if options.Inline then 1 else 0.4 })
					Theme.bind(item.edge, "Color", "textMuted")
				end
			end)
			scope:connect(button.MouseLeave, function()
				Motion.tween(button, "fast", { BackgroundTransparency = 1 })
				draw("fast")
			end)
		end
		scope:connect(button.Activated, function()
			press(item)
		end)
		table.insert(items, item)
	end

	if mode == "checklist" and options.SelectAll then
		addItem({ text = if type(options.SelectAll) == "string" then options.SelectAll else "Select all" }, 0, true)
	end
	for index, entry in entries do
		if entry.heading == nil then
			addItem(entry, index, false)
		end
	end

	local default = options.Default
	if default == nil and not multi and not options.AllowNone then
		default = values[1]
	end
	Options.pick(values, picked, default, multi)
	draw(nil)
	return handle
end

function Choices.radio(container, options)
	return build(container, options, "radio")
end

function Choices.checklist(container, options)
	return build(container, options, "checklist")
end

function Choices.chips(container, options)
	return build(container, options, "chips")
end

return Choices
