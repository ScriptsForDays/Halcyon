local Create = require("../Core/Create")
local Drag = require("../Core/Drag")
local Env = require("../Core/Env")
local Popup = require("../Components/Popup")
local Row = require("./Row")
local Signal = require("../Core/Signal")

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local HUES = {}
for index = 0, 6 do
	table.insert(HUES, ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1)))
end
local FADE_IN = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
local FADE_OUT = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })

local ColorPicker = {}

-- Reads "rrggbb" or "rrggbbaa". Returns the colour and, when present, its transparency.
local function parseHex(text)
	local hex = string.gsub(text, "[#%s]", "")
	if (#hex ~= 6 and #hex ~= 8) or string.find(hex, "%X") then
		return nil
	end
	local color = Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
	return color, if #hex == 8 then 1 - tonumber(string.sub(hex, 7, 8), 16) / 255 else nil
end

-- The swatch and its popup, usable on its own row or beside a Toggle.
-- `onCommit(color, transparency)` runs when a drag ends or a hex is entered,
-- not on every move: a colour change often rebuilds something expensive.
function ColorPicker.control(row, options, onCommit)
	local scope, library = row.scope, row.library
	local color = options.Default or WHITE
	local transparency = if options.Alpha then options.Transparency or 0 else 0
	local hue, saturation, value = color:ToHSV()
	local control = { Changed = Signal.new() }
	local redraw
	scope:add(control.Changed)

	local swatch = Create.new("TextButton", {
		Name = "Swatch",
		Size = UDim2.fromOffset(32, math.max(row.reach - 6, 20)),
		BackgroundColor3 = color,
		Parent = row.slot,
	})
	Create.corner(6, swatch)
	Create.stroke("stroke", swatch)

	local function hexText()
		local text = color:ToHex()
		return if options.Alpha then text .. string.format("%02x", math.round((1 - transparency) * 255)) else text
	end

	local function commit()
		control.Changed:Fire(color, transparency)
		onCommit(color, transparency)
	end

	-- `exact` keeps a colour that was set directly from drifting through the
	-- round trip to hue, saturation and value.
	local function update(newHue, newSaturation, newValue, newTransparency, exact)
		hue, saturation, value = newHue, newSaturation, newValue
		transparency = newTransparency or transparency
		color = exact or Color3.fromHSV(hue, saturation, value)
		swatch.BackgroundColor3 = color
		if redraw then
			redraw()
		end
	end

	function control:Get()
		return color, transparency
	end

	-- Accepts a Color3 or a hex string, which is how a saved config hands it back.
	function control:Set(newColor, newTransparency)
		if type(newColor) == "string" then
			newColor, newTransparency = parseHex(newColor)
		end
		if typeof(newColor) ~= "Color3" then
			return
		end
		local newHue, newSaturation, newValue = newColor:ToHSV()
		update(newHue, newSaturation, newValue, if options.Alpha then newTransparency else nil, newColor)
		commit()
	end

	function control:Encode()
		return hexText()
	end

	local function bar(parent, order)
		local track = Create.new("TextButton", {
			Size = UDim2.new(1, 0, 0, if library.touch then 22 else 14),
			BackgroundColor3 = WHITE,
			LayoutOrder = order,
			Parent = parent,
		})
		Create.corner(-1, track)
		local cursor = Create.new("Frame", {
			Size = UDim2.new(0, 4, 1, 4),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = WHITE,
			Parent = track,
		})
		Create.corner(-1, cursor)
		Create.new("UIStroke", { Color = BLACK, Transparency = 0.5, Parent = cursor })
		return track, cursor
	end

	scope:connect(swatch.Activated, function()
		local popup = Popup.toggle(library, swatch, {
			Width = 224,
			OnClose = function()
				redraw = nil
			end,
		})
		if not popup then
			return
		end
		local panel, session = popup.frame, popup.scope

		local area = Create.new("TextButton", { Name = "Shade", Size = UDim2.new(1, 0, 0, 132), Parent = panel })
		Create.corner(6, area)
		local white = Create.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = area }, {
			Create.new("UIGradient", { Transparency = FADE_OUT }),
		})
		Create.corner(6, white)
		local black = Create.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, Parent = area }, {
			Create.new("UIGradient", { Transparency = FADE_IN, Rotation = 90 }),
		})
		Create.corner(6, black)
		local ring = Create.new("Frame", {
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 2,
			BackgroundTransparency = 1,
			Parent = area,
		})
		Create.corner(-1, ring)
		Create.new("UIStroke", { Color = WHITE, Thickness = 2, Parent = ring })

		local hueTrack, hueCursor = bar(panel, 1)
		Create.new("UIGradient", { Color = ColorSequence.new(HUES), Parent = hueTrack })

		local alphaTrack, alphaCursor, alphaGradient
		if options.Alpha then
			alphaTrack, alphaCursor = bar(panel, 2)
			alphaGradient = Create.new("UIGradient", { Transparency = FADE_OUT, Parent = alphaTrack })
		end

		local box = Create.new("TextBox", {
			Name = "Hex",
			Size = UDim2.new(1, 0, 0, if library.touch then 40 else 28),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 3,
			Theme = { BackgroundColor3 = "raised", TextColor3 = "text" },
			Parent = panel,
		})
		Create.corner(6, box)

		function redraw()
			area.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			ring.Position = UDim2.fromScale(saturation, 1 - value)
			hueCursor.Position = UDim2.fromScale(hue, 0.5)
			if alphaTrack then
				alphaTrack.BackgroundColor3 = color
				alphaGradient.Color = ColorSequence.new(color)
				alphaCursor.Position = UDim2.fromScale(transparency, 0.5)
			end
			if not box:IsFocused() then
				box.Text = "#" .. string.upper(hexText())
			end
		end

		Drag.area(session, area, function(x, y)
			update(hue, x, 1 - y)
		end, commit)
		Drag.area(session, hueTrack, function(x)
			update(x, saturation, value)
		end, commit)
		if alphaTrack then
			Drag.area(session, alphaTrack, function(x)
				update(hue, saturation, value, x)
			end, commit)
		end
		session:connect(box.FocusLost, function()
			local typed, typedTransparency = parseHex(box.Text)
			if typed then
				control:Set(typed, typedTransparency)
			end
			redraw()
		end)
		redraw()
	end)

	return control
end

function ColorPicker.new(container, options)
	local row = Row.new(container, options)
	local handle = row.handle
	local control = ColorPicker.control(row, options, function(color, transparency)
		handle.Changed:Fire(color, transparency)
		Env.call(handle.Title, options.Callback, color, transparency)
	end)

	function handle:Get()
		return control:Get()
	end

	function handle:Set(color, transparency)
		control:Set(color, transparency)
	end

	function handle:Encode()
		return control:Encode()
	end

	return handle
end

return ColorPicker
