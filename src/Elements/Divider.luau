local Create = require("../Core/Create")
local Row = require("./Row")

local Divider = {}

-- A hairline between groups of rows, with an optional caption on the left.
function Divider.new(container, options)
	local row = Row.new(container, { Title = options.Title or "" }, { bare = true, compact = true })
	local line = Create.new("Frame", { Name = "Divider", Size = UDim2.new(1, 0, 0, 16), Parent = row.content })
	Create.list(line, "Horizontal", 8)
	if options.Title then
		Create.new("TextLabel", {
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = options.Title,
			TextSize = 12,
			Weight = "medium",
			Theme = { TextColor3 = "textMuted" },
			Parent = line,
		})
	end
	Create.new("Frame", { Size = UDim2.fromOffset(0, 1), LayoutOrder = 1, Theme = { BackgroundColor3 = "stroke" }, Parent = line }, {
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
	})
	return row.handle
end

return Divider
