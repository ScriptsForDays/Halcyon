-- Moving backgrounds for the window and for sections. Every motion is a
-- repeating tween, so no Lua runs per frame; the tweens pause while the
-- surface is hidden, and with reduced motion the background holds still.
--
--   Background = { Kind = "Aurora", Colors = { "accent", "info" }, Speed = 1, Intensity = 0.5 }
--
-- Kinds:
--   Aurora    soft blobs of colour drifting behind the content
--   Gradient  a slowly turning blend of the colours
--   Mesh      two blends turning against each other
--   Pattern   fine diagonal lines sliding across
--   Image     a picture that slowly fades a little in and out (Image = any image source)
-- Colors are theme roles or Color3s; Speed scales every motion (2 is twice
-- as fast); Intensity 0-1 is how strongly it shows.
--
-- A section sizes itself to its children, and Roblox counts every
-- scale-sized piece below such a frame as wanting more room, so the section
-- would stretch to the screen. So the layer itself is the only scale-sized
-- piece: Gradient and Pattern draw on it directly, and the other kinds size
-- their pieces in pixels measured from it, laid out again only when its
-- size changes.

local TweenService = game:GetService("TweenService")

local Create = require("./Create")
local Icons = require("./Icons")
local Motion = require("./Motion")
local Theme = require("./Theme")

local Background = {}

local KINDS = { Aurora = true, Gradient = true, Mesh = true, Pattern = true, Image = true }
-- A soft-edged square (the window shadow's image), stretched into a blob.
local BLOB = "rbxassetid://8992230677"
local PATTERN_BANDS = 15

local function colourOf(entry)
	if typeof(entry) == "Color3" then
		return entry
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
-- Radius and Scale (a function returning the UIScale above the parent).
-- Returns { frame, Kind, SetVisible(bool), Destroy() }, or nil for none.
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
	local colours = if type(spec.Colors) == "table" and #spec.Colors > 0 then spec.Colors else { "accent", "info", "accentHover" }

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

	local function loop(list, target, seconds, goals, style)
		local timing = TweenInfo.new(seconds / speed, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, style ~= Enum.EasingStyle.Linear)
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
	local function placePieces()
		for _, tween in sized do
			tween:Cancel()
		end
		table.clear(sized)
		local scale = if defaults.Scale then defaults.Scale() else 1
		local box = frame.AbsoluteSize / math.max(scale, 0.01)
		box = Vector2.new(math.floor(box.X), math.floor(box.Y))
		if box.X <= 0 or box.Y <= 0 then
			return
		end
		for _, piece in pieces do
			local size = Vector2.new(math.min(math.floor(box.X * piece.size.X), box.X), math.min(math.floor(box.Y * piece.size.Y), box.Y))
			-- Kept wholly inside the layer, wherever the path goes: a piece
			-- poking out would make a self-sizing section grow to fit it.
			local function at(share)
				local x = math.clamp(math.floor(box.X * share.X - size.X / 2), 0, box.X - size.X)
				local y = math.clamp(math.floor(box.Y * share.Y - size.Y / 2), 0, box.Y - size.Y)
				return UDim2.fromOffset(x, y)
			end
			piece.instance.Size = UDim2.fromOffset(size.X, size.Y)
			piece.instance.Position = at(piece.from)
			if piece.to then
				loop(sized, piece.instance, piece.time, { Position = at(piece.to) })
			end
		end
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
		-- Three blobs, each wandering on its own slow path.
		local paths = {
			{ from = Vector2.new(0.25, 0.35), to = Vector2.new(0.55, 0.6), time = 16 },
			{ from = Vector2.new(0.8, 0.65), to = Vector2.new(0.45, 0.35), time = 21 },
			{ from = Vector2.new(0.5, 0.5), to = Vector2.new(0.75, 0.3), time = 26 },
		}
		for index, path in paths do
			local blob = Create.new("ImageLabel", { Name = "Blob", Image = BLOB, ImageTransparency = 0.1, Parent = frame })
			table.insert(painters, function()
				blob.ImageColor3 = colourOf(colours[(index - 1) % #colours + 1])
			end)
			table.insert(pieces, { instance = blob, size = Vector2.new(0.65, 1), from = path.from, to = path.to, time = path.time })
		end
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

	local function paint()
		for _, painter in painters do
			painter()
		end
	end
	paint()
	table.insert(connections, Theme.Changed:Connect(paint))
	if #pieces > 0 then
		placePieces()
		table.insert(connections, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePieces))
	end

	local controller = { frame = frame, Kind = kind }
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
		frame:Destroy()
	end
	controller.SetVisible(true)
	return controller
end

return Background
