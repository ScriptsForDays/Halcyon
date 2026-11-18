-- Landing on a row from search or the command palette: the page glides to
-- it, a light runs once round its border from the top centre, and a soft
-- accent glow and tint hold for a moment before fading. With reduced motion
-- the row just shows a steady outline for the same moment.
--
-- The effect is drawn on a frame laid over the row inside the page's
-- canvas, not inside the row: a row sizes itself to its children, and an
-- outline inside it would make it grow.

local TweenService = game:GetService("TweenService")

local Arc = require("../Core/Arc")
local Create = require("../Core/Create")
local Motion = require("../Core/Motion")

local SearchFocus = {}

-- Seconds: the light's run round the border, how long the glow holds, the fade.
local SWEEP_TIME, HOLD, FADE_TIME = 0.55, 1.3, 0.45
local SWEEP = TweenInfo.new(SWEEP_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function SearchFocus.reveal(window, tab, handle)
	local frame = handle and handle.Frame
	if not frame then
		return
	end
	-- Measured a moment after the tab opens: a page that was hidden reports
	-- stale positions until it has been laid out once.
	task.delay(0.05, function()
		local page = tab.page
		if not frame.Parent or not page.Parent then
			return
		end
		local scale = window.scale
		local top = (frame.AbsolutePosition.Y - page.AbsolutePosition.Y) / scale + page.CanvasPosition.Y
		local wanted = Vector2.new(0, math.max(top - 24, 0))
		if Motion.reduced then
			page.CanvasPosition = wanted
		else
			TweenService:Create(page, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { CanvasPosition = wanted }):Play()
		end

		if window.searchSpot then
			window.searchSpot:Destroy()
		end
		local left = (frame.AbsolutePosition.X - page.AbsolutePosition.X) / scale
		local size = frame.AbsoluteSize / scale
		local spot = Create.new("Frame", {
			Name = "SearchSpot",
			Size = UDim2.fromOffset(size.X, size.Y),
			Position = UDim2.fromOffset(left, top),
			BackgroundTransparency = 1,
			ZIndex = 8,
			Theme = { BackgroundColor3 = "accent" },
			Parent = page,
		})
		window.searchSpot = spot
		Create.corner(8, spot)
		-- The glow: a wide, faint outline under the sharp one.
		local glow = Create.new("UIStroke", { Thickness = 4, Transparency = 1, Theme = { Color = "accent" }, Parent = spot })
		local arc = Arc.new(spot, { Thickness = 2, Role = "accent", Radius = 8, ZIndex = 9 })

		if Motion.reduced then
			arc:Set(1)
			glow.Transparency = 0.7
			task.delay(HOLD, function()
				spot:Destroy()
			end)
			return
		end
		arc:Set(0)
		local progress = Instance.new("NumberValue")
		progress.Parent = spot
		progress:GetPropertyChangedSignal("Value"):Connect(function()
			arc:Set(progress.Value)
		end)
		TweenService:Create(progress, SWEEP, { Value = 1 }):Play()
		TweenService:Create(glow, SWEEP, { Transparency = 0.72 }):Play()
		TweenService:Create(spot, SWEEP, { BackgroundTransparency = 0.9 }):Play()
		task.delay(SWEEP_TIME + HOLD, function()
			if not spot.Parent then
				return
			end
			TweenService:Create(glow, FADE, { Transparency = 1 }):Play()
			TweenService:Create(spot, FADE, { BackgroundTransparency = 1 }):Play()
			for _, stroke in arc.strokes do
				TweenService:Create(stroke, FADE, { Transparency = 1 }):Play()
			end
			task.delay(FADE_TIME, function()
				spot:Destroy()
				if window.searchSpot == spot then
					window.searchSpot = nil
				end
			end)
		end)
	end)
end

return SearchFocus
