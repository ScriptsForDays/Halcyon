local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Segmented = {}

-- A few mutually exclusive modes shown side by side. Options: Values,
-- Default, Stacked (full width under the title, for longer labels).
function Segmented.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local values = options.Values or {}
	local value = if table.find(values, options.Default) then options.Default else values[1]
	local segments = {}

	local group = Create.new("Frame", { Name = "Segments", Theme = { BackgroundColor3 = row.controlRole } })
	Create.corner(8, group)
	Create.padding(group, 2)
	Create.list(group, "Horizontal", 2)

	local function draw(timing)
		for _, segment in segments do
			local on = segment.value == value
			Theme.bind(segment.button, "TextColor3", if on then "onAccent" else "textMuted", true)
			Motion.tween(segment.button, timing, {
				BackgroundTransparency = if on then 0 else 1,
				TextColor3 = Theme.color(if on then "onAccent" else "textMuted"),
			})
			segment.button.FontFace = Create.font(if on then "bold" else "medium")
		end
	end

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		if table.find(values, newValue) then
			value = newValue
			draw("fast")
			row.fire(value)
		end
	end

	for index, item in values do
		local button = Create.new("TextButton", {
			Name = "Segment",
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = index,
			Text = tostring(item),
			TextSize = 13,
			Theme = { BackgroundColor3 = "accent", TextColor3 = "textMuted" },
			Parent = group,
		})
		Create.corner(6, button)
		Create.padding(button, 12, 0)
		segments[index] = { button = button, value = item, flex = Create.new("UIFlexItem", { Parent = button }) }
		scope:connect(button.Activated, function()
			handle:Set(item)
		end)
	end

	-- Beside the title the segments hug their labels; under it they share
	-- the full width. A row too narrow for both stacks on its own.
	local below
	local function place(stacked)
		if stacked then
			below = below or row.belowTitle()
			below.Visible = true
		elseif below then
			below.Visible = false
		end
		group.Size = if stacked then UDim2.new(1, 0, 0, row.reach + 4) else UDim2.fromOffset(0, row.reach + 4)
		group.AutomaticSize = if stacked then Enum.AutomaticSize.None else Enum.AutomaticSize.X
		for _, segment in segments do
			segment.button.AutomaticSize = if stacked then Enum.AutomaticSize.None else Enum.AutomaticSize.X
			segment.flex.FlexMode = if stacked then Enum.UIFlexMode.Fill else Enum.UIFlexMode.None
		end
		group.Parent = if stacked then below else row.slot
	end
	place(options.Stacked == true)
	if not options.Stacked then
		row.onNarrow(place)
	end

	draw(nil)
	return handle
end

return Segmented
