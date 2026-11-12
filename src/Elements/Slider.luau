local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local SliderTooltip = require("./SliderTooltip")
local Styles = require("../Core/Styles")

-- Slider looks (kind "Slider").
--   rail        the track's height
--   knob        the knob's width and height, or nil for none
--   knobCorner  the knob's radius (-1 round)
--   railCorner  the track's radius (-1 round)
--   ring        an accent ring around the knob
--   ticks       marks along the track
--   inside      the value is written inside the filled track
--   grow        the track thickens by this much while hovered
Styles.register("Slider", "Line", { rail = 4, knob = { 14, 14 }, knobCorner = -1 })
Styles.register("Slider", "Thin", { rail = 2, knob = { 12, 12 }, knobCorner = -1 })
Styles.register("Slider", "Thick", { rail = 8, knob = { 18, 18 }, knobCorner = -1, ring = true })
Styles.register("Slider", "Handle", { rail = 4, knob = { 6, 18 }, knobCorner = -1 })
Styles.register("Slider", "Ticks", { rail = 4, knob = { 14, 14 }, knobCorner = -1, ticks = true })
Styles.register("Slider", "Bare", { rail = 6, grow = 4 })
Styles.register("Slider", "Block", { rail = 22, railCorner = 6, inside = true })

local Slider = {}

local function decimalsOf(step)
	local fraction = string.match(tostring(step), "%.(%d+)")
	return if fraction then #fraction else 0
end

-- Options: Min, Max, Step, Default, Suffix, Stacked (track under the title),
-- Range (two knobs; the value is { low, high }), Tooltip (false hides the
-- value bubble shown while dragging), TooltipStyle ("Rounded", "Sharp",
-- "Pill" or "Plain"), Live (false runs the Callback once, when the drag
-- ends, for a setting that is costly or moves the slider itself), Style
-- (a Slider look), Display ("Box" typed value, "Text", "Fraction" as
-- 5 / 10, or "None"), Prefix, Percent (shows the share of the range),
-- Format (a function from value to text), DefaultMarker (a mark at Default).
function Slider.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local min, max = options.Min or 0, options.Max or 100
	local step = options.Step or 1
	local range = options.Range == true
	local pattern = "%." .. decimalsOf(step) .. "f"
	local low, high = min, min
	local look = Styles.pick("Slider", options.Style, row.window)
	local knobSize = look.knob
	local KNOB = if knobSize then knobSize[1] else 0
	local display = options.Display or (if look.inside then "None" else "Box")

	local function snap(number)
		number = math.clamp(tonumber(number) or min, min, max)
		number = min + math.round((number - min) / step) * step
		-- Formatting and parsing again drops float noise such as 0.30000000000000004.
		return math.clamp(tonumber(string.format(pattern, number)), min, max)
	end

	local function label(number)
		if type(options.Format) == "function" then
			local ok, text = pcall(options.Format, number)
			if ok and text ~= nil then
				return tostring(text)
			end
		end
		if options.Percent then
			return (options.Prefix or "") .. math.round((number - min) / math.max(max - min, 1e-9) * 100) .. "%"
		end
		return (options.Prefix or "") .. string.format(pattern, number) .. (options.Suffix or "")
	end

	local area = Create.new("TextButton", { Name = "Track", LayoutOrder = 1 })
	row.placeControl(area, options.Width or 130, row.reach, options.Stacked)
	-- The rail is inset by half a knob so the knob never leaves the press area.
	local rail = Create.new("Frame", {
		Name = "Rail",
		Size = UDim2.new(1, -KNOB, 0, look.rail or 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Theme = { BackgroundColor3 = "stroke" },
		Parent = area,
	})
	Create.corner(look.railCorner or -1, rail)
	local fill = Create.new("Frame", { Name = "Fill", Theme = { BackgroundColor3 = "accent" }, Parent = rail })
	Create.corner(look.railCorner or -1, fill)

	local function newKnob()
		if not knobSize then
			return nil
		end
		local knob = Create.new("Frame", {
			Name = "Knob",
			Size = UDim2.fromOffset(knobSize[1], knobSize[2]),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 2,
			Theme = { BackgroundColor3 = "text" },
			Parent = rail,
		})
		Create.corner(look.knobCorner or -1, knob)
		if look.ring then
			Create.new("UIStroke", { Thickness = 3, Theme = { Color = "accent" }, Parent = knob })
		end
		return knob
	end
	local highKnob = newKnob()
	local lowKnob = if range then newKnob() else nil

	if look.ticks then
		-- One mark per step when there are few, otherwise ten.
		local steps = math.floor((max - min) / step + 0.5)
		local count = if steps > 0 and steps <= 20 then steps else 10
		for index = 0, count do
			local mark = Create.new("Frame", {
				Name = "Tick",
				Size = UDim2.fromOffset(2, 8),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(index / count, 0.5),
				BackgroundTransparency = 0.4,
				Theme = { BackgroundColor3 = "textMuted" },
				Parent = rail,
			})
			Create.corner(-1, mark)
		end
	end
	if options.DefaultMarker and type(options.Default) == "number" then
		local spot = (math.clamp(options.Default, min, max) - min) / math.max(max - min, 1e-9)
		Create.new("Frame", {
			Name = "DefaultMark",
			Size = UDim2.fromOffset(2, (look.rail or 4) + 8),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot, 0.5),
			Theme = { BackgroundColor3 = "textMuted" },
			Parent = rail,
		})
	end
	local inside
	if look.inside then
		inside = Create.new("TextLabel", {
			Name = "Inside",
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			TextSize = 12,
			Weight = "bold",
			ZIndex = 3,
			Theme = { TextColor3 = "text" },
			Parent = rail,
		})
	end
	if look.grow then
		-- A bare track thickens under the pointer so it reads as grabbable.
		scope:connect(area.MouseEnter, function()
			Motion.tween(rail, "fast", { Size = UDim2.new(1, -KNOB, 0, look.rail + look.grow) })
		end)
		scope:connect(area.MouseLeave, function()
			Motion.tween(rail, "fast", { Size = UDim2.new(1, -KNOB, 0, look.rail) })
		end)
	end

	local readout
	if display == "None" or display == "Text" or display == "Fraction" then
		readout = Create.new("TextLabel", {
			Name = "Value",
			Size = UDim2.fromOffset(0, row.reach),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 13,
			Visible = display ~= "None",
			LayoutOrder = 2,
			Theme = { TextColor3 = "textMuted" },
			Parent = row.slot,
		})
	elseif range then
		readout = Create.new("TextLabel", {
			Name = "Value",
			Size = UDim2.fromOffset(0, row.reach),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 13,
			LayoutOrder = 2,
			Theme = { TextColor3 = "textMuted" },
			Parent = row.slot,
		})
	else
		readout = Create.new("TextBox", {
			Name = "Value",
			Size = UDim2.fromOffset(54, row.reach),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
			Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text" },
			Parent = row.slot,
		})
		Create.corner(6, readout)
		Create.stroke("stroke", readout)
	end

	local function draw()
		local span = math.max(max - min, 1e-9)
		local from, to = if range then (low - min) / span else 0, (high - min) / span
		fill.Position = UDim2.fromScale(from, 0)
		fill.Size = UDim2.fromScale(to - from, 1)
		if highKnob then
			highKnob.Position = UDim2.fromScale(to, 0.5)
		end
		if lowKnob then
			lowKnob.Position = UDim2.fromScale(from, 0.5)
		end
		local text = if range then label(low) .. " - " .. label(high) else label(high)
		if display == "Fraction" and not range then
			text ..= " / " .. label(max)
		end
		readout.Text = text
		if inside then
			inside.Text = text
		end
	end

	-- Stores a snapped value and reports whether it changed.
	local function store(newLow, newHigh)
		newLow, newHigh = snap(newLow), snap(newHigh)
		if newLow > newHigh then
			newLow, newHigh = newHigh, newLow
		end
		local changed = newLow ~= low or newHigh ~= high
		low, high = newLow, newHigh
		draw()
		return changed
	end

	function handle:Get()
		return if range then { low, high } else high
	end

	function handle:Set(value)
		if range then
			value = if type(value) == "table" then value else { min, max }
			store(value[1], value[2])
		else
			store(min, value)
		end
		row.fire(self:Get())
	end

	-- A range drag moves whichever knob was nearer to the press.
	local dragLow = false
	Drag.track(scope, area, function(position)
		local origin, width = rail.AbsolutePosition, math.max(rail.AbsoluteSize.X, 1)
		local pressed = min + math.clamp((position.X - origin.X) / width, 0, 1) * (max - min)
		dragLow = range and math.abs(pressed - low) < math.abs(pressed - high)
		return true
	end, function() end)
	-- The slider's own Tooltip and TooltipStyle win over the window's defaults.
	local tip
	local function tipWanted()
		if options.Tooltip ~= nil then
			return options.Tooltip == true
		end
		return row.window.sliderTooltips
	end

	local dragged = false
	Drag.area(scope, area, function(x)
		local pressed = min + x * (max - min)
		local changed = if not range then store(min, pressed) elseif dragLow then store(math.min(pressed, high), high) else store(low, math.max(pressed, low))
		if tipWanted() then
			local style = options.TooltipStyle or row.window.styles.SliderTooltip or row.window.sliderTooltipStyle
			if tip and tip.style ~= style then
				tip.destroy()
				tip = nil
			end
			tip = tip or SliderTooltip.new(row, style)
			local shown = if range and dragLow then low else high
			tip.show(rail, (shown - min) / math.max(max - min, 1e-9), label(shown), readout)
		end
		if changed then
			if options.Live == false then
				dragged = true
			else
				row.fire(handle:Get())
			end
		end
	end, function()
		if tip then
			tip.hide()
		end
		if dragged then
			dragged = false
			row.fire(handle:Get())
		end
	end, rail)

	if not range and readout:IsA("TextBox") then
		scope:connect(readout.FocusLost, function()
			local typed = tonumber(string.match(readout.Text, "-?%d+%.?%d*"))
			if typed then
				handle:Set(typed)
			else
				draw()
			end
		end)
	end

	-- The default is only shown. Writing it to the game on creation could
	-- overwrite a value the game set itself, such as a WalkSpeed of 20.
	local default = options.Default
	if range then
		default = if type(default) == "table" then default else { min, max }
		store(default[1], default[2])
	else
		store(min, default or min)
	end
	return handle
end

return Slider
