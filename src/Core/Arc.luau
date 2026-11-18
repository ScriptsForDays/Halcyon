-- An outline that shows only part of itself, clockwise from the top centre:
-- a countdown running around a card's border, a progress ring, a gauge.
--
-- The outline is a UIStroke on a frame shaped like the card (same corner
-- radius), drawn twice, once in each half of the card. Each half clips its
-- copy and a UIGradient with a hard step hides one side of a line through
-- the centre; turning the gradient sweeps that line round. No images are
-- needed and rounded corners stay exact.
--
--   local arc = Arc.new(card, { Thickness = 2, Role = "accent", Radius = 12 })
--   arc:Set(0.6)

local Create = require("./Create")
local Theme = require("./Theme")

local Arc = {}
Arc.__index = Arc

local STEP = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.5001, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- Options: Thickness [2], Role ["accent"] (or Color), Radius (corner in
-- pixels; -1 for a circle) [0], ZIndex, Transparency [0], Even (the shown
-- part grows at the same speed along every edge) [true unless a circle].
function Arc.new(parent, options)
	options = options or {}
	local thickness = options.Thickness or 2
	local radius = options.Radius or 0
	local self = setmetatable({ parent = parent, thickness = thickness, fraction = 1 }, Arc)
	self.even = if options.Even ~= nil then options.Even else radius >= 0

	-- Nothing here may reach past the parent: a parent that sizes itself to
	-- its descendants (AutomaticSize) would grow to fit and never stop. So
	-- the halves are exactly half the parent, and the shape is inset by the
	-- stroke's width; a UIStroke draws outside its frame, which puts the
	-- outline's outer edge on the parent's edge.
	self.frame = Create.new("Frame", {
		Name = "Arc",
		Size = UDim2.fromScale(1, 1),
		ZIndex = options.ZIndex,
		Parent = parent,
	})
	self.strokes, self.gradients = {}, {}
	for index, left in { false, true } do
		local clip = Create.new("Frame", {
			Name = if left then "Left" else "Right",
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(if left then 0 else 0.5, 0),
			ClipsDescendants = true,
			ZIndex = options.ZIndex,
			Parent = self.frame,
		})
		local shape = Create.new("Frame", {
			Name = "Shape",
			Size = UDim2.new(2, -2 * thickness, 1, -2 * thickness),
			Position = if left then UDim2.fromOffset(thickness, thickness) else UDim2.new(-1, thickness, 0, thickness),
			ZIndex = options.ZIndex,
			Parent = clip,
		})
		Create.new("UICorner", {
			CornerRadius = if radius < 0 then UDim.new(1, 0) else UDim.new(0, math.max(radius - thickness, 0)),
			Parent = shape,
		})
		local stroke = Create.new("UIStroke", {
			Thickness = thickness,
			Transparency = options.Transparency or 0,
			Theme = if options.Color then nil else { Color = options.Role or "accent" },
			Parent = shape,
		})
		if options.Color then
			stroke.Color = options.Color
		end
		self.strokes[index] = stroke
		self.gradients[index] = Create.new("UIGradient", { Transparency = STEP, Parent = stroke })
	end
	self:Set(1)
	return self
end

-- The gradient angle, in the card's own stretched space, at which `fraction`
-- of the outline's length (walking clockwise from the top centre) is shown.
local function evenAngle(fraction, width, height)
	local perimeter = 2 * (width + height)
	local walked = fraction * perimeter
	-- Points along the edge, measured from the centre.
	local x, y
	local halfWidth, halfHeight = width / 2, height / 2
	if walked <= halfWidth then
		x, y = walked, -halfHeight
	elseif walked <= halfWidth + height then
		x, y = halfWidth, -halfHeight + (walked - halfWidth)
	elseif walked <= halfWidth + height + width then
		x, y = halfWidth - (walked - halfWidth - height), halfHeight
	elseif walked <= halfWidth + 2 * height + width then
		x, y = -halfWidth, halfHeight - (walked - halfWidth - height - width)
	else
		x, y = -halfWidth + (walked - halfWidth - 2 * height - width), -halfHeight
	end
	-- A gradient turns in the frame's 0-1 space, so a wide card is a square to it.
	local angle = math.deg(math.atan2(x / width, -y / height))
	if angle < 0 then
		angle += 360
	end
	if fraction >= 1 then
		return 360
	end
	return angle
end

-- Shows `fraction` (0 to 1) of the outline.
function Arc:Set(fraction)
	fraction = math.clamp(fraction, 0, 1)
	self.fraction = fraction
	local angle = fraction * 360
	local size = self.parent.AbsoluteSize
	if self.even and size.X > 0 and size.Y > 0 and fraction > 0 and fraction < 1 then
		angle = evenAngle(fraction, size.X, size.Y)
	end
	self.gradients[1].Rotation = math.min(angle, 180)
	self.gradients[2].Rotation = 180 + math.max(angle - 180, 0)
end

function Arc:Get()
	return self.fraction
end

function Arc:SetRole(role)
	for _, stroke in self.strokes do
		Theme.bind(stroke, "Color", role)
	end
end

function Arc:SetColor(color)
	for _, stroke in self.strokes do
		Theme.unbind(stroke, "Color")
		stroke.Color = color
	end
end

function Arc:SetVisible(visible)
	self.frame.Visible = visible
end

function Arc:Destroy()
	self.frame:Destroy()
end

return Arc
