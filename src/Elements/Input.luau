local Create = require("../Core/Create")
local Row = require("./Row")

local Input = {}

-- Options: Default, Placeholder, Numeric (with Min and Max), Live (run the
-- Callback on every keystroke instead of when typing ends), MaxLength, Width.
function Input.new(container, options)
	local row = Row.new(container, options)
	local handle, scope = row.handle, row.scope
	local numeric = options.Numeric == true
	local value = if numeric then tonumber(options.Default) or 0 else tostring(options.Default or "")
	local writing = false

	local box = Create.new("TextBox", {
		Name = "Input",
		PlaceholderText = options.Placeholder or "",
		TextSize = 13,
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = row.controlRole, TextColor3 = "text" },
	})
	Create.corner(6, box)
	Create.stroke("stroke", box)
	Create.padding(box, 10, 0)
	row.placeControl(box, options.Width or 150, math.max(row.reach, 30))

	local function show()
		writing = true
		box.Text = if numeric and options.Default == nil and value == 0 then "" else tostring(value)
		writing = false
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

	function handle:Get()
		return value
	end

	function handle:Set(newValue)
		if store(newValue) then
			show()
			row.fire(value)
		end
	end

	scope:connect(box.FocusLost, function()
		local previous = value
		local accepted = store(box.Text)
		show()
		if accepted and (value ~= previous or not options.Live) then
			row.fire(value)
		end
	end)

	if options.Live and not numeric then
		scope:connect(box:GetPropertyChangedSignal("Text"), function()
			if not writing and store(box.Text) then
				row.fire(value)
			end
		end)
	end

	show()
	return handle
end

return Input
