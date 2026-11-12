-- The value bubble that follows a slider's knob while it is dragged, with
-- an arrow pointing at the knob. It lives in the overlay, so no scrolling
-- page or window edge can clip it.

local Create = require("../Core/Create")
local Mount = require("../Core/Mount")

-- corner: the bubble's radius (-1 rounds it fully). arrow: the pointer's
-- radius, or nil for no pointer.
local STYLES = {
	Rounded = { corner = 8, arrow = 2 },
	Sharp = { corner = 0, arrow = 0 },
	Pill = { corner = -1, arrow = 2 },
	Plain = { corner = 8 },
}
local KNOB_RADIUS = 7
local LIFT = 10
-- How far the bubble may hang past either end of the rail. Small enough to
-- stay clear of a value box beside the track, large enough that the arrow
-- still sits under the bubble when the knob is at an end.
local OVERHANG = 10
local MARGIN = 4

local SliderTooltip = { Styles = STYLES }

local function overlaps(left, top, right, bottom, other)
	local corner, extent = other.AbsolutePosition, other.AbsoluteSize
	return right > corner.X - MARGIN and left < corner.X + extent.X + MARGIN and bottom > corner.Y - MARGIN and top < corner.Y + extent.Y + MARGIN
end

function SliderTooltip.new(row, styleName)
	local library = row.library
	local style = STYLES[styleName] or STYLES.Rounded
	local overlay = Mount.overlay(library)
	local lift = if style.arrow then LIFT else 6

	-- The holder carries the position and the body carries the scale, as popups do.
	local holder = Create.new("Frame", { Name = "SliderTip", Visible = false, ZIndex = 5, Parent = overlay.popups })
	row.scope:add(holder)
	local scale = Create.new("UIScale", { Scale = library.scale })
	local body = Create.new("Frame", { Name = "Body", Parent = holder }, { scale })

	local arrow
	if style.arrow then
		-- A square turned on its corner; the bubble covers half of it.
		arrow = Create.new("Frame", {
			Name = "Arrow",
			Size = UDim2.fromOffset(9, 9),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			Theme = { BackgroundColor3 = "accent" },
			Parent = body,
		})
		if style.arrow > 0 then
			Create.corner(style.arrow, arrow)
		end
	end

	local bubble = Create.new("Frame", {
		Name = "Bubble",
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 2,
		Theme = { BackgroundColor3 = "accent" },
		Parent = body,
	})
	if style.corner ~= 0 then
		Create.corner(style.corner, bubble)
	end
	Create.padding(bubble, 8, 4)
	local label = Create.new("TextLabel", {
		Name = "Value",
		AutomaticSize = Enum.AutomaticSize.XY,
		TextSize = 12,
		Weight = "bold",
		Theme = { TextColor3 = "onAccent" },
		Parent = bubble,
	})

	local tip = { Frame = holder, style = styleName, above = true }

	function tip.destroy()
		row.scope:release(holder)
	end

	-- Places the bubble over the point `fraction` of the way along `rail`.
	-- The rail is measured instead of the knob, whose position is only
	-- updated on the next layout pass. The bubble never covers `avoid` (the
	-- slider's value box): it stays within the rail's ends, and drops below
	-- the knob when the box sits right above the track.
	function tip.show(rail, fraction, text, avoid)
		local factor = library.scale
		local origin = overlay.gui.AbsolutePosition
		local corner, extent = rail.AbsolutePosition, rail.AbsoluteSize
		local knobX, centre = corner.X + extent.X * fraction, corner.Y + extent.Y / 2
		scale.Scale = factor
		label.Text = text

		-- Before its first layout the bubble has no size; the text length is close enough.
		local size = bubble.AbsoluteSize
		if size.X <= 0 then
			size = Vector2.new((#text * 7 + 16) * factor, 24 * factor)
		end
		local half = size.X / 2
		local low, high = corner.X - OVERHANG * factor + half, corner.X + extent.X + OVERHANG * factor - half
		local bubbleX = if low <= high then math.clamp(knobX, low, high) else corner.X + extent.X / 2

		local reach = (KNOB_RADIUS + lift) * factor
		local above = true
		if avoid and overlaps(bubbleX - half, centre - reach - size.Y, bubbleX + half, centre - reach, avoid) then
			above = false
		end
		local direction = if above then -1 else 1
		tip.above = above

		holder.Position = UDim2.fromOffset(knobX - origin.X, centre + direction * KNOB_RADIUS * factor - origin.Y)
		bubble.AnchorPoint = Vector2.new(0.5, if above then 1 else 0)
		bubble.Position = UDim2.fromOffset((bubbleX - knobX) / factor, direction * lift)
		if arrow then
			arrow.Position = UDim2.fromOffset(0, direction * lift)
		end
		holder.Visible = true
	end

	function tip.hide()
		holder.Visible = false
	end

	return tip
end

return SliderTooltip
