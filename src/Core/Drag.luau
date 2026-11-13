-- Pointer tracking for dragging windows, sliders and colour areas. Listeners
-- on UserInputService exist only while a press is held, so an idle UI costs
-- nothing per frame.

local UserInputService = game:GetService("UserInputService")

local TAP_DISTANCE = 6

local Drag = {}

local function isPress(input)
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

local function point(input)
	return Vector2.new(input.Position.X, input.Position.Y)
end

-- Follows one press on `surface` until it is released.
--   onStart(position) may return false to ignore the press
--   onMove(position, origin, moved) runs for every pointer move
--   onEnd(moved) runs once; `moved` is false for a tap
function Drag.track(scope, surface, onStart, onMove, onEnd)
	scope:connect(surface.InputBegan, function(input)
		if not isPress(input) then
			return
		end
		local origin = point(input)
		if onStart and onStart(origin) == false then
			return
		end

		local touch = input.UserInputType == Enum.UserInputType.Touch
		local session = scope:child()
		local moved = false

		session:connect(UserInputService.InputChanged, function(changed)
			if touch then
				if changed ~= input then
					return
				end
			elseif changed.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local position = point(changed)
			if (position - origin).Magnitude > TAP_DISTANCE then
				moved = true
			end
			onMove(position, origin, moved)
		end)

		session:connect(UserInputService.InputEnded, function(ended)
			if ended == input or (not touch and ended.UserInputType == Enum.UserInputType.MouseButton1) then
				scope:release(session)
				if onEnd then
					onEnd(moved)
				end
			end
		end)
	end)
end

-- Keeps `target` fully inside its parent.
function Drag.clamp(target, x, y)
	local size, bounds, anchor = target.AbsoluteSize, target.Parent.AbsoluteSize, target.AnchorPoint
	local minX, minY = size.X * anchor.X, size.Y * anchor.Y
	return math.clamp(x, minX, math.max(bounds.X - size.X * (1 - anchor.X), minX)), math.clamp(y, minY, math.max(bounds.Y - size.Y * (1 - anchor.Y), minY))
end

-- A press that never moved is a tap, so the same handle can both drag and
-- open something (options.onTap); options.onMoved runs after a real drag.
function Drag.move(scope, handle, target, options)
	local start = Vector2.zero
	Drag.track(scope, handle, function()
		-- `enabled` lets the owner lock the position for a while.
		if options.enabled and not options.enabled() then
			return false
		end
		start = target.AbsolutePosition - target.Parent.AbsolutePosition + target.AbsoluteSize * target.AnchorPoint
		return true
	end, function(position, origin, moved)
		if moved then
			local wanted = start + (position - origin)
			local x, y = Drag.clamp(target, wanted.X, wanted.Y)
			-- Snap the top-left corner to a whole pixel so edges stay crisp.
			local lead = target.AbsoluteSize * target.AnchorPoint
			target.Position = UDim2.fromOffset(math.round(x - lead.X) + lead.X, math.round(y - lead.Y) + lead.Y)
		end
	end, function(moved)
		local callback = if moved then options.onMoved else options.onTap
		if callback then
			callback()
		end
	end)
end

-- Reports a press and every move on `surface` as fractions, 0 to 1, of
-- `reference` (the surface itself unless a narrower track is given).
function Drag.area(scope, surface, onChange, onEnd, reference)
	reference = reference or surface
	local function report(position)
		local origin, size = reference.AbsolutePosition, reference.AbsoluteSize
		onChange(math.clamp((position.X - origin.X) / math.max(size.X, 1), 0, 1), math.clamp((position.Y - origin.Y) / math.max(size.Y, 1), 0, 1))
	end
	Drag.track(scope, surface, function(position)
		report(position)
		return true
	end, report, onEnd)
end

return Drag
