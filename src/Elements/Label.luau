local Create = require("../Core/Create")
local Row = require("./Row")

local Label = {}

-- One quiet line of text, for a note between controls.
function Label.new(container, options)
	local row = Row.new(container, options, { bare = true, compact = true })
	local handle = row.handle
	local text = Create.new("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = 13,
		Text = options.Title,
		Theme = { TextColor3 = "textMuted" },
		Parent = row.content,
	})

	function handle:SetTitle(newText)
		self.Title = newText
		text.Text = newText
		self.SearchText = string.lower(newText)
	end

	handle.Set = handle.SetTitle
	return handle
end

return Label
