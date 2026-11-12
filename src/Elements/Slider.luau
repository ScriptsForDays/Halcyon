local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Row = require("./Row")
local Tip = require("./Tip")

local KNOB = 14

local Slider = {}

local function decimalsOf(step)
	local fraction = string.match(tostring(step), "%.(%d+)")
	return if fraction then #fraction else 0
end

-- Options: Min, Max, Step, Default, Suffix, Stacked (track under the title),
-- Range (two knobs; the value is { low, high }), Tooltip (false hides the
-- value bubble shown while dragging), TooltipStyle ("Rounded", "Sharp",
-- "Pill" or "Plain").
function Slider.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local min, max = options.Min or 0, options.Max or 100
	local step = options.Step or 1
	local range = options.Range == true
	local pattern = "%." .. decimalsOf(step) .. "f"
	local low, high = min, min

	local function snap(number)
		number = math.clamp(tonumber(number) or min, min, max)
		number = min + math.round((number - min) / step) * step
		-- Formatting and parsing again drops float noise such as 0.30000000000000004.
		return math.clamp(tonumber(string.format(pattern, number)), min, max)
	end

	local function label(number)
		return string.format(pattern, number) .. (options.Suffix or "")
	end

	local area = Create.new("TextButton", { Name = "Track", LayoutOrder = 1 })
	row.adapt(area, options.Width or 130, row.reach, options.Stacked)
	-- The rail is inset by half a knob so the knob never leaves the press area.
	local rail = Create.new("Frame", {
		Name = "Rail",
		Size = UDim2.new(1, -KNOB, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Theme = { BackgroundColor3 = "stroke" },
		Parent = area,
	})
	Create.corner(-1, rail)
	local fill = Create.new("Frame", { Name = "Fill", Theme = { BackgroundColor3 = "accent" }, Parent = rail })
	Create.corner(-1, fill)

	local function newKnob()
		local knob = Create.new("Frame", { Name = "Knob", Size = UDim2.fromOffset(KNOB, KNOB), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Theme = { BackgroundColor3 = "text" }, Parent = rail })
		Create.corner(-1, knob)
		return knob
	end
	local highKnob = newKnob()
	local lowKnob = if range then newKnob() else nil

	local readout
	if range then
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
		highKnob.Position = UDim2.fromScale(to, 0.5)
		if lowKnob then
			lowKnob.Position = UDim2.fromScale(from, 0.5)
		end
		readout.Text = if range then label(low) .. " - " .. label(high) else label(high)
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

	Drag.area(scope, area, function(x)
		local pressed = min + x * (max - min)
		local changed = if not range then store(min, pressed) elseif dragLow then store(math.min(pressed, high), high) else store(low, math.max(pressed, low))
		if tipWanted() then
			local style = options.TooltipStyle or row.window.sliderTooltipStyle
			if tip and tip.style ~= style then
				tip.destroy()
				tip = nil
			end
			tip = tip or Tip.new(row, style)
			local shown = if range and dragLow then low else high
			tip.show(rail, (shown - min) / math.max(max - min, 1e-9), label(shown), readout)
		end
		if changed then
			row.fire(handle:Get())
		end
	end, function()
		if tip then
			tip.hide()
		end
	end, rail)

	if not range then
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
