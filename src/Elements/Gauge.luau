-- Rings: Gauge shows a value the hub measures (health, cooldown, progress
-- to a goal), Knob is a value the player turns. Both fill clockwise from the
-- top, with the number in the middle.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Arc = require("../Core/Arc")
local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local Gauge = {}

-- How far a drag must travel, in pixels, to cross the knob's whole range.
local KNOB_TRAVEL = 220

local function format(options, value)
	if type(options.Format) == "function" then
		local ok, text = pcall(options.Format, value)
		if ok then
			return tostring(text)
		end
	end
	local rounded = if math.abs(value - math.round(value)) < 1e-6 then tostring(math.round(value)) else string.format("%.1f", value)
	return rounded .. (options.Suffix or "")
end

-- A track ring, a value ring on top of it and a label in the middle.
function Gauge.ring(row, options)
	local size = options.Size or 72
	local thickness = options.Thickness or math.max(math.round(size / 12), 4)
	local holder = Create.new("Frame", {
		Name = "Ring",
		Size = UDim2.fromOffset(size, size),
		Parent = row.slot,
	})
	local track = Arc.new(holder, { Thickness = thickness, Role = "raised", Radius = -1, Even = false })
	local fill = Arc.new(holder, { Thickness = thickness, Role = options.Role or "accent", Radius = -1, Even = false })
	local label = Create.new("TextLabel", {
		Name = "Value",
		Size = UDim2.fromScale(1, 1),
		TextSize = math.max(math.round(size / 5), 11),
		Weight = "bold",
		TextXAlignment = Enum.TextXAlignment.Center,
		Theme = { TextColor3 = "text" },
		Parent = holder,
	})
	track:Set(1)
	return { holder = holder, track = track, fill = fill, label = label }
end

-- Gauge options: Value, Min [0], Max [100], Suffix, Format, Size [72],
-- Role ["accent"], Thresholds = { { At = 0.25, Role = "danger" }, ... }
-- (the role used at or below each share of the range).
function Gauge.new(container, options)
	local row = Row.new(container, options)
	local handle = row.handle
	local min, max = options.Min or 0, options.Max or 100
	local ring = Gauge.ring(row, options)
	local value = min
	local animation
	-- One value the ring follows, so an update eases from where it was.
	local shown = Instance.new("NumberValue")
	row.scope:add(shown)
	row.scope:connect(shown:GetPropertyChangedSignal("Value"), function()
		ring.fill:Set(shown.Value)
	end)

	local function roleFor(share)
		local chosen = options.Role or "accent"
		if type(options.Thresholds) == "table" then
			local best = math.huge
			for _, threshold in options.Thresholds do
				if type(threshold.At) == "number" and share <= threshold.At and threshold.At < best then
					best, chosen = threshold.At, threshold.Role or chosen
				end
			end
		end
		return chosen
	end

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		value = math.clamp(tonumber(newValue) or min, min, max)
		local share = if max > min then (value - min) / (max - min) else 0
		ring.label.Text = format(options, value)
		ring.fill:SetRole(roleFor(share))
		-- The ring eases to the new value; under reduced motion it jumps.
		if animation then
			animation:Cancel()
		end
		animation = Motion.tween(shown, "base", { Value = share })
		ring.fill:Set(shown.Value)
		self.Changed:Fire(value)
	end

	handle:Set(options.Value or min)
	return handle
end

-- Knob options: Min [0], Max [100], Step [1], Default [Min], Suffix,
-- Format, Size [64], Live [true; false calls back once on release].
-- Drag up or right to raise it, scroll over it, or use the arrow keys
-- while it is focused.
function Gauge.knob(container, options)
	local row = Row.new(container, options)
	local handle = row.handle
	local min, max, step = options.Min or 0, options.Max or 100, options.Step or 1
	local ring = Gauge.ring(row, { Size = options.Size or 64, Role = options.Role, Thickness = options.Thickness })
	local value = min
	local hovered = false

	local button = Create.new("TextButton", { Name = "Knob", Size = UDim2.fromScale(1, 1), Text = "", Parent = ring.holder })
	Create.corner(-1, button)

	local function snap(raw)
		return math.clamp(min + math.round((raw - min) / step) * step, min, max)
	end

	local function draw()
		local share = if max > min then (value - min) / (max - min) else 0
		ring.fill:Set(share)
		ring.label.Text = format(options, value)
	end

	-- `call` is false while dragging with Live = false.
	local function change(newValue, call)
		newValue = snap(newValue)
		if newValue == value then
			return
		end
		value = newValue
		draw()
		if call then
			row.fire(value)
		else
			handle.Changed:Fire(value)
		end
	end

	local live = options.Live ~= false
	local start = value
	Drag.track(row.scope, button, function()
		start = value
		return not handle:IsLocked()
	end, function(position, origin)
		local travel = (position.X - origin.X) - (position.Y - origin.Y)
		change(start + travel / KNOB_TRAVEL * (max - min), live)
	end, function(moved)
		if moved and not live then
			row.fire(value)
		end
	end)

	row.scope:connect(button.MouseEnter, function()
		hovered = true
		Theme.bind(ring.label, "TextColor3", "accent")
	end)
	row.scope:connect(button.MouseLeave, function()
		hovered = false
		Theme.bind(ring.label, "TextColor3", "text")
	end)
	row.scope:connect(UserInputService.InputChanged, function(input)
		if hovered and input.UserInputType == Enum.UserInputType.MouseWheel and not handle:IsLocked() then
			change(value + math.sign(input.Position.Z) * step, true)
		end
	end)
	row.scope:connect(UserInputService.InputBegan, function(input)
		if GuiService.SelectedObject == button then
			if input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.Up then
				change(value + step, true)
			elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Down then
				change(value - step, true)
			end
		end
	end)

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		value = snap(tonumber(newValue) or min)
		draw()
		row.fire(value)
	end

	value = snap(options.Default or min)
	draw()
	return handle
end

return Gauge
