-- Moving backgrounds for the window and for sections. Motion comes from
-- repeating tweens, so no Lua runs per frame; the tweens pause while the
-- surface is hidden, and with reduced motion the background holds still.
--
--   Background = { Kind = "Aurora", Colors = { "accent", "info" }, Speed = 1, Intensity = 0.5, Sheen = true }
--
-- Kinds:
--   Aurora    fields of colour drifting and breathing behind the content
--   Glow      a soft light that follows the pointer across the surface
--   Gradient  a slowly turning blend of the colours
--   Mesh      two blends turning against each other
--   Pattern   fine diagonal lines sliding across
--   Image     a picture that slowly fades a little in and out (Image = any image source)
-- Any kind also takes Sheen (a band of light crossing every few seconds) and
-- Vignette (shaded edges that draw the eye inward; on by default behind the
-- window). Colors are theme roles or Color3s; Speed scales every motion (2
-- is twice as fast); Intensity 0-1 is how strongly it shows.
--
-- A section sizes itself to its children, and Roblox counts every
-- scale-sized piece below such a frame as wanting more room, so the section
-- would stretch to the screen. So the layer itself is the only scale-sized
-- piece: Gradient and Pattern draw on it directly, and everything else is
-- sized in pixels measured from it, laid out again only when its size
-- changes. Inside a section the pieces also stay within the layer; behind
-- the window, which has a fixed size, they may drift past its edges.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Create = require("./Create")
local Icons = require("./Icons")
local Motion = require("./Motion")
local Theme = require("./Theme")

local Background = {}

local KINDS = { Aurora = true, Glow = true, Gradient = true, Mesh = true, Pattern = true, Image = true }
-- A soft-edged square (the window shadow's image), stretched into a field of light.
local BLOB = "rbxassetid://8992230677"
local PATTERN_BANDS = 15
-- Seconds between two passes of the sheen, and how long one pass takes.
local SHEEN_GAP, SHEEN_PASS = 0.8, 2.4

-- The accent turned round the colour wheel: a neighbouring hue that sits
-- well beside it in every theme.
local function neighbour(turn)
	return function()
		local ok, h, s, v = pcall(function()
			return Theme.color("accent"):ToHSV()
		end)
		if not ok then
			return Theme.color("info")
		end
		return Color3.fromHSV((h + turn) % 1, math.min(s * 1.05, 1), v)
	end
end

local DEFAULT_COLOURS = { "accent", neighbour(0.09), "info", neighbour(-0.07) }

local function colourOf(entry)
	if typeof(entry) == "Color3" then
		return entry
	elseif type(entry) == "function" then
		return entry()
	end
	return Theme.color(if type(entry) == "string" then entry else "accent")
end

local function sequence(colours)
	local keypoints = {}
	for index, colour in colours do
		table.insert(keypoints, ColorSequenceKeypoint.new(if #colours == 1 then 0 else (index - 1) / (#colours - 1), colour))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colours[1]))
	end
	return ColorSequence.new(keypoints)
end

-- Builds a background inside `parent`. `defaults` may give Intensity,
-- Radius, Scale (a function returning the UIScale above the parent),
-- Contained (keep every piece inside the layer), Vignette and Measure (the
-- object whose size the pieces fill; the layer itself by default).
-- Returns { frame, Kind, SetVisible(bool), MeasureFrom(object), Destroy() },
-- or nil for none.
function Background.new(parent, spec, defaults)
	if spec == nil or spec == false then
		return nil
	end
	if type(spec) == "string" then
		spec = { Kind = spec }
	end
	if type(spec) ~= "table" then
		return nil
	end
	defaults = defaults or {}
	local kind = if KINDS[spec.Kind] then spec.Kind else "Aurora"
	local speed = math.clamp(tonumber(spec.Speed) or 1, 0.1, 5)
	local intensity = math.clamp(tonumber(spec.Intensity) or defaults.Intensity or 0.5, 0, 1)
	local colours = if type(spec.Colors) == "table" and #spec.Colors > 0 then spec.Colors else DEFAULT_COLOURS
	local contained = defaults.Contained == true
	local vignette = if spec.Vignette ~= nil then spec.Vignette == true else defaults.Vignette == true

	local frame = Create.new("CanvasGroup", {
		Name = "MovingBackground",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		GroupTransparency = 1 - intensity,
		Parent = parent,
	})
	Create.corner(defaults.Radius or 12, frame)
	local painters, connections = {}, {}
	-- Tweens that never change, and tweens rebuilt with each new size.
	local fixed, sized = {}, {}
	local running = false
	local box = Vector2.zero
	-- Inside a parent that sizes itself to its children, the pieces count as
	-- children too, so measuring the layer would let them hold the parent at
	-- an old, larger size. Such parents pass the frame their content sits in.
	local measured = defaults.Measure or frame
	local measuring

	local function loop(list, target, seconds, goals, style, delay)
		local linear = style == Enum.EasingStyle.Linear
		local timing = TweenInfo.new(seconds / speed, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, not linear and not delay, delay and delay / speed or 0)
		local tween = TweenService:Create(target, timing, goals)
		table.insert(list, tween)
		if running then
			tween:Play()
		end
		return tween
	end

	-- Pieces placed in pixels: { instance, size, from, to, time } with size
	-- and positions as shares of the layer, centred on the position.
	local pieces = {}
	local function at(piece, share)
		local size = piece.pixels
		local x, y = math.floor(box.X * share.X - size.X / 2), math.floor(box.Y * share.Y - size.Y / 2)
		if contained then
			x, y = math.clamp(x, 0, box.X - size.X), math.clamp(y, 0, box.Y - size.Y)
		end
		return UDim2.fromOffset(x, y)
	end
	local function placePieces()
		for _, tween in sized do
			tween:Cancel()
		end
		table.clear(sized)
		local scale = if defaults.Scale then defaults.Scale() else 1
		local size = measured.AbsoluteSize / math.max(scale, 0.01)
		box = Vector2.new(math.floor(size.X), math.floor(size.Y))
		if box.X <= 0 or box.Y <= 0 then
			return
		end
		for _, piece in pieces do
			local size = Vector2.new(math.floor(box.X * piece.size.X), math.floor(box.Y * piece.size.Y))
			if contained then
				size = Vector2.new(math.min(size.X, box.X), math.min(size.Y, box.Y))
			end
			piece.pixels = size
			piece.instance.Size = UDim2.fromOffset(size.X, size.Y)
			piece.instance.Position = at(piece, piece.from)
			if piece.to then
				piece.drift = loop(sized, piece.instance, piece.time, { Position = at(piece, piece.to) })
			end
		end
	end

	local function field(index, size, from, to, time, breathe)
		local blob = Create.new("ImageLabel", { Name = "Light", Image = BLOB, ImageTransparency = breathe[1], Parent = frame })
		table.insert(painters, function()
			blob.ImageColor3 = colourOf(colours[(index - 1) % #colours + 1])
		end)
		-- Each field brightens and fades on its own rhythm, so the light
		-- never settles into one picture.
		loop(fixed, blob, breathe[3], { ImageTransparency = breathe[2] })
		local piece = { instance = blob, size = size, from = from, to = to, time = time }
		table.insert(pieces, piece)
		return piece
	end

	if kind == "Gradient" or kind == "Pattern" then
		-- Drawn on the layer itself: a UIGradient on the CanvasGroup.
		frame.BackgroundTransparency = 0
		local gradient = Create.new("UIGradient", { Parent = frame })
		if kind == "Gradient" then
			frame.BackgroundColor3 = Color3.new(1, 1, 1)
			table.insert(painters, function()
				local list = {}
				for _, entry in colours do
					table.insert(list, colourOf(entry))
				end
				gradient.Color = sequence(list)
			end)
			loop(fixed, gradient, 22, { Rotation = 360 }, Enum.EasingStyle.Linear)
		else
			local keypoints = {}
			for band = 0, PATTERN_BANDS do
				table.insert(keypoints, NumberSequenceKeypoint.new(band / PATTERN_BANDS, if band % 2 == 0 then 0.55 else 1))
			end
			gradient.Rotation = 45
			gradient.Transparency = NumberSequence.new(keypoints)
			table.insert(painters, function()
				frame.BackgroundColor3 = colourOf(colours[1])
			end)
			-- One pair of bands, so the slide repeats without a jump.
			loop(fixed, gradient, 6, { Offset = Vector2.new(2 / PATTERN_BANDS, 0) }, Enum.EasingStyle.Linear)
		end
	elseif kind == "Aurora" then
		if contained then
			field(1, Vector2.new(0.65, 1), Vector2.new(0.25, 0.35), Vector2.new(0.55, 0.6), 16, { 0.1, 0.45, 7 })
			field(2, Vector2.new(0.65, 1), Vector2.new(0.8, 0.65), Vector2.new(0.45, 0.35), 21, { 0.2, 0.5, 9 })
			field(3, Vector2.new(0.65, 1), Vector2.new(0.5, 0.5), Vector2.new(0.75, 0.3), 26, { 0.3, 0.6, 11 })
		else
			-- Large fields that wander past the window's edges, so the light
			-- seems to come from beyond it.
			field(1, Vector2.new(0.95, 1.35), Vector2.new(0.08, 0.1), Vector2.new(0.35, 0.3), 24, { 0.05, 0.35, 8 })
			field(2, Vector2.new(1.05, 1.45), Vector2.new(0.95, 0.95), Vector2.new(0.65, 0.7), 29, { 0.15, 0.45, 10 })
			field(3, Vector2.new(0.75, 1.1), Vector2.new(0.9, 0.05), Vector2.new(0.6, 0.35), 34, { 0.3, 0.6, 12 })
			field(4, Vector2.new(0.7, 1), Vector2.new(0.15, 0.95), Vector2.new(0.4, 0.7), 31, { 0.35, 0.65, 9 })
		end
	elseif kind == "Glow" then
		-- A wide, faint field for depth, and the light the pointer leads.
		field(2, Vector2.new(0.9, 1), Vector2.new(0.85, 0.75), Vector2.new(0.6, 0.6), 23, { 0.45, 0.65, 10 })
		local light = field(1, Vector2.new(0.6, 1), Vector2.new(0.3, 0.45), Vector2.new(0.7, 0.55), 14, { 0.05, 0.25, 6 })
		local following = false
		local follow
		-- While the pointer is over the surface, the light eases towards it
		-- (one short tween per mouse move, nothing per frame); once it
		-- leaves, the light goes back to drifting.
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if not running or input.UserInputType ~= Enum.UserInputType.MouseMovement or box.X <= 0 then
				return
			end
			local origin, size = frame.AbsolutePosition, frame.AbsoluteSize
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local inside = point.X >= origin.X and point.Y >= origin.Y and point.X <= origin.X + size.X and point.Y <= origin.Y + size.Y
			if inside then
				if not following and light.drift then
					light.drift:Cancel()
				end
				following = true
				local share = (point - origin) / Vector2.new(math.max(size.X, 1), math.max(size.Y, 1))
				if follow then
					follow:Cancel()
				end
				follow = TweenService:Create(light.instance, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = at(light, share) })
				follow:Play()
			elseif following then
				following = false
				if light.drift then
					light.drift:Play()
				end
			end
		end))
	elseif kind == "Mesh" then
		-- Two blends turning against each other.
		for layer = 1, 2 do
			local fill = Create.new("Frame", {
				Name = "Blend",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = if layer == 2 then 0.45 else 0,
				Parent = frame,
			})
			local gradient = Create.new("UIGradient", { Rotation = if layer == 2 then 180 else 0, Parent = fill })
			table.insert(painters, function()
				local list = {}
				for _, entry in colours do
					table.insert(list, colourOf(entry))
				end
				if layer == 2 then
					list = { list[#list], list[1] }
				end
				gradient.Color = sequence(list)
			end)
			loop(fixed, gradient, if layer == 2 then 28 else 22, { Rotation = if layer == 2 then -180 else 360 }, Enum.EasingStyle.Linear)
			table.insert(pieces, { instance = fill, size = Vector2.one, from = Vector2.new(0.5, 0.5) })
		end
	elseif kind == "Image" then
		local picture = Create.new("ImageLabel", { Name = "Picture", ScaleType = Enum.ScaleType.Crop, ImageTransparency = 0.1, Parent = frame })
		Icons.apply(picture, spec.Image)
		loop(fixed, picture, 9, { ImageTransparency = 0.35 })
		table.insert(pieces, { instance = picture, size = Vector2.one, from = Vector2.new(0.5, 0.5) })
	end

	-- Shaded edges: two soft bands, across and down, darker at the rim.
	if vignette then
		for _, rotation in { 0, 90 } do
			local shade = Create.new("Frame", { Name = "Vignette", BackgroundColor3 = Color3.new(0, 0, 0), Parent = frame }, {
				Create.new("UIGradient", {
					Rotation = rotation,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.5),
						NumberSequenceKeypoint.new(0.22, 1),
						NumberSequenceKeypoint.new(0.78, 1),
						NumberSequenceKeypoint.new(1, 0.5),
					}),
				}),
			})
			table.insert(pieces, { instance = shade, size = Vector2.one, from = Vector2.new(0.5, 0.5) })
		end
	end

	-- A band of light crossing the surface, then a pause.
	if spec.Sheen then
		local sheen = Create.new("Frame", { Name = "Sheen", BackgroundColor3 = Color3.new(1, 1, 1), Parent = frame })
		local gradient = Create.new("UIGradient", {
			Rotation = 20,
			Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.4, 1),
				NumberSequenceKeypoint.new(0.5, 0.82),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = sheen,
		})
		table.insert(pieces, { instance = sheen, size = Vector2.one, from = Vector2.new(0.5, 0.5) })
		loop(fixed, gradient, SHEEN_PASS, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Linear, SHEEN_GAP)
	end

	local function paint()
		for _, painter in painters do
			painter()
		end
	end
	paint()
	table.insert(connections, Theme.Changed:Connect(paint))
	local function watch()
		if measuring then
			measuring:Disconnect()
			measuring = nil
		end
		if #pieces > 0 then
			placePieces()
			measuring = measured:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePieces)
		end
	end
	watch()

	local controller = { frame = frame, Kind = kind }
	-- Lays the pieces out to fill `object` from now on (nil: the layer).
	function controller.MeasureFrom(object)
		object = object or frame
		if object == measured and (measuring or #pieces == 0) then
			return
		end
		measured = object
		watch()
	end
	function controller.SetVisible(visible)
		frame.Visible = visible ~= false
		local play = visible ~= false and not Motion.reduced
		if play == running then
			return
		end
		running = play
		for _, list in { fixed, sized } do
			for _, tween in list do
				if play then
					tween:Play()
				else
					tween:Pause()
				end
			end
		end
	end
	function controller.Destroy()
		for _, list in { fixed, sized } do
			for _, tween in list do
				tween:Cancel()
			end
		end
		for _, connection in connections do
			connection:Disconnect()
		end
		if measuring then
			measuring:Disconnect()
		end
		frame:Destroy()
	end
	controller.SetVisible(true)
	return controller
end

return Background
