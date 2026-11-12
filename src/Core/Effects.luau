-- Animated finishes for buttons. Each draws on a layer of its own inside the
-- button, clipped to its rounded corners, so the button's own colours and
-- text are never touched.
--
--   Sweep   a band of light crosses the button on hover
--   Ripple  a circle spreads from the point that was pressed
--   Lift    the button grows a little on hover and sinks when pressed
--   Glow    an accent outline fades in on hover
--   None    nothing
--
-- With reduced motion on, every effect is skipped.

local Create = require("./Create")
local Motion = require("./Motion")

local TweenService = game:GetService("TweenService")

local SWEEP = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RIPPLE = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- One pass every few seconds, repeated by the engine: no Lua runs per frame.
local SHIMMER = TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 2.6)
local BAND_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.7),
	NumberSequenceKeypoint.new(1, 1),
})

local Effects = { Kinds = { Sweep = true, Ripple = true, Lift = true, Glow = true, None = true } }

-- The clipping layer, made once per button.
local function layer(button, radius)
	local existing = button:FindFirstChild("Effects")
	if existing then
		return existing
	end
	local group = Create.new("CanvasGroup", { Name = "Effects", Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = button })
	Create.corner(radius, group)
	return group
end

local function sweep(scope, button, radius)
	local band = Create.new("Frame", {
		Name = "Sweep",
		Size = UDim2.fromScale(0.45, 1),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(-0.3, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = layer(button, radius),
	}, { Create.new("UIGradient", { Transparency = BAND_FADE, Rotation = 0 }) })
	scope:connect(button.MouseEnter, function()
		if Motion.reduced then
			return
		end
		band.Position = UDim2.fromScale(-0.3, 0)
		TweenService:Create(band, SWEEP, { Position = UDim2.fromScale(1.3, 0) }):Play()
	end)
end

local function ripple(scope, button, radius)
	local group = layer(button, radius)
	scope:connect(button.InputBegan, function(input)
		local kind = input.UserInputType
		if Motion.reduced or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
			return
		end
		local origin, size = button.AbsolutePosition, button.AbsoluteSize
		local reach = math.max(size.X, size.Y) * 2.2
		local circle = Create.new("Frame", {
			Name = "Ripple",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(input.Position.X - origin.X, input.Position.Y - origin.Y),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.75,
			Parent = group,
		})
		Create.corner(-1, circle)
		local grow = TweenService:Create(circle, RIPPLE, { Size = UDim2.fromOffset(reach, reach), BackgroundTransparency = 1 })
		grow.Completed:Once(function()
			circle:Destroy()
		end)
		grow:Play()
	end)
end

local function lift(scope, button)
	local scale = button:FindFirstChildOfClass("UIScale") or Create.new("UIScale", { Parent = button })
	local hovered = false
	local function settle(target)
		Motion.tween(scale, "spring", { Scale = target })
	end
	scope:connect(button.MouseEnter, function()
		hovered = true
		settle(1.03)
	end)
	scope:connect(button.MouseLeave, function()
		hovered = false
		settle(1)
	end)
	scope:connect(button.MouseButton1Down, function()
		Motion.tween(scale, "fast", { Scale = 0.97 })
	end)
	scope:connect(button.MouseButton1Up, function()
		settle(if hovered then 1.03 else 1)
	end)
end

local function glow(scope, button)
	local stroke = Create.new("UIStroke", { Name = "Glow", Thickness = 1.5, Transparency = 1, Theme = { Color = "accentHover" }, Parent = button })
	scope:connect(button.MouseEnter, function()
		Motion.tween(stroke, "base", { Transparency = 0 })
	end)
	scope:connect(button.MouseLeave, function()
		Motion.tween(stroke, "base", { Transparency = 1 })
	end)
end

-- A light band that crosses `target` every few seconds, for locked rows and
-- sections. Returns start and stop; it starts stopped. The clipping layer
-- is made on the first start, so unlocked rows carry no CanvasGroup.
function Effects.shimmer(scope, target, radius)
	local band, tween
	local shimmer = {}
	function shimmer.start()
		if tween or Motion.reduced then
			return
		end
		band = band
			or Create.new("Frame", {
				Name = "Shimmer",
				Size = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.55,
				Parent = layer(target, radius),
			}, { Create.new("UIGradient", { Transparency = BAND_FADE, Rotation = 20 }) })
		band.Position = UDim2.fromScale(-0.4, 0)
		tween = TweenService:Create(band, SHIMMER, { Position = UDim2.fromScale(1.4, 0) })
		tween:Play()
	end
	function shimmer.stop()
		if tween then
			tween:Cancel()
			tween = nil
		end
		if band then
			band.Position = UDim2.fromScale(-0.4, 0)
		end
	end
	scope:add(shimmer.stop)
	return shimmer
end

-- Adds `kind` to `button`. `radius` matches the button's own corner so the
-- light never shows past its rounding.
function Effects.apply(scope, button, kind, radius)
	if kind == "Sweep" then
		sweep(scope, button, radius or 8)
	elseif kind == "Ripple" then
		ripple(scope, button, radius or 8)
	elseif kind == "Lift" then
		lift(scope, button)
	elseif kind == "Glow" then
		glow(scope, button)
	end
end

return Effects
