-- The timings for the whole library. With `reduced` on, every change is
-- applied at once and nothing animates.

local TweenService = game:GetService("TweenService")

local TIMINGS = {
	fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	base = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	slow = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	-- Overshoots a little before settling, for a thumb or a tick landing.
	spring = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local Motion = { reduced = false }

-- A nil timing applies the goals at once, for the first draw of a control.
function Motion.tween(instance, timing, goals)
	if Motion.reduced or not timing then
		for property, value in goals do
			instance[property] = value
		end
		return nil
	end
	local tween = TweenService:Create(instance, TIMINGS[timing], goals)
	tween:Play()
	return tween
end

return Motion
