local Create = require("../Core/Create")
local Effects = require("../Core/Effects")
local Row = require("./Row")
local Theme = require("../Core/Theme")

local KINDS = { success = "success", warning = "warning", danger = "danger", info = "info", muted = "textMuted" }

local Status = {}

-- A pill with a coloured dot that reports a state: Online, Working,
-- Patched. Options: Status (the words), Kind (success, warning, danger,
-- info or muted), Pulse (the dot breathes while true). The words always
-- say the state, so colour is never the only signal.
function Status.new(container, options)
	local row = Row.new(container, options)
	local handle = row.handle

	local pill = Create.new("Frame", {
		Name = "Status",
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.86,
		Parent = row.slot,
	})
	Create.corner(-1, pill)
	Create.padding(pill, 10, 0)
	Create.list(pill, "Horizontal", 6)
	local dot = Create.new("Frame", { Name = "Dot", Size = UDim2.fromOffset(8, 8), Parent = pill })
	Create.corner(-1, dot)
	local halo = Create.new("UIStroke", { Thickness = 0, Transparency = 0.4, Parent = dot })
	local words = Create.new("TextLabel", {
		Name = "Words",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = 12,
		Weight = "bold",
		LayoutOrder = 1,
		Parent = pill,
	})
	local pulse = Effects.pulse(row.scope, halo)

	local state = { text = options.Status or "Ready", kind = options.Kind or "success" }
	local function draw()
		local role = KINDS[state.kind] or "success"
		Theme.bind(pill, "BackgroundColor3", role)
		Theme.bind(dot, "BackgroundColor3", role)
		Theme.bind(halo, "Color", role)
		Theme.bind(words, "TextColor3", role)
		words.Text = state.text
		handle.SearchExtra = state.text
		handle.SearchText = string.lower(handle.Title .. " " .. state.text)
		if options.Pulse then
			pulse.start()
		else
			pulse.stop()
		end
	end

	function handle:Get()
		return state.text, state.kind
	end

	-- SetStatus("Working", "warning"); the kind is kept when left out.
	function handle:SetStatus(text, kind)
		state.text = tostring(text)
		state.kind = kind or state.kind
		draw()
		self.Changed:Fire(state.text, state.kind)
	end
	handle.Set = handle.SetStatus

	function handle:SetPulse(on)
		options.Pulse = on == true
		draw()
	end

	draw()
	return handle
end

return Status
