local ColorPicker = require("./ColorPicker")
local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Keybind = require("./Keybind")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local TRACK_WIDTH, INSET, STRETCH = 36, 3, 6
-- The shapes a switch's thumb can take.
local THUMBS = {
	Circle = { width = 14, height = 14, corner = -1 },
	Oval = { width = 18, height = 12, corner = -1 },
	Square = { width = 14, height = 14, corner = 4 },
}

local Toggle = {}

-- The key chip and colour swatch each take a Flag of their own, so a config
-- can restore the bound key and colour without switching the toggle on.
function Toggle.new(container, options)
	local row = Row.new(container, options, { button = true })
	local handle, window = row.handle, row.window
	local value = options.Default == true
	local checkbox = options.Style == "Checkbox"
	local thumb = THUMBS[options.Thumb or window.toggleThumb] or THUMBS.Circle

	local problem = window:checkFlag(options.Color and options.Color.Flag) or window:checkFlag(options.Keybind and options.Keybind.Flag)
	if problem then
		handle:Destroy()
		error(problem, 4)
	end

	if options.Color then
		local settings = options.Color
		handle.Color = ColorPicker.control(row, settings, function(color, transparency)
			Env.call(handle.Title .. " colour", settings.Callback, color, transparency)
		end)
		window:claimFlag(settings.Flag, handle.Color, row.scope)
	end

	if options.Keybind then
		local settings = options.Keybind
		local hold = settings.Mode == "Hold"
		handle.Keybind = Keybind.control(row, { Default = settings.Default, Mode = if hold then "Hold" else "Toggle" }, function(pressed)
			if hold then
				handle:Set(pressed)
			elseif pressed then
				handle:Set(not value)
			end
		end)
		window:claimFlag(settings.Flag, handle.Keybind, row.scope)
	end

	local track = Create.new("Frame", {
		Name = "Switch",
		Size = if checkbox then UDim2.fromOffset(22, 22) else UDim2.fromOffset(36, 20),
		LayoutOrder = 10,
		Theme = { BackgroundColor3 = "stroke" },
		Parent = row.slot,
	})
	Create.corner(if checkbox then 7 else -1, track)
	-- An empty checkbox needs an outline to read as a box; a switch has its knob.
	local restRole = if checkbox then row.controlRole else "stroke"
	local outline = if checkbox then Create.stroke("stroke", track) else nil

	-- The hover outline hugs the track: one pixel of gap keeps it visible
	-- when the track itself is the accent colour.
	local ring = Create.new("Frame", {
		Name = "Outline",
		Size = UDim2.new(1, 2, 1, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = track,
	})
	Create.corner(if checkbox then 8 else -1, ring)
	local ringStroke = Create.new("UIStroke", { Name = "Stroke", Thickness = 1.5, Transparency = 1, Parent = ring })

	-- The toggle's own Outline and OutlineColor win over the window's defaults.
	local function showOutline(active)
		local wanted = window.toggleOutline
		if options.Outline ~= nil then
			wanted = options.Outline == true
		end
		local color = options.OutlineColor or window.toggleOutlineColor
		ringStroke.Color = if typeof(color) == "Color3" then color else Theme.color("accent")
		Motion.tween(ringStroke, "fast", { Transparency = if active and wanted then 0 else 1 })
	end

	local knob, mark
	if checkbox then
		mark = Create.icon("check", 14, "onAccent", track)
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		outline.Thickness = 1.5
	else
		knob = Create.new("Frame", { Name = "Thumb", Size = UDim2.fromOffset(thumb.width, thumb.height), AnchorPoint = Vector2.new(0, 0.5), Theme = { BackgroundColor3 = "textMuted" }, Parent = track })
		Create.corner(thumb.corner, knob)
	end

	-- The thumb stretches toward where it is going, then settles there with a
	-- small overshoot. A newer change cancels the settle of an older one.
	local slideGeneration = 0
	local function slide(timing)
		local width, height = thumb.width, thumb.height
		local rest = UDim2.new(0, if value then TRACK_WIDTH - width - INSET else INSET, 0.5, 0)
		slideGeneration += 1
		if not timing or Motion.reduced then
			knob.Size = UDim2.fromOffset(width, height)
			knob.Position = rest
			return
		end
		local stretched = width + STRETCH
		Motion.tween(knob, "fast", {
			Size = UDim2.fromOffset(stretched, height),
			Position = UDim2.new(0, if value then TRACK_WIDTH - stretched - INSET else INSET, 0.5, 0),
		})
		local started = slideGeneration
		task.delay(0.1, function()
			if started == slideGeneration and not row.scope.cleaned then
				Motion.tween(knob, "spring", { Size = UDim2.fromOffset(width, height), Position = rest })
			end
		end)
	end

	local hovered = false
	local function draw(timing)
		local role = if value then (if hovered then "accentHover" else "accent") elseif hovered and not checkbox then "hover" else restRole
		Theme.bind(track, "BackgroundColor3", role, true)
		Motion.tween(track, timing, { BackgroundColor3 = Theme.color(role) })
		if checkbox then
			-- The box fills with the accent and the mark pops into it.
			Motion.tween(mark, if timing and value then "spring" else timing, {
				Size = if value then UDim2.fromOffset(14, 14) else UDim2.fromOffset(0, 0),
				ImageTransparency = if value then 0 else 1,
			})
			Theme.bind(outline, "Color", if value then "accent" elseif hovered then "textMuted" else "stroke")
		else
			local knobRole = if value then "onAccent" elseif hovered then "text" else "textMuted"
			Theme.bind(knob, "BackgroundColor3", knobRole, true)
			Motion.tween(knob, timing, { BackgroundColor3 = Theme.color(knobRole) })
		end
	end

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		local moved = value ~= (newValue == true)
		value = newValue == true
		draw("fast")
		if moved and knob then
			slide("fast")
		end
		if self.Keybind then
			self.Keybind.Active = value
			window.KeybindsChanged:Fire()
		end
		row.fire(value)
	end

	row.scope:connect(row.frame.Activated, function()
		handle:Set(not value)
	end)
	row.onHover(function(active)
		hovered = active
		draw("fast")
		showOutline(active)
	end, track)

	draw(nil)
	if knob then
		slide(nil)
	end
	if value then
		-- A switch drawn on must mean the feature is on, so its Callback runs
		-- once, after the hub has finished building.
		task.defer(function()
			if not row.scope.cleaned and value then
				row.fire(true)
			end
		end)
	end
	return handle
end

return Toggle
