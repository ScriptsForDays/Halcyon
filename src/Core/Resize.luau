-- A corner grip that resizes a panel whose top-left corner stays put, so the
-- bottom-right corner moves exactly with the pointer. Used by the window and
-- by popped-out sections.

local Drag = require("./Drag")

local Resize = {}

-- `begin()` returns nil to ignore the press, or a table:
--   size   the size shown now, before scaling
--   scale  the UIScale on the panel
--   min    the smallest size allowed
--   max    the largest size that still fits on screen
-- `apply(size)` runs for every move with a whole-pixel size; `done()` on release.
function Resize.grip(scope, grip, begin, apply, done)
	local from
	Drag.track(scope, grip, function()
		from = begin()
		return from ~= nil
	end, function(position, origin)
		local wanted = from.size + (position - origin) / from.scale
		local high = Vector2.new(math.max(from.max.X, from.min.X), math.max(from.max.Y, from.min.Y))
		apply(Vector2.new(math.round(math.clamp(wanted.X, from.min.X, high.X)), math.round(math.clamp(wanted.Y, from.min.Y, high.Y))))
	end, function()
		if done then
			done()
		end
	end)
end

return Resize
