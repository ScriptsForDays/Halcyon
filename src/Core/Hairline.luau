-- Divider lines.
--
-- A 1 px Frame lands on a fractional pixel as soon as display scaling or a
-- UIScale is involved, and Roblox then draws it 1 or 2 pixels thick
-- depending on where it falls. Measured in Studio at 125 % display scaling,
-- a UIStroke round a zero-thickness frame kept one weight at every position
-- and at UI scales from 0.9 to 1.25, where the plain frame alternated.
-- A UIScale also scales stroke thickness, so the thickness is divided by
-- the interface scale to keep every line the same weight at any scale.

local Create = require("./Create")

local Hairline = { scale = 1, strokes = {} }

-- axis "X" runs across the parent (a horizontal line), "Y" down it.
-- `properties` may set Name, Position, AnchorPoint, Size, LayoutOrder,
-- ZIndex, Visible and Parent.
function Hairline.new(axis, role, properties)
	local settings = {
		Name = "Seam",
		Size = if axis == "Y" then UDim2.new(0, 0, 1, 0) else UDim2.new(1, 0, 0, 0),
	}
	for key, value in properties or {} do
		settings[key] = value
	end
	local frame = Create.new("Frame", settings)
	local stroke = Create.new("UIStroke", {
		Thickness = 1 / Hairline.scale,
		-- Two pixels at reduced opacity read as one crisp line.
		Transparency = 0.35,
		Theme = { Color = role or "stroke" },
		Parent = frame,
	})
	Hairline.strokes[stroke] = true
	stroke.Destroying:Once(function()
		Hairline.strokes[stroke] = nil
	end)
	return frame
end

function Hairline.setScale(scale)
	Hairline.scale = scale
	for stroke in Hairline.strokes do
		stroke.Thickness = 1 / scale
	end
end

return Hairline
