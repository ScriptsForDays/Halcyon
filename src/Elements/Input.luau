local Create = require("../Core/Create")
local Icons = require("../Core/Icons")
local Motion = require("../Core/Motion")
local Row = require("./Row")
local Styles = require("../Core/Styles")
local Theme = require("../Core/Theme")

-- Input looks (kind "Input").
--   fill        the field's colour ("control" is one step off the row's own)
--   stroke      an outline that turns accent while typing
--   underline   a line under the field instead of an outline
--   corner      the field's radius (-1 round)
Styles.register("Input", "Boxed", { fill = "control", stroke = true, corner = 6 })
Styles.register("Input", "Underline", { underline = true, corner = 0 })
Styles.register("Input", "Filled", { fill = "hover", corner = 6 })
Styles.register("Input", "Pill", { fill = "control", stroke = true, corner = -1 })

local MASK = "\u{2022}"

local Input = {}

-- Options: Default, Placeholder, Numeric (with Min and Max), Live (run the
-- Callback on every keystroke instead of when typing ends), MaxLength,
-- Width, Style (an Input look), LeadingIcon (inside the field, on the left),
-- Clearable (a button that empties it), Counter (characters used of
-- MaxLength), Password (dots while not typing, with a button to show it),
-- MultiLine (a text area under the title; Lines sets its height).
function Input.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local numeric = options.Numeric == true
	local multiLine = options.MultiLine == true and not numeric
	local password = options.Password == true and not multiLine
	local value = if numeric then tonumber(options.Default) or 0 else tostring(options.Default or "")
	local writing, focused, revealed = false, false, false
	local look = Styles.pick("Input", options.Style, row.window)
	local fillRole = if look.fill == "control" then row.controlRole else look.fill

	local lines = math.clamp(tonumber(options.Lines) or 4, 2, 12)
	local height = if multiLine then lines * 17 + 14 else math.max(row.reach, 30)
	local field = Create.new("Frame", {
		Name = "Field",
		BackgroundTransparency = if fillRole then 0 else 1,
		Theme = { BackgroundColor3 = fillRole or "raised" },
	})
	if look.corner ~= 0 then
		Create.corner(look.corner or 6, field)
	end
	local outline = if look.stroke then Create.stroke("stroke", field) else nil
	local underline
	if look.underline then
		underline = Create.new("Frame", {
			Name = "Underline",
			Size = UDim2.new(1, 0, 0, 1),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			ZIndex = 2,
			Theme = { BackgroundColor3 = "stroke" },
			Parent = field,
		})
	end
	-- The field's contents sit in their own frame so the underline is not
	-- laid out as one of them.
	local inner = Create.new("Frame", { Name = "Inner", Size = UDim2.fromScale(1, 1), Parent = field })
	Create.padding(inner, if look.underline then 2 else 10, 0)
	Create.list(inner, "Horizontal", 6, { VerticalAlignment = if multiLine then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Center })

	if options.LeadingIcon then
		local icon = Create.icon(options.LeadingIcon, 14, "textMuted", inner)
		icon.LayoutOrder = 0
	end
	local box = Create.new("TextBox", {
		Name = "Input",
		Size = UDim2.fromScale(0, 1),
		PlaceholderText = options.Placeholder or "",
		TextSize = 13,
		ClipsDescendants = true,
		MultiLine = multiLine,
		TextWrapped = multiLine,
		TextYAlignment = if multiLine then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
		LayoutOrder = 1,
		Theme = { TextColor3 = "text" },
		Parent = inner,
	}, { Create.new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	if multiLine then
		Create.padding(box, 0, 7)
	end

	local counter
	if options.Counter and options.MaxLength and not numeric then
		counter = Create.new("TextLabel", {
			Name = "Counter",
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 12,
			LayoutOrder = 4,
			Theme = { TextColor3 = "textMuted" },
			Parent = inner,
		})
		if multiLine then
			counter.Size = UDim2.fromOffset(0, 30)
		end
	end

	local function fieldButton(icon, order)
		local button = Create.new("ImageButton", { Name = "Action", Size = UDim2.fromOffset(18, 18), LayoutOrder = order, Parent = inner })
		local glyph = Create.icon(icon, 14, "textMuted", button)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		scope:connect(button.MouseEnter, function()
			Theme.bind(glyph, "ImageColor3", "text")
		end)
		scope:connect(button.MouseLeave, function()
			Theme.bind(glyph, "ImageColor3", "textMuted")
		end)
		return button, glyph
	end

	local clear = if options.Clearable then fieldButton("x", 2) else nil
	local eye, eyeGlyph
	if password then
		eye, eyeGlyph = fieldButton("eye", 3)
	end

	row.placeControl(field, options.Width or 150, height, multiLine)

	local function decorate()
		local text = tostring(value)
		if clear then
			clear.Visible = text ~= "" and not (numeric and value == 0 and options.Default == nil)
		end
		if counter then
			counter.Text = #box.Text .. "/" .. options.MaxLength
		end
	end

	local function show()
		writing = true
		local text = if numeric and options.Default == nil and value == 0 then "" else tostring(value)
		-- A password shows as dots unless it is being typed or was revealed.
		box.Text = if password and not focused and not revealed then string.rep(MASK, utf8.len(text) or #text) else text
		writing = false
		decorate()
	end

	-- Returns false when the text is not acceptable, leaving the value as it was.
	local function store(text)
		if numeric then
			local number = tonumber(text)
			if not number then
				return false
			end
			value = math.clamp(number, options.Min or -math.huge, options.Max or math.huge)
		else
			text = tostring(text)
			value = if options.MaxLength then string.sub(text, 1, options.MaxLength) else text
		end
		return true
	end

	local function focusLook(active)
		if outline then
			Theme.bind(outline, "Color", if active then "accent" else "stroke")
		end
		if underline then
			Theme.bind(underline, "BackgroundColor3", if active then "accent" else "stroke")
			Motion.tween(underline, "fast", { Size = UDim2.new(1, 0, 0, if active then 2 else 1) })
		end
	end

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		if store(newValue) then
			show()
			row.fire(value)
		end
	end

	scope:connect(box.Focused, function()
		focused = true
		focusLook(true)
		if password then
			show()
		end
	end)
	scope:connect(box.FocusLost, function()
		focused = false
		focusLook(false)
		local previous = value
		local accepted = store(box.Text)
		show()
		if accepted and (value ~= previous or not options.Live) then
			row.fire(value)
		end
	end)

	scope:connect(box:GetPropertyChangedSignal("Text"), function()
		if writing then
			return
		end
		if options.MaxLength and not numeric and #box.Text > options.MaxLength then
			-- Typing stops at the limit instead of being cut when the box closes.
			writing = true
			box.Text = string.sub(box.Text, 1, options.MaxLength)
			writing = false
		end
		if options.Live and not numeric and store(box.Text) then
			row.fire(value)
		end
		decorate()
	end)

	if clear then
		scope:connect(clear.Activated, function()
			handle:Set(if numeric then options.Min or 0 else "")
		end)
	end
	if eye then
		scope:connect(eye.Activated, function()
			revealed = not revealed
			Icons.apply(eyeGlyph, if revealed then "eye-off" else "eye")
			show()
		end)
	end

	show()
	return handle
end

return Input
