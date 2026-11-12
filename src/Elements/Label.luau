local Create = require("../Core/Create")
local Icons = require("../Core/Icons")
local Row = require("./Row")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

-- Label looks (kind "Label"). Plain is one quiet line; the others are
-- callouts tinted by a status role, with an icon so the meaning does not
-- rest on colour.
Styles.register("Label", "Plain", {})
Styles.register("Label", "Info", { role = "info", icon = "info" })
Styles.register("Label", "Success", { role = "success", icon = "circle-check" })
Styles.register("Label", "Warning", { role = "warning", icon = "triangle-alert" })
Styles.register("Label", "Danger", { role = "danger", icon = "circle-x" })
Styles.register("Label", "Note", { role = "accent", icon = "sparkles" })

local Label = {}

-- One line of text between controls. Options: Title, Style, Icon (replaces
-- a callout's icon).
function Label.new(container, options)
	local row = Row.new(container, options, { bare = true, compact = true })
	local handle = row.handle
	local look = Styles.pick("Label", options.Style, row.window)
	local parent = row.content

	if look.role then
		local box = Create.new("Frame", {
			Name = "Callout",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0.88,
			Theme = { BackgroundColor3 = look.role },
			Parent = row.content,
		})
		Create.corner(8, box)
		local edge = Create.stroke(look.role, box)
		edge.Transparency = 0.6
		Create.padding(box, 10, 8)
		Create.list(box, "Horizontal", 8, { VerticalAlignment = Enum.VerticalAlignment.Top })
		Create.icon(options.Icon or look.icon, 16, look.role, box)
		parent = box
	end

	local text = Create.new("TextLabel", {
		Name = "Label",
		Size = UDim2.new(if look.role then 0 else 1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		RichText = true,
		TextSize = 13,
		LayoutOrder = 1,
		Text = options.Title,
		Theme = { TextColor3 = if look.role then "text" else "textMuted" },
		Parent = parent,
	})
	if look.role then
		Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = text })
	end

	function handle:SetTitle(newText)
		self.Title = newText
		text.Text = newText
		self.SearchText = string.lower(newText)
	end

	-- Changes the callout's look after creation: "Info", "Warning" and so on.
	function handle:SetKind(name)
		local chosen = Styles.get("Label", name)
		if chosen and chosen.role and look.role then
			Theme.bind(parent, "BackgroundColor3", chosen.role)
			Theme.bind(parent:FindFirstChildOfClass("UIStroke"), "Color", chosen.role)
			local icon = parent:FindFirstChild("Icon")
			if icon then
				Theme.bind(icon, "ImageColor3", chosen.role)
				Icons.apply(icon, options.Icon or chosen.icon)
			end
			look = chosen
		end
	end

	handle.Set = handle.SetTitle
	return handle
end

return Label
