local ColorPicker = require("./ColorPicker")
local Create = require("../Core/Create")
local Env = require("../Core/Env")
local Icons = require("../Core/Icons")
local Keybind = require("./Keybind")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Strings = require("../Core/Strings")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

-- How far a moving thumb stretches toward where it is going.
local STRETCH = 6

-- The shapes a switch's thumb can take (kind "Thumb").
Styles.register("Thumb", "Circle", { width = 14, height = 14, corner = -1 })
Styles.register("Thumb", "Oval", { width = 18, height = 12, corner = -1 })
Styles.register("Thumb", "Square", { width = 14, height = 14, corner = 4 })

-- Toggle looks (kind "Toggle"). A switch has a track and a sliding thumb;
-- a box fills and shows a mark; a chip is a small pill that reads On or Off.
--   width, height, corner  the track (corner -1 is fully round)
--   inset                   the gap between thumb and track end
--   thumb                   a fixed thumb, else the window's Thumb look
--   rail                    a thin rail of this height under a larger thumb
--   labels                  { on, off } words drawn inside the track
--   icons                   { on, off } icons drawn inside the thumb
--   glow                    an accent halo while on
--   knobOff                 the thumb's colour while off
Styles.register("Toggle", "Switch", { kind = "switch", width = 36, height = 20, corner = -1, inset = 3 })
Styles.register("Toggle", "Large", {
	kind = "switch",
	width = 46,
	height = 26,
	corner = -1,
	inset = 3,
	thumb = { width = 20, height = 20, corner = -1 },
	knobOff = "text",
})
Styles.register("Toggle", "Slim", {
	kind = "switch",
	width = 34,
	height = 20,
	corner = -1,
	inset = 0,
	rail = 12,
	thumb = { width = 18, height = 18, corner = -1 },
	knobOff = "text",
})
Styles.register("Toggle", "Square", {
	kind = "switch",
	width = 36,
	height = 20,
	corner = 5,
	inset = 3,
	thumb = { width = 14, height = 14, corner = 3 },
})
Styles.register("Toggle", "Labelled", {
	kind = "switch",
	width = 60,
	height = 24,
	corner = -1,
	inset = 3,
	thumb = { width = 18, height = 18, corner = -1 },
	labels = { "ON", "OFF" },
})
Styles.register("Toggle", "Icon", {
	kind = "switch",
	width = 40,
	height = 22,
	corner = -1,
	inset = 3,
	thumb = { width = 16, height = 16, corner = -1 },
	icons = { "check", "x" },
})
Styles.register("Toggle", "Glow", { kind = "switch", width = 36, height = 20, corner = -1, inset = 3, glow = true })
Styles.register("Toggle", "Checkbox", { kind = "box", width = 22, height = 22, corner = 7 })
Styles.register("Toggle", "Circle", { kind = "box", width = 22, height = 22, corner = -1 })
Styles.register("Toggle", "Chip", { kind = "chip", width = 46, height = 24, corner = -1, labels = { "On", "Off" } })

local Toggle = {}

-- The key chip and colour swatch each take a Flag of their own, so a config
-- can restore the bound key and colour without switching the toggle on.
function Toggle.new(container, options)
	local row = Row.new(container, options, { button = true })
	local handle, window = row.handle, row.window
	local value = options.Default == true
	local look = Styles.pick("Toggle", options.Style, window)
	local kind = look.kind or "switch"
	local box, chip = kind == "box", kind == "chip"
	local width, height = look.width or 36, look.height or 20
	local thumb = look.thumb or Styles.pick("Thumb", options.Thumb, window)
	local inset = look.inset or 3

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

	-- Exclusive = "name": at most one toggle with that name is on at a time.
	local group
	if type(options.Exclusive) == "string" then
		window.exclusiveGroups = window.exclusiveGroups or {}
		group = window.exclusiveGroups[options.Exclusive] or {}
		window.exclusiveGroups[options.Exclusive] = group
		table.insert(group, handle)
		row.scope:add(function()
			local index = table.find(group, handle)
			if index then
				table.remove(group, index)
			end
		end)
	end

	if options.Keybind then
		local settings = options.Keybind
		local hold = settings.Mode == "Hold"
		handle.Keybind = Keybind.control(row, { Default = settings.Default, Mode = if hold then "Hold" else "Toggle", Modifiers = settings.Modifiers }, function(pressed)
			if hold then
				handle:Set(pressed)
			elseif pressed then
				handle:Set(not value)
			end
		end)
		window:claimFlag(settings.Flag, handle.Keybind, row.scope)
	end

	-- The track is the hover target and the outline's frame. With a rail
	-- look it is a clear holder and the thin rail inside it takes the colour.
	local track = Create.new("Frame", {
		Name = "Switch",
		Size = UDim2.fromOffset(width, height),
		LayoutOrder = 10,
		BackgroundTransparency = if look.rail then 1 else 0,
		Theme = { BackgroundColor3 = "stroke" },
		Parent = row.slot,
	})
	local body = track
	if look.rail then
		body = Create.new("Frame", {
			Name = "Rail",
			Size = UDim2.new(1, 0, 0, look.rail),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Theme = { BackgroundColor3 = "stroke" },
			Parent = track,
		})
		Create.corner(-1, body)
	else
		Create.corner(look.corner or -1, track)
	end
	-- An empty box needs an outline to read as a box; a switch has its thumb.
	local restRole = if box then row.controlRole else "stroke"
	local outline = if box then Create.stroke("stroke", track, 1.5) else nil

	-- The hover outline hugs the track: one pixel of gap keeps it visible
	-- when the track itself is the accent colour.
	local ring = Create.new("Frame", {
		Name = "Outline",
		Size = UDim2.new(1, 2, 1, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = track,
	})
	Create.corner(if (look.corner or -1) < 0 then -1 else look.corner + 1, ring)
	local ringStroke = Create.new("UIStroke", { Name = "Stroke", Thickness = 1.5, Transparency = 1, Parent = ring })

	local halo
	if look.glow then
		halo = Create.new("UIStroke", { Name = "Glow", Thickness = 3, Transparency = 1, Theme = { Color = "accent" }, Parent = body })
	end

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

	local knob, mark, word, glyph
	if box then
		mark = Create.icon("check", 14, "onAccent", track)
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
	elseif chip then
		-- A fixed size: a chip that grew with its word would shift the row
		-- each time it switched.
		word = Create.new("TextLabel", {
			Name = "State",
			Size = UDim2.fromScale(1, 1),
			TextSize = 12,
			Weight = "bold",
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = track,
		})
	else
		knob = Create.new("Frame", {
			Name = "Thumb",
			Size = UDim2.fromOffset(thumb.width, thumb.height),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 2,
			Theme = { BackgroundColor3 = "textMuted" },
			Parent = track,
		})
		Create.corner(thumb.corner or -1, knob)
		if look.rail then
			-- A thumb wider than its rail needs an edge against the page.
			Create.new("UIStroke", { Transparency = 0.6, Theme = { Color = "background" }, Parent = knob })
		end
		if look.icons then
			glyph = Create.icon(look.icons[2], math.max(thumb.height - 6, 8), "background", knob)
			glyph.AnchorPoint = Vector2.new(0.5, 0.5)
			glyph.Position = UDim2.fromScale(0.5, 0.5)
		end
		if look.labels then
			word = Create.new("TextLabel", {
				Name = "State",
				Size = UDim2.fromOffset(0, height),
				AutomaticSize = Enum.AutomaticSize.X,
				AnchorPoint = Vector2.new(1, 0.5),
				TextSize = 12,
				Weight = "bold",
				Parent = track,
			})
		end
	end

	-- The thumb stretches toward where it is going, then settles there with a
	-- small overshoot. A newer change cancels the settle of an older one.
	local slideGeneration = 0
	local function slide(timing)
		local thumbWidth, thumbHeight = thumb.width, thumb.height
		local rest = UDim2.new(0, if value then width - thumbWidth - inset else inset, 0.5, 0)
		slideGeneration += 1
		if word and not chip then
			-- The word sits on the side the thumb left.
			word.AnchorPoint = Vector2.new(if value then 0 else 1, 0.5)
			word.Position = UDim2.new(if value then 0 else 1, if value then 8 else -8, 0.5, 0)
		end
		if not timing or Motion.reduced then
			knob.Size = UDim2.fromOffset(thumbWidth, thumbHeight)
			knob.Position = rest
			return
		end
		local stretched = thumbWidth + STRETCH
		Motion.tween(knob, "fast", {
			Size = UDim2.fromOffset(stretched, thumbHeight),
			Position = UDim2.new(0, if value then width - stretched - inset else inset, 0.5, 0),
		})
		local started = slideGeneration
		task.delay(0.1, function()
			if started == slideGeneration and not row.scope.cleaned then
				Motion.tween(knob, "spring", { Size = UDim2.fromOffset(thumbWidth, thumbHeight), Position = rest })
			end
		end)
	end

	local hovered = false
	local function draw(timing)
		local role = if value then (if hovered then "accentHover" else "accent") elseif hovered and not box then "hover" else restRole
		Theme.bind(body, "BackgroundColor3", role, true)
		Motion.tween(body, timing, { BackgroundColor3 = Theme.color(role) })
		if box then
			-- The box fills with the accent and the mark pops into it.
			Motion.tween(mark, if timing and value then "spring" else timing, {
				Size = if value then UDim2.fromOffset(14, 14) else UDim2.fromOffset(0, 0),
				ImageTransparency = if value then 0 else 1,
			})
			Theme.bind(outline, "Color", if value then "accent" elseif hovered then "textMuted" else "stroke")
		elseif knob then
			local knobRole = if value then "onAccent" elseif hovered then "text" else look.knobOff or "textMuted"
			Theme.bind(knob, "BackgroundColor3", knobRole, true)
			Motion.tween(knob, timing, { BackgroundColor3 = Theme.color(knobRole) })
		end
		if word then
			word.Text = Strings.get(if value then look.labels[1] else look.labels[2])
			Theme.bind(word, "TextColor3", if value then "onAccent" else "textMuted")
		end
		if glyph then
			Icons.apply(glyph, if value then look.icons[1] else look.icons[2])
			Theme.bind(glyph, "ImageColor3", if value then "accent" else "background")
		end
		if halo then
			Motion.tween(halo, timing, { Transparency = if value then 0.55 else 1 })
		end
	end

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		local moved = value ~= (newValue == true)
		value = newValue == true
		-- In an Exclusive group, turning this on turns the others off.
		if value and group then
			for _, other in group do
				if other ~= handle and other:Get() then
					other:Set(false)
				end
			end
		end
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

	-- Confirm = true or a sentence: switching on from the row asks first.
	-- Turning it off never asks.
	row.scope:connect(row.frame.Activated, function()
		if value or not options.Confirm then
			handle:Set(not value)
			return
		end
		window:Dialog({
			Title = Strings.get("Turn on {title}?", { title = handle.Title }),
			Content = if type(options.Confirm) == "string" then options.Confirm else nil,
			Dismissible = true,
			Buttons = {
				{ Title = Strings.get("Keep it off") },
				{
					Title = Strings.get("Turn on"),
					Variant = "Primary",
					Callback = function()
						handle:Set(true)
					end,
				},
			},
		})
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
