local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Row = require("./Row")
local Styles = require("../Core/Styles")

local Paragraph = {}

-- A title with wrapped text under it. Options: Title, Content (rich text
-- allowed), Icon, Image (a picture beside the text; ImageSize, default 48),
-- Buttons ({ { Title, Variant, Callback } } under the text).
function Paragraph.new(container, options)
	local row = Row.new(container, { Title = options.Title, Description = options.Content, Icon = options.Icon })
	local handle = row.handle

	local description = row.titleBlock and row.titleBlock:FindFirstChild("Description")
	if description then
		description.RichText = true
	end

	if options.Image then
		local size = tonumber(options.ImageSize) or 48
		local picture = Create.new("ImageLabel", {
			Name = "Picture",
			Size = UDim2.fromOffset(size, size),
			Image = tostring(options.Image),
			ScaleType = Enum.ScaleType.Crop,
			LayoutOrder = -1,
			Parent = row.titleBlock.Parent,
		})
		Create.corner(8, picture)
	end

	if type(options.Buttons) == "table" then
		local line = row.belowTitle()
		Create.list(line, "Horizontal", 8)
		for index, spec in options.Buttons do
			local look = Styles.get("Button", spec.Variant or "Soft") or Styles.get("Button", "Soft")
			if look.row then
				look = Styles.get("Button", "Soft")
			end
			local button = Create.new("TextButton", {
				Name = "Button",
				Size = UDim2.fromOffset(0, 28),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = tostring(spec.Title or ""),
				TextSize = 13,
				Weight = "medium",
				LayoutOrder = index,
				BackgroundTransparency = look.fillTransparency or 0,
				Theme = { BackgroundColor3 = look.fill, TextColor3 = look.text },
				Parent = line,
			})
			Create.corner(6, button)
			Create.padding(button, 12, 0)
			if look.stroke then
				Create.stroke(look.stroke, button)
			end
			row.scope:connect(button.Activated, function()
				Env.call(tostring(spec.Title), spec.Callback)
			end)
		end
	end

	-- Set({ Title = ..., Content = ... }) or Set("content").
	function handle:Set(value)
		if type(value) == "table" then
			if value.Title then
				self:SetTitle(value.Title)
			end
			self:SetDescription(value.Content)
		else
			self:SetDescription(tostring(value))
		end
	end

	return handle
end

return Paragraph
