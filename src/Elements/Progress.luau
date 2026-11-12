local Create = require("../Core/Create")
local Motion = require("../Core/Motion")
local Row = require("./Row")

local Progress = {}

-- A bar the hub fills as real work advances. Options: Value, Max, Suffix.
function Progress.new(container, options)
	local row = Row.new(container, options)
	local handle = row.handle
	local max = options.Max or 100
	local value = 0

	local readout = Create.new("TextLabel", {
		Name = "Value",
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 13,
		Theme = { TextColor3 = "textMuted" },
		Parent = row.slot,
	})
	local rail = Create.new("Frame", {
		Name = "Rail",
		Size = UDim2.new(1, 0, 0, 6),
		Theme = { BackgroundColor3 = "stroke" },
		Parent = row.belowTitle(),
	})
	Create.corner(-1, rail)
	local fill = Create.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		Theme = { BackgroundColor3 = "accent" },
		Parent = rail,
	})
	Create.corner(-1, fill)

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		value = math.clamp(tonumber(newValue) or 0, 0, max)
		local fraction = if max > 0 then value / max else 0
		readout.Text = if options.Suffix then tostring(value) .. options.Suffix else math.round(fraction * 100) .. "%"
		Motion.tween(fill, "base", { Size = UDim2.fromScale(fraction, 1) })
		self.Changed:Fire(value)
	end

	handle:Set(options.Value or 0)
	return handle
end

return Progress
