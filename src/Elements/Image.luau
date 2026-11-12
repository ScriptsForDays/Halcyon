local Create = require("../Core/Create")
local Icons = require("../Core/Icons")
local Row = require("./Row")

local Image = {}

-- A picture across the row. Options: Image (asset id, content string or icon
-- name), Height, Crop (fill the area instead of fitting inside it).
function Image.new(container, options)
	local row = Row.new(container, { Title = options.Title or "" }, { bare = true })
	local handle = row.handle
	local picture = Create.new("ImageLabel", {
		Name = "Image",
		Size = UDim2.new(1, 0, 0, options.Height or 140),
		ScaleType = if options.Crop then Enum.ScaleType.Crop else Enum.ScaleType.Fit,
		Theme = { BackgroundColor3 = row.controlRole },
		Parent = row.content,
	})
	Create.corner(8, picture)

	function handle:Set(image)
		Icons.apply(picture, image)
	end

	handle:Set(options.Image)
	return handle
end

return Image
