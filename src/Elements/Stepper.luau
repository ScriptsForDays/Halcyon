local UserInputService = game:GetService("UserInputService")

local Create = require("../Core/Create")
local Row = require("./Row")

local Stepper = {}

-- Pixels of horizontal drag on the number per step.
local DRAG_PER_STEP = 8

-- A number changed one step at a time. Options: Min, Max, Step, Default,
-- Suffix, Drag (default true: dragging the number sideways changes it).
function Stepper.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local min, max = options.Min or -math.huge, options.Max or math.huge
	local step = options.Step or 1
	local value = math.clamp(options.Default or 0, min, max)

	local function press(icon, order)
		local button = Create.new("TextButton", {
			Name = icon,
			Size = UDim2.fromOffset(row.reach, row.reach),
			LayoutOrder = order,
			Theme = { BackgroundColor3 = row.controlRole },
			Parent = row.slot,
		})
		Create.corner(6, button)
		Create.stroke("stroke", button)
		local glyph = Create.icon(icon, 14, "text", button)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		return button
	end

	local minus = press("minus", 1)
	local readout = Create.new(if options.Drag == false then "TextLabel" else "TextButton", {
		Name = "Value",
		Size = UDim2.fromOffset(52, row.reach),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Theme = { TextColor3 = "text" },
		Parent = row.slot,
	})
	local plus = press("plus", 3)

	local function draw()
		readout.Text = tostring(value) .. (options.Suffix or "")
	end

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		value = math.clamp(tonumber(newValue) or value, min, max)
		draw()
		row.fire(value)
	end

	scope:connect(minus.Activated, function()
		handle:Set(value - step)
	end)
	scope:connect(plus.Activated, function()
		handle:Set(value + step)
	end)

	if options.Drag ~= false then
		-- Drag sideways on the number: each few pixels is one step, and the
		-- Callback runs once when the drag ends.
		local origin, start
		scope:connect(readout.InputBegan, function(input)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				origin, start = input.Position.X, value
			end
		end)
		scope:connect(UserInputService.InputChanged, function(input)
			local kind = input.UserInputType
			if origin and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
				local steps = math.round((input.Position.X - origin) / (DRAG_PER_STEP * row.library.scale))
				value = math.clamp(start + steps * step, min, max)
				draw()
			end
		end)
		scope:connect(UserInputService.InputEnded, function(input)
			local kind = input.UserInputType
			if origin and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
				origin = nil
				if value ~= start then
					row.fire(value)
				end
			end
		end)
	end

	draw()
	return handle
end

return Stepper
